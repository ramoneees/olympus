"""mnemosyne-api — semantic search + guarded upserts over the Mnemosyne pgvector store.

Endpoints:
  GET /health              — PG + TEI probe (no auth; used by k8s probes)
  GET /search?q=&ns=&k=&profile=  — semantic search (token required)
  GET /stats               — namespace counts (token required)
  POST /upsert             — guarded bulk write (token required; see UPSERT_* limits)

Upsert guards (incident 2026-11-08: a 47-entry batch starved the CPU-only TEI,
/health timed out, kubelet killed a healthy pod, 38 ECONNRESETs upstream):
  - max 32 entries per request (422 beyond — clients chunk)
  - 20..20000 chars per entry (422 outside; embed uses first 6000)
  - embeddings STRICTLY serialized: global lock + sequential loop, one TEI
    call in flight at a time; retry x3 with backoff per entry
  - circuit breaker: TEI /health must answer <3s before we start, else 503
  - idempotent per (namespace, key, content_hash): unchanged entries are
    skipped without spending a single TEI call

Auth: X-API-Token header must match MNEMOSYNE_API_TOKEN (set from secret).
Exposure: LAN-only via Traefik wildcard (mnemosyne.ramoneees.com).
"""
import hashlib
import json
import os
import re
import threading
import time
import urllib.request

import psycopg2
from fastapi import Body, FastAPI, HTTPException, Query, Request

TEI_URL = os.environ.get("TEI_URL", "http://tei.olympus.svc.cluster.local:80")
PG_DSN = os.environ["MNEMOSYNE_PG_DSN"]
PG_WRITE_DSN = os.environ.get("MNEMOSYNE_PG_WRITE_DSN", "")  # writer role; /upsert 503 if unset
API_TOKEN = os.environ.get("MNEMOSYNE_API_TOKEN", "")

UPSERT_MAX_ENTRIES = 32
UPSERT_MIN_CHARS = 20
UPSERT_MAX_CHARS = 20000
EMBED_TRUNC = 6000

app = FastAPI(title="mnemosyne-api", version="0.2.0")

_upsert_lock = threading.Lock()  # one embed pipeline at a time, process-wide


def check_token(request: Request) -> None:
    if API_TOKEN and request.headers.get("x-api-token") != API_TOKEN:
        raise HTTPException(status_code=401, detail="invalid or missing X-API-Token")


def http_json(url: str, payload: bytes | None, timeout: float) -> bytes:
    req = urllib.request.Request(
        url, data=payload,
        headers={"Content-Type": "application/json"}, method="POST" if payload else "GET",
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def embed(text: str) -> list[float]:
    out = json.loads(http_json(f"{TEI_URL.rstrip('/')}/embed",
                               json.dumps({"inputs": text}).encode(), 30))
    if not isinstance(out, list) or not out:
        raise ValueError(f"unexpected TEI response: {str(out)[:120]}")
    return out[0]


def embed_retry(text: str, tries: int = 3) -> list[float]:
    delays = (0.5, 2.0)
    for i in range(tries):
        try:
            return embed(text)
        except Exception:
            if i == tries - 1:
                raise
            time.sleep(delays[min(i, len(delays) - 1)])
    raise RuntimeError("unreachable")


def tei_alive(timeout: float = 3.0) -> bool:
    """Circuit breaker: a TEI that can't answer /health fast is saturated."""
    try:
        http_json(f"{TEI_URL.rstrip('/')}/health", None, timeout)
        return True
    except Exception:
        return False


def db():
    return psycopg2.connect(PG_DSN)


@app.get("/health")
def health():
    try:
        conn = db()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.fetchone()
        cur.close()
        conn.close()
        dims = len(embed("ping"))
        status = "ok" if dims == 1024 else "degraded"
        return {"status": status, "tei_dims": dims}
    except Exception as e:
        raise HTTPException(status_code=503, detail=str(e)[:200])


@app.get("/search")
def search(
    request: Request,
    q: str = Query(min_length=2, max_length=2000),
    ns: str | None = Query(default=None, max_length=200),
    profile: str | None = Query(default=None, max_length=64),
    k: int = Query(default=5, ge=1, le=25),
):
    check_token(request)
    try:
        vec = "[" + ",".join(map(str, embed(q))) + "]"
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"tei error: {str(e)[:150]}")

    sql = (
        "SELECT content, namespace, metadata->>'title', metadata->>'file_path', "
        "metadata->>'profile', metadata->>'session_id', 1 - (embedding <=> %s::vector) "
        "FROM memory_entries"
    )
    params: list = [vec]
    conds = []
    if ns:
        conds.append("namespace = %s")
        params.append(ns)
    if profile:
        conds.append("metadata->>'profile' = %s")
        params.append(profile)
    if conds:
        sql += " WHERE " + " AND ".join(conds)
    sql += " ORDER BY embedding <=> %s::vector LIMIT %s"
    params += [vec, k]

    try:
        conn = db()
        cur = conn.cursor()
        cur.execute(sql, params)
        rows = cur.fetchall()
        cur.close()
        conn.close()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"db error: {str(e)[:150]}")

    return {
        "query": q,
        "count": len(rows),
        "results": [
            {
                "similarity": round(sim, 4),
                "namespace": ns_,
                "title": title,
                "file_path": file_path,
                "profile": prof,
                "session_id": sid,
                "content": content,
            }
            for content, ns_, title, file_path, prof, sid, sim in rows
        ],
    }


@app.get("/stats")
def stats(request: Request):
    check_token(request)
    conn = db()
    cur = conn.cursor()
    cur.execute("SELECT namespace, count(*) FROM memory_entries GROUP BY 1 ORDER BY 2 DESC")
    rows = [{"namespace": ns_, "chunks": n} for ns_, n in cur.fetchall()]
    cur.close()
    conn.close()
    return {"namespaces": rows, "total": sum(r["chunks"] for r in rows)}


@app.post("/upsert")
def upsert(request: Request, payload: dict = Body(...)):
    check_token(request)
    if not PG_WRITE_DSN:
        raise HTTPException(status_code=503, detail="write DSN not configured")

    ns = payload.get("namespace", "")
    agent = payload.get("source_agent", "")
    entries = payload.get("entries")

    if not re.fullmatch(r"/memory/[A-Za-z0-9/_-]{1,100}", ns or ""):
        raise HTTPException(status_code=422, detail="namespace must be /memory/<topic>")
    if not re.fullmatch(r"[A-Za-z0-9_.:-]{1,100}", agent or ""):
        raise HTTPException(status_code=422, detail="invalid source_agent")
    if not isinstance(entries, list) or not entries:
        raise HTTPException(status_code=422, detail="entries must be a non-empty list")
    if len(entries) > UPSERT_MAX_ENTRIES:
        raise HTTPException(
            status_code=422,
            detail=f"max {UPSERT_MAX_ENTRIES} entries per request (got {len(entries)}); chunk client-side",
        )

    prepared, errors = [], []
    for i, e in enumerate(entries):
        key = (e or {}).get("key", "")
        content = ((e or {}).get("content") or "").strip()
        meta = (e or {}).get("metadata") or {}
        if not re.fullmatch(r".{1,200}", key, flags=re.S):
            errors.append(f"entries[{i}].key: required, <=200 chars")
            continue
        if not UPSERT_MIN_CHARS <= len(content) <= UPSERT_MAX_CHARS:
            errors.append(f"entries[{i}].content: {UPSERT_MIN_CHARS}..{UPSERT_MAX_CHARS} chars (got {len(content)})")
            continue
        if not isinstance(meta, dict):
            errors.append(f"entries[{i}].metadata: must be an object")
            continue
        prepared.append({
            "key": key,
            "content": content,
            "meta": {**meta, "key": key,
                     "content_hash": hashlib.sha256(content.encode()).hexdigest()},
        })
    if errors:
        raise HTTPException(status_code=422, detail="; ".join(errors[:5]))

    if not _upsert_lock.acquire(timeout=5):
        raise HTTPException(status_code=429, detail="another upsert in flight; retry shortly",
                            headers={"Retry-After": "60"})
    try:
        if not tei_alive():
            raise HTTPException(status_code=503, detail="TEI saturated or down; back off",
                                headers={"Retry-After": "120"})
        t0 = time.monotonic()
        conn = psycopg2.connect(PG_WRITE_DSN)
        cur = conn.cursor()
        indexed = skipped = 0
        try:
            for p in prepared:
                # idempotency: same key + same content already stored -> no TEI work
                cur.execute(
                    "SELECT 1 FROM memory_entries "
                    "WHERE namespace=%s AND metadata->>'key'=%s "
                    "AND metadata->>'content_hash'=%s LIMIT 1",
                    (ns, p["key"], p["meta"]["content_hash"]),
                )
                if cur.fetchone():
                    skipped += 1
                    continue
                vec = "[" + ",".join(map(str, embed_retry(p["content"][:EMBED_TRUNC]))) + "]"
                cur.execute(
                    "DELETE FROM memory_entries WHERE namespace=%s AND metadata->>'key'=%s",
                    (ns, p["key"]),
                )
                cur.execute(
                    "INSERT INTO memory_entries (content, metadata, namespace, embedding, source_agent) "
                    "VALUES (%s, %s::jsonb, %s, %s::vector, %s)",
                    (p["content"], json.dumps(p["meta"]), ns, vec, agent),
                )
                indexed += 1
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            cur.close()
            conn.close()
        return {"status": "ok", "indexed": indexed, "skipped": skipped,
                "elapsed_ms": int((time.monotonic() - t0) * 1000)}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"upsert failed: {str(e)[:200]}")
    finally:
        _upsert_lock.release()

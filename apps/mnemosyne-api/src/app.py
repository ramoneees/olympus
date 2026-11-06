"""mnemosyne-api — semantic search over the Mnemosyne pgvector store.

Endpoints:
  GET /health              — PG + TEI probe (no auth; used by k8s probes)
  GET /search?q=&ns=&k=&profile=  — semantic search (token required)
  GET /stats               — namespace counts (token required)

Auth: X-API-Token header must match MNEMOSYNE_API_TOKEN (set from secret).
Exposure: LAN-only via Traefik wildcard (mnemosyne.ramoneees.com).
"""
import json
import os
import urllib.request

import psycopg2
from fastapi import FastAPI, HTTPException, Query, Request

TEI_URL = os.environ.get("TEI_URL", "http://tei.olympus.svc.cluster.local:80")
PG_DSN = os.environ["MNEMOSYNE_PG_DSN"]
API_TOKEN = os.environ.get("MNEMOSYNE_API_TOKEN", "")

app = FastAPI(title="mnemosyne-api", version="0.1.0")


def check_token(request: Request) -> None:
    if API_TOKEN and request.headers.get("x-api-token") != API_TOKEN:
        raise HTTPException(status_code=401, detail="invalid or missing X-API-Token")


def embed(text: str) -> list[float]:
    data = json.dumps({"inputs": text}).encode("utf-8")
    req = urllib.request.Request(
        f"{TEI_URL.rstrip('/')}/embed",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        out = json.loads(resp.read())
    if not isinstance(out, list) or not out:
        raise ValueError(f"unexpected TEI response: {str(out)[:120]}")
    return out[0]


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

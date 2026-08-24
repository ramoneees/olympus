#!/usr/bin/env python3
"""Incremental session indexer: only sessions newer than the newest indexed timestamp."""
import sys, sqlite3, json, base64, subprocess, time, datetime, argparse
import importlib.util
from pathlib import Path

# import chunk_conversation/get_embedding from the hyphenated script
spec = importlib.util.spec_from_file_location(
    "idx", "/Users/ramoneees/dev/olympus/scripts/index-sessions.py"
)
idx = importlib.util.module_from_spec(spec)
sys.modules["idx"] = idx
spec.loader.exec_module(idx)
chunk_conversation, get_embedding = idx.chunk_conversation, idx.get_embedding

import psycopg2

ap = argparse.ArgumentParser()
ap.add_argument("--dry-run", action="store_true")
args = ap.parse_args()

r = subprocess.run(
    ["kubectl", "get", "secret", "-n", "databases", "postgresql-secret",
     "-o", "jsonpath={.data.postgres-password}"], capture_output=True, text=True)
PG_PASSWORD = base64.b64decode(r.stdout.strip()).decode()
PG = f"postgresql://postgres:{PG_PASSWORD}@localhost:5432/mnemosyne"
TEI = "http://localhost:8080"
NS = "/memory/sessions"

conn = psycopg2.connect(PG)
cur = conn.cursor()
cur.execute("SELECT max((metadata->>'started_at')::timestamptz) FROM memory_entries WHERE namespace=%s", (NS,))
last = cur.fetchone()[0]
print(f"last indexed started_at: {last}")

sconn = sqlite3.connect("/Users/ramoneees/.hermes/state.db")
sconn.row_factory = sqlite3.Row
scur = sconn.cursor()

q = """
SELECT id, title, source, started_at FROM sessions
WHERE message_count > 2 AND started_at > ?
ORDER BY started_at ASC
"""
sessions = scur.execute(q, (last.timestamp(),)).fetchall()
print(f"sessions to index: {len(sessions)}")

total_chunks = 0
plan = []
for s in sessions:
    msgs = scur.execute(
        "SELECT role, content FROM messages WHERE session_id=? AND role IN ('user','assistant') "
        "AND content IS NOT NULL AND content != '' ORDER BY timestamp", (s["id"],)).fetchall()
    chunks = chunk_conversation([dict(m) for m in msgs])
    if chunks:
        plan.append((s, chunks))
        total_chunks += len(chunks)

print(f"chunks to embed: {total_chunks}")
if args.dry_run:
    for s, chunks in plan:
        print(f"  {datetime.datetime.fromtimestamp(s['started_at']).isoformat()} | {(s['title'] or s['id'])[:60]} | {len(chunks)} chunks")
    sys.exit(0)

indexed = errors = 0
t0 = time.time()
for n, (s, chunks) in enumerate(plan, 1):
    sid, title, source, started = s["id"], s["title"] or s["id"], s["source"], s["started_at"]
    dt = datetime.datetime.fromtimestamp(started, tz=datetime.timezone.utc).isoformat()
    for ci, chunk in enumerate(chunks):
        if len(chunk) > 2400:
            chunk = chunk[:2400] + "..."
        try:
            emb = get_embedding(chunk, TEI)
            cur.execute(
                "INSERT INTO memory_entries (namespace, content, embedding, source_agent, confidence, metadata) "
                "VALUES (%s,%s,%s,%s,%s,%s)",
                (NS, chunk, str(emb), "hermes-sessions", 0.90,
                 json.dumps({"session_id": sid, "title": title, "source": source,
                             "chunk_index": ci, "total_chunks": len(chunks), "started_at": dt})))
            indexed += 1
        except Exception as e:
            errors += 1
            print(f"\nERR {sid} chunk {ci}: {e}")
    conn.commit()
    print(f"[{n}/{len(plan)}] {title[:55]} (+{len(chunks)}) elapsed {time.time()-t0:.0f}s", flush=True)

print(f"\nDONE: {indexed} chunks inserted, {errors} errors, {time.time()-t0:.0f}s")
cur.execute("SELECT count(*), count(DISTINCT metadata->>'session_id') FROM memory_entries WHERE namespace=%s", (NS,))
print("DB now:", cur.fetchone())
cur.close(); conn.close(); sconn.close()

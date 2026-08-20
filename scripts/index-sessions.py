#!/usr/bin/env python3
"""
Index Hermes session history into pgvector (Mnemosyne schema).

Extracts user+assistant messages from state.db, groups them into
conversation chunks per session, embeds via TEI, stores in pgvector.

Usage:
    python3 index-sessions.py \
        --db /Users/ramoneees/.hermes/state.db \
        --tei http://localhost:8080 \
        --pg "postgresql://postgres:PASSWORD@localhost:5432/mnemosyne" \
        --rebuild
"""

import argparse
import json
import sqlite3
import sys
import time
import urllib.request
from pathlib import Path
from datetime import datetime, timezone

try:
    import psycopg2
except ImportError:
    print("ERROR: psycopg2 not installed. Run: pip3 install psycopg2-binary")
    sys.exit(1)


def chunk_conversation(messages: list[dict], max_chars: int = 2500) -> list[str]:
    """
    Group messages into conversation chunks.
    Each chunk is a coherent exchange: user message + assistant response(s).
    max_chars=2500 to stay under TEI payload limit (~2MB with JSON overhead).
    """
    chunks = []
    current = ""
    
    for msg in messages:
        role = msg["role"]
        content = (msg["content"] or "").strip()
        if not content:
            continue
        
        # Format message
        if role == "user":
            prefix = "User: "
        elif role == "assistant":
            prefix = "Assistant: "
        else:
            continue
        
        entry = f"{prefix}{content}\n\n"
        
        if len(current) + len(entry) <= max_chars:
            current += entry
        else:
            if current:
                chunks.append(current.strip())
            current = entry
    
    if current:
        chunks.append(current.strip())
    
    return chunks


def get_embedding(text: str, tei_url: str, max_retries: int = 3) -> list[float]:
    """Get embedding from TEI endpoint with retry logic."""
    data = json.dumps({"inputs": text}).encode("utf-8")
    
    for attempt in range(max_retries):
        try:
            req = urllib.request.Request(
                f"{tei_url.rstrip('/')}/embed",
                data=data,
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=120) as resp:
                result = json.loads(resp.read())
            if isinstance(result, list) and len(result) > 0:
                return result[0]
            raise ValueError(f"Unexpected TEI response: {str(result)[:200]}")
        except Exception as e:
            if attempt < max_retries - 1:
                print(f"      retry {attempt+1}/{max_retries}: {e}", end="", flush=True)
                time.sleep(5)
            else:
                raise


def main():
    parser = argparse.ArgumentParser(description="Index Hermes sessions into pgvector")
    parser.add_argument("--db", required=True, help="Path to state.db")
    parser.add_argument("--tei", required=True, help="TEI endpoint URL")
    parser.add_argument("--pg", required=True, help="PostgreSQL connection string")
    parser.add_argument("--namespace", default="/memory/sessions", help="Namespace prefix")
    parser.add_argument("--rebuild", action="store_true", help="Clear namespace before indexing")
    parser.add_argument("--limit", type=int, default=0, help="Max sessions to index (0=all)")
    parser.add_argument("--dry-run", action="store_true", help="Show stats without indexing")
    args = parser.parse_args()
    
    db_path = Path(args.db)
    if not db_path.exists():
        print(f"ERROR: state.db not found: {db_path}")
        sys.exit(1)
    
    # Connect to SQLite
    sconn = sqlite3.connect(str(db_path))
    sconn.row_factory = sqlite3.Row
    scur = sconn.cursor()
    
    # Get sessions
    query = """
        SELECT id, title, source, started_at, ended_at, message_count, archived
        FROM sessions
        WHERE message_count > 2
        ORDER BY started_at DESC
    """
    if args.limit > 0:
        query += f" LIMIT {args.limit}"
    
    sessions = scur.execute(query).fetchall()
    print(f"Found {len(sessions)} sessions to index")
    
    if args.dry_run:
        total_chunks = 0
        for s in sessions:
            msgs = scur.execute(
                "SELECT role, content FROM messages WHERE session_id=? AND role IN ('user','assistant') AND content IS NOT NULL AND content != '' ORDER BY timestamp",
                (s["id"],)
            ).fetchall()
            chunks = chunk_conversation([dict(m) for m in msgs])
            total_chunks += len(chunks)
            if chunks:
                print(f"  {s['title'] or s['id']}: {len(msgs)} msgs → {len(chunks)} chunks")
        print(f"\nTotal: {total_chunks} chunks across {len(sessions)} sessions")
        sconn.close()
        return
    
    # Connect to Postgres
    conn = psycopg2.connect(args.pg)
    conn.autocommit = False
    cur = conn.cursor()
    
    def reconnect():
        """Reconnect to Postgres after connection loss."""
        nonlocal conn, cur
        try:
            cur.close()
        except:
            pass
        try:
            conn.close()
        except:
            pass
        time.sleep(2)
        conn = psycopg2.connect(args.pg)
        conn.autocommit = False
        cur = conn.cursor()
    
    if args.rebuild:
        cur.execute("DELETE FROM memory_entries WHERE namespace = %s", (args.namespace,))
        deleted = cur.rowcount
        conn.commit()
        print(f"Deleted {deleted} existing entries in namespace '{args.namespace}'")
    
    total_indexed = 0
    total_sessions = 0
    errors = 0
    
    for si, s in enumerate(sessions):
        sid = s["id"]
        title = s["title"] or sid
        source = s["source"]
        started = s["started_at"]
        
        # Parse timestamp
        try:
            dt = datetime.fromtimestamp(started, tz=timezone.utc).isoformat()
        except:
            dt = None
        
        # Get messages
        msgs = scur.execute(
            "SELECT role, content FROM messages WHERE session_id=? AND role IN ('user','assistant') AND content IS NOT NULL AND content != '' ORDER BY timestamp",
            (sid,)
        ).fetchall()
        
        if not msgs:
            continue
        
        chunks = chunk_conversation([dict(m) for m in msgs])
        if not chunks:
            continue
        
        print(f"\n  [{si+1}/{len(sessions)}] {title[:60]} ({len(chunks)} chunks)")
        
        for ci, chunk in enumerate(chunks):
            # Truncate chunk to stay under TEI payload limit
            if len(chunk) > 2400:
                chunk = chunk[:2400] + "..."
            
            try:
                embedding = get_embedding(chunk, args.tei)
                
                metadata = {
                    "session_id": sid,
                    "title": title,
                    "source": source,
                    "chunk_index": ci,
                    "total_chunks": len(chunks),
                    "started_at": dt,
                }
                
                try:
                    cur.execute(
                        """
                        INSERT INTO memory_entries (namespace, content, embedding, source_agent, confidence, metadata)
                        VALUES (%s, %s, %s, %s, %s, %s)
                        """,
                        (
                            args.namespace,
                            chunk,
                            str(embedding),
                            "hermes-sessions",
                            0.90,
                            json.dumps(metadata),
                        ),
                    )
                except psycopg2.OperationalError:
                    # Connection lost, try reconnect
                    print(f"    chunk {ci} PG connection lost, reconnecting...", end="", flush=True)
                    reconnect()
                    cur.execute(
                        """
                        INSERT INTO memory_entries (namespace, content, embedding, source_agent, confidence, metadata)
                        VALUES (%s, %s, %s, %s, %s, %s)
                        """,
                        (
                            args.namespace,
                            chunk,
                            str(embedding),
                            "hermes-sessions",
                            0.90,
                            json.dumps(metadata),
                        ),
                    )
                
                total_indexed += 1
                print(f"    chunk {ci}/{len(chunks)-1} ✓", end="", flush=True)
                
                time.sleep(0.05)  # Small delay
                
            except Exception as e:
                print(f"    chunk {ci} ERROR: {e}")
                errors += 1
                try:
                    conn.rollback()
                except:
                    reconnect()
                continue
        
        try:
            conn.commit()
        except psycopg2.OperationalError:
            reconnect()
            conn.commit()
        total_sessions += 1
    
    cur.close()
    conn.close()
    sconn.close()
    
    print(f"\n{'='*50}")
    print(f"Indexed: {total_indexed} chunks from {total_sessions} sessions")
    print(f"Errors:  {errors}")
    print(f"Namespace: {args.namespace}")
    print(f"{'='*50}")


if __name__ == "__main__":
    main()

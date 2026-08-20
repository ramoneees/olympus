#!/usr/bin/env python3
"""
Semantic memory search across pgvector (Mnemosyne).

Searches both Obsidian vault notes and Hermes session history.
Can be used as a CLI tool or as an MCP tool via Hermes.

Usage (CLI):
    python3 semantic-search.py --query "configuração do Mac" --limit 5
    python3 semantic-search.py --query "firefly reconciliação" --namespace /memory/obsidian
    python3 semantic-search.py --stats

Environment variables:
    MNEMOSYNE_PG_URL  — PostgreSQL connection string (required if --pg not given)
    TEI_URL           — TEI endpoint (default: http://localhost:8080)
"""

import argparse
import json
import os
import sys
import urllib.request

try:
    import psycopg2
except ImportError:
    print("ERROR: psycopg2 not installed. Run: pip3 install psycopg2-binary")
    sys.exit(1)


def get_embedding(text: str, tei_url: str) -> list[float]:
    data = json.dumps({"inputs": text}).encode("utf-8")
    req = urllib.request.Request(
        f"{tei_url.rstrip('/')}/embed",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        result = json.loads(resp.read())
    if isinstance(result, list) and len(result) > 0:
        return result[0]
    raise ValueError(f"Unexpected TEI response: {str(result)[:200]}")


def search(pg_url: str, tei_url: str, query: str, namespace: str | None = None, limit: int = 5):
    """Search pgvector for similar content."""
    emb = get_embedding(query, tei_url)
    emb_str = "[" + ",".join(str(x) for x in emb) + "]"
    
    conn = psycopg2.connect(pg_url)
    cur = conn.cursor()
    
    if namespace:
        cur.execute("""
            SELECT 
                content,
                metadata->>'file_path' as file_path,
                metadata->>'title' as title,
                metadata->>'session_id' as session_id,
                metadata->>'source' as source,
                namespace,
                1 - (embedding <=> %s::vector) as similarity
            FROM memory_entries
            WHERE namespace = %s
            ORDER BY embedding <=> %s::vector
            LIMIT %s
        """, (emb_str, namespace, emb_str, limit))
    else:
        cur.execute("""
            SELECT 
                content,
                metadata->>'file_path' as file_path,
                metadata->>'title' as title,
                metadata->>'session_id' as session_id,
                metadata->>'source' as source,
                namespace,
                1 - (embedding <=> %s::vector) as similarity
            FROM memory_entries
            ORDER BY embedding <=> %s::vector
            LIMIT %s
        """, (emb_str, emb_str, limit))
    
    results = cur.fetchall()
    cur.close()
    conn.close()
    return results


def stats(pg_url: str):
    """Show database stats."""
    conn = psycopg2.connect(pg_url)
    cur = conn.cursor()
    
    cur.execute("""
        SELECT namespace, COUNT(*) as count,
               MIN(timestamp) as oldest,
               MAX(timestamp) as newest
        FROM memory_entries
        GROUP BY namespace
        ORDER BY namespace;
    """)
    rows = cur.fetchall()
    cur.close()
    conn.close()
    
    print(f"\n{'Namespace':<30} {'Count':>8} {'Oldest':>12} {'Newest':>12}")
    print("-" * 65)
    for ns, count, oldest, newest in rows:
        print(f"{ns:<30} {count:>8} {str(oldest)[:10]:>12} {str(newest)[:10]:>12}")
    print()


def main():
    parser = argparse.ArgumentParser(description="Semantic search across Mnemosyne memory")
    parser.add_argument("--query", "-q", help="Search query")
    parser.add_argument("--limit", "-l", type=int, default=5, help="Max results")
    parser.add_argument("--namespace", "-n", help="Filter by namespace (e.g. /memory/obsidian, /memory/sessions)")
    parser.add_argument("--stats", action="store_true", help="Show database stats")
    parser.add_argument("--pg", help="PostgreSQL connection string (or set MNEMOSYNE_PG_URL env)")
    parser.add_argument("--tei", default=os.environ.get("TEI_URL", "http://localhost:8080"), help="TEI endpoint")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    args = parser.parse_args()
    
    pg_url = args.pg or os.environ.get("MNEMOSYNE_PG_URL")
    if not pg_url:
        print("ERROR: set MNEMOSYNE_PG_URL or pass --pg")
        sys.exit(1)
    
    if args.stats:
        stats(pg_url)
        return
    
    if not args.query:
        print("ERROR: provide --query or --stats")
        sys.exit(1)
    
    results = search(args.tei, args.tei, args.query, args.namespace, args.limit)
    # Fix: call with correct args
    results = search(pg_url, args.tei, args.query, args.namespace, args.limit)
    
    if args.json:
        output = []
        for content, file_path, title, session_id, source, namespace, sim in results:
            output.append({
                "content": content,
                "file_path": file_path,
                "title": title,
                "session_id": session_id,
                "source": source,
                "namespace": namespace,
                "similarity": round(sim, 4),
            })
        print(json.dumps(output, indent=2, ensure_ascii=False))
    else:
        print(f"\nQuery: {args.query}")
        print(f"{'='*60}\n")
        for i, (content, file_path, title, session_id, source, namespace, sim) in enumerate(results, 1):
            preview = content[:200].replace("\n", " ")
            location = file_path or session_id or "?"
            print(f"#{i} [sim={sim:.4f}] {namespace}")
            print(f"   Title: {title or '?'}")
            print(f"   Location: {location}")
            print(f"   Preview: {preview}...")
            print()


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Index Obsidian vault memory files into pgvector (Mnemosyne schema).

Usage:
    python3 index-vault.py --vault /Users/ramoneees/obsidian-vault/memory \
        --tei http://localhost:8080 \
        --pg "postgresql://postgres:PASSWORD@localhost:5432/mnemosyne" \
        --namespace /memory/obsidian

Flags:
    --dry-run    Show what would be indexed without writing to DB
    --rebuild    Drop all entries in namespace before indexing (idempotent re-runs)
"""

import argparse
import hashlib
import json
import os
import re
import sys
import time
import urllib.request
from pathlib import Path

try:
    import psycopg2
except ImportError:
    print("ERROR: psycopg2 not installed. Run: pip install psycopg2-binary")
    sys.exit(1)


# Files to skip (reference dumps, not memory)
SKIP_PATTERNS = [
    "skills-references/llms-txt.md",
    "skills-references/llms-full.md",
    "skills-references/README.md",
    "README.md",
]


def chunk_text(text: str, max_tokens: int = 512, overlap: int = 64) -> list[str]:
    """
    Split text into chunks by paragraphs, respecting approximate token limits.
    BGE-M3 supports 8192 tokens max, but smaller chunks = better retrieval precision.
    """
    # Rough: 1 token ≈ 4 chars. 512 tokens ≈ 2048 chars
    max_chars = max_tokens * 4
    overlap_chars = overlap * 4

    # Split by double newline (paragraphs)
    paragraphs = re.split(r'\n\n+', text.strip())
    
    chunks = []
    current_chunk = ""
    
    for para in paragraphs:
        para = para.strip()
        if not para:
            continue
        
        if len(current_chunk) + len(para) + 2 <= max_chars:
            current_chunk += ("\n\n" if current_chunk else "") + para
        else:
            if current_chunk:
                chunks.append(current_chunk)
            # Start new chunk with overlap from end of previous
            if chunks and overlap_chars > 0:
                prev_tail = chunks[-1][-overlap_chars:]
                current_chunk = prev_tail + "\n\n" + para
            else:
                current_chunk = para
    
    if current_chunk:
        chunks.append(current_chunk)
    
    return chunks if chunks else [text.strip()]


def get_embedding(text: str, tei_url: str) -> list[float]:
    """Get embedding from TEI endpoint."""
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


def file_to_chunks(file_path: Path, vault_root: Path) -> list[dict]:
    """Read a markdown file and split into chunks with metadata."""
    rel_path = str(file_path.relative_to(vault_root))
    
    content = file_path.read_text(encoding="utf-8")
    
    # Extract title from first heading or filename
    title_match = re.match(r'^#\s+(.+)$', content, re.MULTILINE)
    title = title_match.group(1).strip() if title_match else file_path.stem
    
    # Derive namespace sub-path from directory structure
    # e.g., systems/financeiro.md -> /memory/obsidian/systems/financeiro
    namespace_sub = rel_path.replace(".md", "").replace("/", ":")
    
    chunks = chunk_text(content)
    
    return [
        {
            "content": chunk,
            "metadata": {
                "file_path": rel_path,
                "title": title,
                "chunk_index": i,
                "total_chunks": len(chunks),
                "file_hash": hashlib.sha256(content.encode()).hexdigest()[:16],
            },
        }
        for i, chunk in enumerate(chunks)
    ]


def should_skip(rel_path: str) -> bool:
    """Check if file should be skipped."""
    for pattern in SKIP_PATTERNS:
        if pattern in rel_path:
            return True
    return False


def main():
    parser = argparse.ArgumentParser(description="Index Obsidian vault into pgvector")
    parser.add_argument("--vault", required=True, help="Path to vault memory directory")
    parser.add_argument("--tei", required=True, help="TEI endpoint URL")
    parser.add_argument("--pg", required=True, help="PostgreSQL connection string")
    parser.add_argument("--namespace", default="/memory/obsidian", help="Namespace prefix")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be indexed")
    parser.add_argument("--rebuild", action="store_true", help="Clear namespace before indexing")
    args = parser.parse_args()
    
    vault_root = Path(args.vault)
    if not vault_root.exists():
        print(f"ERROR: vault path not found: {vault_root}")
        sys.exit(1)
    
    # Find all markdown files
    md_files = sorted(vault_root.rglob("*.md"))
    
    # Filter
    to_index = []
    for f in md_files:
        rel = str(f.relative_to(vault_root))
        if should_skip(rel):
            print(f"  SKIP: {rel}")
            continue
        to_index.append(f)
    
    print(f"\nFound {len(md_files)} markdown files, {len(to_index)} to index")
    
    if args.dry_run:
        print("\n=== DRY RUN ===")
        total_chunks = 0
        for f in to_index:
            chunks = file_to_chunks(f, vault_root)
            total_chunks += len(chunks)
            rel = str(f.relative_to(vault_root))
            print(f"  {rel}: {len(chunks)} chunks, {sum(len(c['content']) for c in chunks)} chars")
        print(f"\nTotal: {total_chunks} chunks across {len(to_index)} files")
        return
    
    # Connect to Postgres
    conn = psycopg2.connect(args.pg)
    conn.autocommit = False
    cur = conn.cursor()
    
    # Rebuild: clear existing entries
    if args.rebuild:
        cur.execute("DELETE FROM memory_entries WHERE namespace = %s", (args.namespace,))
        deleted = cur.rowcount
        conn.commit()
        print(f"Deleted {deleted} existing entries in namespace '{args.namespace}'")
    
    # Index
    total_indexed = 0
    total_files = 0
    errors = 0
    
    for f in to_index:
        rel = str(f.relative_to(vault_root))
        chunks = file_to_chunks(f, vault_root)
        
        print(f"\n  Indexing: {rel} ({len(chunks)} chunks)")
        
        for chunk in chunks:
            try:
                # Get embedding from TEI
                embedding = get_embedding(chunk["content"], args.tei)
                
                # Insert into pgvector
                cur.execute(
                    """
                    INSERT INTO memory_entries (namespace, content, embedding, source_agent, confidence, metadata)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    """,
                    (
                        args.namespace,
                        chunk["content"],
                        str(embedding),  # pgvector accepts "[1.0, 2.0, ...]" format
                        "obsidian-sync",
                        0.95,
                        json.dumps(chunk["metadata"]),
                    ),
                )
                total_indexed += 1
                print(f"    chunk {chunk['metadata']['chunk_index']}/{chunk['metadata']['total_chunks'] - 1} ✓")
                
                # Small delay to not hammer TEI
                time.sleep(0.1)
                
            except Exception as e:
                print(f"    chunk {chunk['metadata']['chunk_index']} ERROR: {e}")
                errors += 1
                conn.rollback()
                continue
        
        conn.commit()
        total_files += 1
    
    cur.close()
    conn.close()
    
    print(f"\n{'='*50}")
    print(f"Indexed: {total_indexed} chunks from {total_files} files")
    print(f"Errors:  {errors}")
    print(f"Namespace: {args.namespace}")
    print(f"{'='*50}")


if __name__ == "__main__":
    main()

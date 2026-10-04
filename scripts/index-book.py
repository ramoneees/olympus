#!/usr/bin/env python3
"""
Index a PDF book into pgvector (Mnemosyne schema).

Extracts text with PyMuPDF, chunks by paragraph (~512 tokens, 64 overlap),
embeds via TEI in batches, inserts into memory_entries.

Usage:
    python3.11 index-book.py \
        --pdf /path/to/book.pdf \
        --tei http://localhost:8080 \
        --pg "postgresql://postgres:***@localhost:5432/mnemosyne" \
        --namespace /memory/books \
        --title "Teologia Bíblica (Geerhardus Vos)" \
        --batch 16
"""

import argparse
import hashlib
import json
import re
import sys
import time
import urllib.request

try:
    import psycopg2
    import pymupdf
except ImportError as e:
    print(f"ERROR: missing dep: {e}. pip install psycopg2-binary pymupdf")
    sys.exit(1)


def chunk_text(text: str, max_tokens: int = 512, overlap: int = 64) -> list[str]:
    max_chars = max_tokens * 4
    overlap_chars = overlap * 4
    paragraphs = re.split(r"\n\n+", text.strip())
    chunks = []
    current = ""
    for para in paragraphs:
        para = para.strip()
        if not para:
            continue
        if len(current) + len(para) + 2 <= max_chars:
            current += ("\n\n" if current else "") + para
        else:
            if current:
                chunks.append(current)
            if chunks and overlap_chars > 0:
                current = chunks[-1][-overlap_chars:] + "\n\n" + para
            else:
                current = para
    if current:
        chunks.append(current)
    return chunks if chunks else [text.strip()]


def embed_batch(texts: list[str], tei_url: str, retries: int = 3) -> list[list[float]]:
    data = json.dumps({"inputs": texts}).encode("utf-8")
    last_err: Exception = RuntimeError("no attempts made")
    for attempt in range(retries):
        try:
            req = urllib.request.Request(
                f"{tei_url.rstrip('/')}/embed",
                data=data,
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=120) as resp:
                return json.loads(resp.read())
        except Exception as e:
            last_err = e
            wait = 30 * (attempt + 1)
            print(f"    embed retry {attempt + 1}/{retries} after {wait}s ({e})")
            time.sleep(wait)
    raise last_err


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--pdf", required=True)
    p.add_argument("--tei", required=True)
    p.add_argument("--pg", required=True)
    p.add_argument("--namespace", default="/memory/books")
    p.add_argument("--title", default=None, help="Book title for metadata")
    p.add_argument("--batch", type=int, default=16)
    p.add_argument("--pace", type=float, default=0.0, help="Sleep seconds between batches")
    p.add_argument("--source-agent", default="book-indexer")
    args = p.parse_args()

    title = args.title or args.pdf.split("/")[-1].rsplit(".", 1)[0]

    doc = pymupdf.open(args.pdf)
    with open(args.pdf, "rb") as fh:
        file_hash = hashlib.sha256(fh.read()).hexdigest()[:16]
    print(f"Book: {title}")
    print(f"PDF: {doc.page_count} pages, hash {file_hash}")

    # Extract + chunk, tagging each chunk with its page range
    all_chunks: list[tuple[str, int, int]] = []  # (text, page_start, page_end)
    for page_num in range(doc.page_count):
        text = doc[page_num].get_text().strip()
        if len(text) < 50:
            continue
        for chunk in chunk_text(text):
            if len(chunk.strip()) < 50:
                continue
            all_chunks.append((chunk, page_num + 1, page_num + 1))

    # Merge tiny fragments from same page into larger chunks for retrieval quality
    merged: list[tuple[str, int, int]] = []
    cur_text, cur_start, cur_end = "", 0, 0
    for text, ps, pe in all_chunks:
        if cur_text and len(cur_text) + len(text) + 2 > 2048:
            merged.append((cur_text, cur_start, cur_end))
            cur_text = text
            cur_start, cur_end = ps, pe
        else:
            cur_text += ("\n\n" if cur_text else "") + text
            if cur_start == 0:
                cur_start = ps
            cur_end = pe
    if cur_text:
        merged.append((cur_text, cur_start, cur_end))

    print(f"Chunks: {len(all_chunks)} raw -> {len(merged)} merged")

    conn = psycopg2.connect(args.pg)
    cur = conn.cursor()

    # Idempotent: drop previous entries for this exact book
    cur.execute(
        "DELETE FROM memory_entries WHERE namespace = %s AND metadata->>'file_hash' = %s",
        (args.namespace, file_hash),
    )
    if cur.rowcount:
        print(f"Removed {cur.rowcount} previous entries for same hash")
    conn.commit()

    total, errors, t0 = 0, 0, time.time()
    for i in range(0, len(merged), args.batch):
        batch = merged[i : i + args.batch]
        texts = [c[0] for c in batch]
        try:
            embs = embed_batch(texts, args.tei)
            assert len(embs) == len(texts), f"TEI returned {len(embs)} != {len(texts)}"
        except Exception as e:
            print(f"  batch {i}: EMBED ERROR {e}")
            errors += len(texts)
            continue

        for (text, ps, pe), emb in zip(batch, embs):
            try:
                meta = {
                    "file_path": args.pdf,
                    "title": title,
                    "chunk_index": total,
                    "pages": f"{ps}-{pe}" if ps != pe else str(ps),
                    "file_hash": file_hash,
                    "kind": "book",
                }
                cur.execute(
                    """INSERT INTO memory_entries
                       (namespace, content, embedding, source_agent, confidence, metadata)
                       VALUES (%s, %s, %s, %s, %s, %s)""",
                    (args.namespace, text, str(emb), args.source_agent, 0.95, json.dumps(meta)),
                )
                total += 1
            except Exception as e:
                print(f"  chunk {i}: INSERT ERROR {e}")
                errors += 1
        conn.commit()
        done = min(i + args.batch, len(merged))
        elapsed = time.time() - t0
        rate = done / elapsed if elapsed > 0 else 0
        eta = (len(merged) - done) / rate if rate > 0 else 0
        print(f"  progress: {done}/{len(merged)} chunks ({rate:.1f}/s, ETA {eta:.0f}s)")
        time.sleep(args.pace)  # let TEI CPU breathe; liveness probe kills it under sustained load

    cur.close()
    conn.close()
    print(f"\nDONE: {total} indexed, {errors} errors, namespace '{args.namespace}', {time.time()-t0:.0f}s total")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3.11
"""Indexa o Regulamento do Condomínio no Mnemosyne (pgvector) — chunk por ARTIGO.
Pré-requisitos: port-forwards 8080 (tei) e 15432 (postgresql) ativos, PG_PASSWORD exportada.
Uso: python3.11 index_regulamento.py
"""
import json, os, re, sys, time, urllib.request

import psycopg2

MD = "/Users/ramoneees/obsidian-vault/Casa/Regulamento Condomínio Quinta da Oliveira.md"
TEI = os.environ.get("TEI_URL", "http://localhost:8080")
DSN = os.environ.get(
    "MNEMOSYNE_PG_URL",
    f"postgresql://postgres:{os.environ.get('PG_PASSWORD', '')}@localhost:15432/mnemosyne",
)
NAMESPACE = "/memory/casa"
TITLE = "Regulamento do Condomínio Quinta da Oliveira (DGI, 2026)"

md = open(MD, encoding="utf-8").read()
# chunks: header + cada ARTIGO (ou secção até ao próximo ##)
parts = re.split(r"(?m)^(## .+)$", md)
chunks = [("preambulo", parts[0].strip())]
for i in range(1, len(parts), 2):
    head, body = parts[i], parts[i + 1] if i + 1 < len(parts) else ""
    chunks.append((head.replace("## ", "").strip(), (head + "\n" + body).strip()))
chunks = [(h, b) for h, b in chunks if len(b) > 60]
print(f"{len(chunks)} chunks")

def embed(text, tries=3):
    for t in range(tries):
        try:
            req = urllib.request.Request(
                f"{TEI}/embed", data=json.dumps({"inputs": text}).encode(),
                headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=90) as r:
                return json.loads(r.read())[0]
        except Exception as e:
            print(f"  embed retry {t+1}: {e}"); time.sleep(5 * (t + 1))
    raise SystemExit("TEI indisponível")

conn = psycopg2.connect(DSN)
cur = conn.cursor()
cur.execute("DELETE FROM memory_entries WHERE namespace = %s", (NAMESPACE,))  # idempotente
for i, (head, body) in enumerate(chunks):
    emb = "[" + ",".join(str(x) for x in embed(body)) + "]"
    cur.execute(
        "INSERT INTO memory_entries (content, metadata, namespace, embedding, source_agent) VALUES (%s,%s,%s,%s::vector,%s)",
        (body, json.dumps({"kind": "document", "title": TITLE, "section": head,
                           "file_path": MD, "chunk_index": i}, ensure_ascii=False),
         NAMESPACE, emb, "olympus-indexer"))
    print(f"  [{i+1}/{len(chunks)}] {head[:50]}")
    time.sleep(0.4)  # TEI em CPU
conn.commit()
cur.execute("SELECT count(*) FROM memory_entries WHERE namespace = %s", (NAMESPACE,))
print("OK —", cur.fetchone()[0], "entradas em", NAMESPACE)
cur.close(); conn.close()

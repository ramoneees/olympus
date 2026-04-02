#!/usr/bin/env python3
"""
Obsidian to pgvector Sync Script

Syncs Obsidian vault notes to the OLYMPUS pgvector database.
Uses bge-m3 embeddings via LiteLLM/Ollama.

Setup:
  pip install psycopg2-binary requests python-dotenv

Usage:
  python obsidian-pgvector-sync.py /path/to/vault

Environment variables (or .env file):
  DB_HOST=postgresql.databases.svc.cluster.local
  DB_PORT=5432
  DB_NAME=mnemosyne
  DB_USER=mnemosyne
  DB_PASSWORD=your-password
  EMBEDDING_URL=http://litellm.olympus.svc.cluster.local:4000
  EMBEDDING_MODEL=bge-m3
"""

import os
import sys
import hashlib
import json
import requests
import psycopg2
from datetime import datetime
from pathlib import Path
from typing import Optional, List
from dotenv import load_dotenv

load_dotenv()

class ObsidianPgvectorSync:
    def __init__(self, vault_path: str):
        self.vault_path = Path(vault_path).expanduser().resolve()
        self.db_config = {
            'host': os.getenv('DB_HOST', 'postgresql.databases.svc.cluster.local'),
            'port': int(os.getenv('DB_PORT', 5432)),
            'database': os.getenv('DB_NAME', 'mnemosyne'),
            'user': os.getenv('DB_USER', 'mnemosyne'),
            'password': os.getenv('DB_PASSWORD', ''),
        }
        self.embedding_url = os.getenv('EMBEDDING_URL', 'http://litellm.olympus.svc.cluster.local:4000')
        self.embedding_model = os.getenv('EMBEDDING_MODEL', 'bge-m3')
        self.namespace = '/memory/obsidian'
        self.source_agent = 'obsidian-sync'
        self.batch_size = int(os.getenv('BATCH_SIZE', 10))
        
    def connect_db(self):
        return psycopg2.connect(**self.db_config)
    
    def get_file_hash(self, filepath: Path) -> str:
        with open(filepath, 'rb') as f:
            return hashlib.md5(f.read()).hexdigest()
    
    def get_embedding(self, text: str) -> Optional[List[float]]:
        try:
            response = requests.post(
                f"{self.embedding_url}/embeddings",
                headers={"Content-Type": "application/json"},
                json={
                    "model": self.embedding_model,
                    "input": text[:8000]  # bge-m3 context limit
                },
                timeout=60
            )
            response.raise_for_status()
            data = response.json()
            return data['data'][0]['embedding']
        except Exception as e:
            print(f"  Error getting embedding: {e}")
            return None
    
    def get_existing_files(self, conn) -> dict:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT metadata->>'file_path', metadata->>'file_hash'
                FROM memory_entries
                WHERE namespace = %s
            """, (self.namespace,))
            return {row[0]: row[1] for row in cur.fetchall()}
    
    def get_markdown_files(self) -> List[Path]:
        files = []
        for ext in ['*.md', '*.markdown']:
            files.extend(self.vault_path.rglob(ext))
        return [f for f in files if not any(part.startswith('.') for part in f.parts)]
    
    def extract_tags(self, content: str) -> List[str]:
        import re
        tags = re.findall(r'#(\w+[\w/-]*)', content)
        yaml_tags = re.findall(r'tags:\s*\[(.*?)\]', content)
        for yt in yaml_tags:
            tags.extend([t.strip() for t in yt.split(',')])
        return list(set(tags))
    
    def extract_title(self, filepath: Path, content: str) -> str:
        lines = content.split('\n')
        for line in lines[:5]:
            if line.startswith('# '):
                return line[2:].strip()
        return filepath.stem
    
    def upsert_note(self, conn, filepath: Path, content: str):
        relative_path = str(filepath.relative_to(self.vault_path))
        file_hash = self.get_file_hash(filepath)
        title = self.extract_title(filepath, content)
        tags = self.extract_tags(content)
        
        print(f"  Processing: {relative_path}")
        
        embedding = self.get_embedding(content)
        if not embedding:
            print(f"  Skipping (no embedding): {relative_path}")
            return False
        
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO memory_entries 
                    (namespace, content, embedding, source_agent, confidence, metadata)
                VALUES 
                    (%s, %s, %s::vector, %s, %s, %s)
                ON CONFLICT (id) DO UPDATE SET
                    content = EXCLUDED.content,
                    embedding = EXCLUDED.embedding,
                    timestamp = NOW(),
                    metadata = EXCLUDED.metadata
            """, (
                self.namespace,
                content[:50000],  # Limit content size
                embedding,
                self.source_agent,
                0.95,
                json.dumps({
                    'file_path': relative_path,
                    'file_hash': file_hash,
                    'title': title,
                    'tags': tags,
                    'vault': self.vault_path.name
                })
            ))
        conn.commit()
        return True
    
    def delete_note(self, conn, file_path: str):
        with conn.cursor() as cur:
            cur.execute("""
                DELETE FROM memory_entries
                WHERE namespace = %s AND metadata->>'file_path' = %s
            """, (self.namespace, file_path))
        conn.commit()
        print(f"  Deleted: {file_path}")
    
    def sync(self):
        print(f"=== Obsidian → pgvector Sync ===")
        print(f"Vault: {self.vault_path}")
        print(f"Database: {self.db_config['host']}:{self.db_config['port']}/{self.db_config['database']}")
        print(f"Embedding: {self.embedding_model} @ {self.embedding_url}")
        print()
        
        conn = self.connect_db()
        
        existing = self.get_existing_files(conn)
        markdown_files = self.get_markdown_files()
        
        current_paths = set()
        added = 0
        updated = 0
        errors = 0
        
        for filepath in markdown_files:
            relative_path = str(filepath.relative_to(self.vault_path))
            current_paths.add(relative_path)
            file_hash = self.get_file_hash(filepath)
            
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            if relative_path not in existing:
                print(f"[NEW] {relative_path}")
                if self.upsert_note(conn, filepath, content):
                    added += 1
                else:
                    errors += 1
            elif existing[relative_path] != file_hash:
                print(f"[UPD] {relative_path}")
                if self.upsert_note(conn, filepath, content):
                    updated += 1
                else:
                    errors += 1
        
        # Delete removed files
        deleted = 0
        for old_path in existing:
            if old_path not in current_paths:
                print(f"[DEL] {old_path}")
                self.delete_note(conn, old_path)
                deleted += 1
        
        conn.close()
        
        print()
        print("=== Sync Complete ===")
        print(f"Added: {added}")
        print(f"Updated: {updated}")
        print(f"Deleted: {deleted}")
        print(f"Errors: {errors}")
        print(f"Total in DB: {len(current_paths)}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python obsidian-pgvector-sync.py /path/to/vault")
        print("\nSet environment variables:")
        print("  DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD")
        print("  EMBEDDING_URL, EMBEDDING_MODEL")
        sys.exit(1)
    
    vault_path = sys.argv[1]
    syncer = ObsidianPgvectorSync(vault_path)
    syncer.sync()


if __name__ == '__main__':
    main()

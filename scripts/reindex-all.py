#!/usr/bin/env python3
"""
Re-index both Obsidian vault and Hermes sessions into pgvector.

Designed to run as a cron job or manually. Handles port-forwards
internally so it works from the Mac without manual setup.

Usage:
    python3 reindex-all.py
    python3 reindex-all.py --vault-only
    python3 reindex-all.py --sessions-only
"""

import argparse
import base64
import os
import signal
import subprocess
import sys
import time
import urllib.request

# Paths
VAULT_DIR = "/Users/ramoneees/obsidian-vault/memory"
STATE_DB = "/Users/ramoneees/.hermes/state.db"
INDEX_VAULT = "/Users/ramoneees/dev/olympus/scripts/index-vault.py"
INDEX_SESSIONS = "/Users/ramoneees/dev/olympus/scripts/index-sessions.py"

# Cluster
TEI_PORT = 8080
PG_PORT = 5432


def get_pg_password():
    r = subprocess.run(
        ["kubectl", "get", "secret", "-n", "databases", "postgresql-secret",
         "-o", "jsonpath={.data.postgres-password}"],
        capture_output=True, text=True
    )
    return base64.b64decode(r.stdout.strip()).decode()


def start_port_forwards():
    """Start kubectl port-forwards. Returns PIDs."""
    # Kill existing
    subprocess.run(["bash", "-c", f"lsof -ti :{TEI_PORT} | xargs kill 2>/dev/null"], capture_output=True)
    subprocess.run(["bash", "-c", f"lsof -ti :{PG_PORT} | xargs kill 2>/dev/null"], capture_output=True)
    time.sleep(2)
    
    tei_pf = subprocess.Popen(
        ["kubectl", "port-forward", "-n", "olympus", "svc/tei", f"{TEI_PORT}:80"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )
    pg_pf = subprocess.Popen(
        ["kubectl", "port-forward", "-n", "databases", "svc/postgresql", f"{PG_PORT}:5432"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )
    time.sleep(5)
    
    # Verify
    try:
        urllib.request.urlopen(f"http://localhost:{TEI_PORT}/health", timeout=5)
        print("TEI: OK")
    except:
        print("TEI: FAIL")
        return None, None
    
    pg_pw = get_pg_password()
    os.environ["PGPASSWORD"] = pg_pw
    os.environ["PATH"] = "/opt/homebrew/opt/libpq/bin:" + os.environ.get("PATH", "")
    
    # Test PG
    r = subprocess.run(
        ["psql", "-h", "localhost", "-U", "postgres", "-d", "mnemosyne", "-c", "SELECT 1;"],
        capture_output=True, text=True, timeout=10
    )
    if r.returncode == 0:
        print("PG: OK")
    else:
        print(f"PG: FAIL ({r.stderr[:100]})")
        return None, None
    
    return tei_pf, pg_pf


def stop_port_forwards(tei_pf, pg_pf):
    if tei_pf:
        tei_pf.terminate()
    if pg_pf:
        pg_pf.terminate()
    time.sleep(1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--vault-only", action="store_true")
    parser.add_argument("--sessions-only", action="store_true")
    args = parser.parse_args()
    
    do_vault = not args.sessions_only
    do_sessions = not args.vault_only
    
    print("=== Starting port-forwards ===")
    tei_pf, pg_pf = start_port_forwards()
    if not tei_pf or not pg_pf:
        print("FATAL: port-forwards failed")
        sys.exit(1)
    
    pg_pw = get_pg_password()
    pg_url = f"postgresql://postgres:{pg_pw}@localhost:5432/mnemosyne"
    tei_url = f"http://localhost:{TEI_PORT}"
    
    try:
        if do_vault:
            print("\n=== Indexing vault ===")
            r = subprocess.run(
                [sys.executable, INDEX_VAULT,
                 "--vault", VAULT_DIR,
                 "--tei", tei_url,
                 "--pg", pg_url,
                 "--namespace", "/memory/obsidian",
                 "--rebuild"],
                timeout=300
            )
            print(f"Vault exit code: {r.returncode}")
        
        if do_sessions:
            print("\n=== Indexing sessions ===")
            r = subprocess.run(
                [sys.executable, INDEX_SESSIONS,
                 "--db", STATE_DB,
                 "--tei", tei_url,
                 "--pg", pg_url,
                 "--namespace", "/memory/sessions",
                 "--rebuild"],
                timeout=600
            )
            print(f"Sessions exit code: {r.returncode}")
        
        # Stats
        print("\n=== Final stats ===")
        r = subprocess.run(
            ["psql", "-h", "localhost", "-U", "postgres", "-d", "mnemosyne", "-c",
             "SELECT namespace, COUNT(*) FROM memory_entries GROUP BY namespace ORDER BY namespace;"],
            capture_output=True, text=True, timeout=10
        )
        print(r.stdout)
        
    finally:
        stop_port_forwards(tei_pf, pg_pf)


if __name__ == "__main__":
    main()

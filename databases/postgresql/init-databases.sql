-- Run after PostgreSQL is up to create per-service databases and users
-- kubectl exec -it postgresql-0 -n databases -- psql -U postgres -f /tmp/init-databases.sql
-- Or copy-paste into psql session

-- Gitea
CREATE DATABASE gitea;
CREATE USER gitea WITH PASSWORD 'CHANGE_ME';
GRANT ALL PRIVILEGES ON DATABASE gitea TO gitea;
ALTER DATABASE gitea OWNER TO gitea;

-- Authentik
CREATE DATABASE authentik;
CREATE USER authentik WITH PASSWORD 'CHANGE_ME';
GRANT ALL PRIVILEGES ON DATABASE authentik TO authentik;
ALTER DATABASE authentik OWNER TO authentik;

-- Mattermost
CREATE DATABASE mattermost;
CREATE USER mattermost WITH PASSWORD 'CHANGE_ME';
GRANT ALL PRIVILEGES ON DATABASE mattermost TO mattermost;
ALTER DATABASE mattermost OWNER TO mattermost;

-- Vikunja
CREATE DATABASE vikunja;
CREATE USER vikunja WITH PASSWORD 'CHANGE_ME';
GRANT ALL PRIVILEGES ON DATABASE vikunja TO vikunja;
ALTER DATABASE vikunja OWNER TO vikunja;

-- LiteLLM
CREATE DATABASE litellm;
CREATE USER litellm WITH PASSWORD 'CHANGE_ME';
GRANT ALL PRIVILEGES ON DATABASE litellm TO litellm;
ALTER DATABASE litellm OWNER TO litellm;

-- n8n
CREATE DATABASE n8n;
CREATE USER n8n WITH PASSWORD 'CHANGE_ME';
GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n;
ALTER DATABASE n8n OWNER TO n8n;

-- Uptime Kuma (optional — it uses SQLite by default, but can use PG)
-- CREATE DATABASE uptimekuma;

-- pgvector for Mnemosyne memory
CREATE DATABASE mnemosyne;
CREATE USER mnemosyne WITH PASSWORD 'CHANGE_ME';
GRANT ALL PRIVILEGES ON DATABASE mnemosyne TO mnemosyne;
ALTER DATABASE mnemosyne OWNER TO mnemosyne;
\c mnemosyne
CREATE EXTENSION IF NOT EXISTS vector;

-- AI Gitea Bot
CREATE DATABASE aigiteabot;
CREATE USER aigiteabot WITH PASSWORD 'cc8QKWq62g0NMtGd';
GRANT ALL PRIVILEGES ON DATABASE aigiteabot TO aigiteabot;
ALTER DATABASE aigiteabot OWNER TO aigiteabot;

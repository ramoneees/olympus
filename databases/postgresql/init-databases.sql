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

-- Paperclip
CREATE DATABASE paperclip;
CREATE USER paperclip WITH PASSWORD 'CHANGE_ME';
GRANT ALL PRIVILEGES ON DATABASE paperclip TO paperclip;
ALTER DATABASE paperclip OWNER TO paperclip;

-- Precisa-se (schema.prisma requires pgcrypto, citext, pg_trgm)
CREATE DATABASE precisase;
CREATE USER precisase WITH PASSWORD '196d8361f029f54edcb5498db6650bba167f53f3871dcdff';
GRANT ALL PRIVILEGES ON DATABASE precisase TO precisase;
ALTER DATABASE precisase OWNER TO precisase;
\c precisase
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Ghostfolio
CREATE DATABASE ghostfolio;
CREATE USER ghostfolio WITH PASSWORD 'b7e5cc963a7e6562f8291ef89006e182';
GRANT ALL PRIVILEGES ON DATABASE ghostfolio TO ghostfolio;
ALTER DATABASE ghostfolio OWNER TO ghostfolio;

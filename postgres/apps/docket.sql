SELECT 'CREATE ROLE docket LOGIN' WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'docket') \gexec
ALTER ROLE docket PASSWORD :'pw' CONNECTION LIMIT 15;
SELECT 'CREATE DATABASE docket OWNER docket' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'docket') \gexec
-- Semantic search. pgvector isn't a trusted extension, so the app can't enable it itself.
\connect docket
CREATE EXTENSION IF NOT EXISTS vector;

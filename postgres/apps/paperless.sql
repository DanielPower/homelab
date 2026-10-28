SELECT 'CREATE ROLE paperless LOGIN' WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'paperless') \gexec
ALTER ROLE paperless PASSWORD :'pw' CONNECTION LIMIT 30;
SELECT 'CREATE DATABASE paperless OWNER paperless' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'paperless') \gexec

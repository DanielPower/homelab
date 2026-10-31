SELECT 'CREATE ROLE osu_observer LOGIN' WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'osu_observer') \gexec
ALTER ROLE osu_observer PASSWORD :'pw' CONNECTION LIMIT 15;
SELECT 'CREATE DATABASE osu_observer OWNER osu_observer' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'osu_observer') \gexec

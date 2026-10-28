# Shared Postgres

One Postgres 18 server for every app that works with stock Postgres. Each app gets its own role and database. Data lives on local NVMe. pgBackRest sends WAL continuously and takes nightly backups (full on Sundays, diff otherwise) to the QNAP at `main/lab/postgres-backup`. The QNAP copies that folder to Backblaze. See `RESTORE.md` for restores.

Apps that need a special Postgres build or extensions (e.g. Immich and VectorChord) keep their own server.

## Adding an app

1. **Role and database.** Create `apps/<name>.sql`, copying `apps/paperless.sql` and replacing the name. Set `CONNECTION LIMIT` to about the app's pool size plus headroom. The limits added together must stay under `max_connections` (100 by default).
2. **Password.** Add `<NAME>_DB_PASSWORD=<random>` to `.env` (`openssl rand -base64 33 | tr -d '/+=' | head -c 40`). Pass it to the `postgres` service's `environment` in `compose.yml`.
3. **Apply.** Run `docker compose up -d` here to pick up the new variable. It restarts Postgres, so every app reconnects. Then run:

       docker compose exec postgres /docker-entrypoint-initdb.d/01-apps.sh

   The script can be run any number of times. It creates missing roles and databases and updates passwords and limits.
4. **Connect the app.** In the app's `compose.yml`, add the `db` network to every service that talks to the database, and declare it at the bottom:

       networks:
         db:
           external: true

   Point the app at host `postgres`, port `5432`, database and user `<name>`, without SSL (e.g. `postgresql://<name>:<pw>@postgres:5432/<name>?sslmode=disable`). Keep the password in the app's own `.env`.
5. **Existing data (if any).** Stop the app. Then:

       pg_dump -Fc --no-acl ... > <name>.dump
       docker exec -i postgres pg_restore -U postgres -d <name> --no-owner --role=<name> --no-acl --single-transaction --exit-on-error < <name>.dump

   Compare the row count of every table between old and new before switching over.
6. **Verify.** Start the app and check its logs and the UI. Then take a full backup so the new data has a clean restore point:

       docker compose exec pgbackrest pgbackrest --stanza=main --type=full backup

7. **Clean up.** Remove the app's old database container. Keep its old data folder until you're confident, then delete it.

## Restoring one database

    ./restore-db.sh <database> ["<target time>"]     # e.g. "2026-10-28 14:00:00-02:30"; omit for latest

The script restores that database into a throwaway container. It mounts the repo read-only and turns archiving off, so it can't touch production or the backups. It then loads the result into the live server as `<database>_restored_<YYYYmmddHHMM>`. Production is not changed.

**Limit:** the target time must be after the most recent full or diff backup that contains the database. A database created after the last backup can't be restored until the next backup runs.

To compare first, query the restored copy next to the live one. To swap it in:

    cd ../<app> && docker compose stop      # everything that uses the DB
    docker exec postgres psql -U postgres -c 'alter database "<db>" rename to "<db>_old"'
    docker exec postgres psql -U postgres -c 'alter database "<db>_restored_<ts>" rename to "<db>"'
    docker compose up -d

When you're happy, drop the old copy with `drop database "<db>_old"`. To discard a restored copy instead, `drop database "<db>_restored_<ts>"`.

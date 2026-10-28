# Postgres restore runbook

Run these from `postgres/`. Backups live on the QNAP at `main/lab/postgres-backup`, mounted over NFS at `/backups` in both containers. The QNAP copies them to Backblaze nightly. You need `PGBACKREST_CIPHER_PASS` from the password manager to restore.

## See what's restorable
    docker compose exec pgbackrest pgbackrest --stanza=main info

## Point-in-time restore (whole cluster)
Restores every database to the given moment. Stop the apps that write to it first.

    docker compose stop pgbackrest postgres
    docker compose run --rm --no-deps --entrypoint pgbackrest pgbackrest \
        --stanza=main --delta --type=time \
        "--target=2026-10-27 14:00:00-02:30" --target-action=promote restore
    docker compose up -d

Check `docker logs postgres` for `recovery stopping before ...` and `selected new timeline`. Archiving continues on the new timeline on its own.

Other targets:
- Latest state: drop `--type`/`--target`.
- A specific backup: `--set=20261028-004607F`.

## Restore just one database
Restore into a throwaway stack so production keeps running, then `pg_dump` the database you need and `pg_restore` it into production. Use a separate project name (`-p pgrestore`), give its postgres service another `container_name`, and point it at the same repo with the same env.

## Restore drill (yearly)
Do the steps above in a throwaway project. Check that row counts and the newest rows look right, then `down -v`.

## Rebuild from Backblaze (the QNAP is gone)
Download the `postgres-backup` folder from Backblaze to local disk. Mount it at `/backups` in place of the NFS volume, for example with a `compose.override.yml`. Then run the restore above.

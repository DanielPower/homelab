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
Use `./restore-db.sh <database> ["<target time>"]`. The whole-cluster restore above rolls back every app. This script restores one database alongside the live one and leaves production running. See README.md for how to swap the copy in.

## Restore drill (yearly)
Run `./restore-db.sh <db>` for each app database. Check that row counts and the newest rows match the live database, then drop the `_restored_` copies.

## Rebuild from Backblaze (the QNAP is gone)
Download the `postgres-backup` folder from Backblaze to local disk. Mount it at `/backups` in place of the NFS volume, for example with a `compose.override.yml`. Then run the restore above.

#!/bin/bash
# Restore one database from the pgBackRest repo into a NEW database next to the
# live one, without touching production.
#
#   ./restore-db.sh <database> ["<target time>"]
#   ./restore-db.sh paperless "2026-10-28 14:00:00-02:30"
#   ./restore-db.sh libby                  # latest state in the archive
#
# It restores just that database into a throwaway container (repo mounted
# read-only, archiving off), dumps it, and loads it into the live server as
# <database>_restored_<YYYYmmddHHMM>, owned by the same app role. Swapping it
# in is left to you; see README.md.
set -euo pipefail
cd "$(dirname "$0")"

db=${1:?usage: $0 <database> [\"<target time>\"]}
target=${2:-}
case "$db" in postgres|template0|template1)
    echo "'$db' is a system database; pgBackRest only restores it with the whole cluster (see RESTORE.md)" >&2; exit 1;;
esac
image=local/postgres-pgbackrest
scratch=pgrestore-$$
new="${db}_restored_$(date +%Y%m%d%H%M)"

psql_live() { docker exec postgres psql -U postgres -v ON_ERROR_STOP=1 -Atq "$@"; }

owner=$(psql_live -c "select pg_get_userbyid(datdba) from pg_database where datname = '$db'")
[ -n "$owner" ] || { echo "no database '$db' on the live server" >&2; exit 1; }
[ -z "$(psql_live -c "select 1 from pg_database where datname = '$new'")" ] || { echo "$new already exists" >&2; exit 1; }

cipher=$(grep '^PGBACKREST_CIPHER_PASS=' .env | cut -d= -f2-)
common=(--user postgres -e PGBACKREST_REPO1_CIPHER_PASS="$cipher"
        -v "$scratch:/var/lib/postgresql" -v postgres_backups:/backups:ro)

cleanup() {
    docker rm -f "$scratch" >/dev/null 2>&1 || true
    docker volume rm "$scratch" >/dev/null 2>&1 || true
}
trap cleanup EXIT

args=(--stanza=main --db-include="$db" --archive-mode=off)
[ -n "$target" ] && args+=(--type=time "--target=$target" --target-action=promote)

echo "==> restoring '$db'${target:+ to $target} into a scratch volume"
docker volume create "$scratch" >/dev/null
docker run --rm "${common[@]}" --entrypoint sh "$image" -c \
    'mkdir -p -m 700 /var/lib/postgresql/18/docker && exec pgbackrest "$@"' sh "${args[@]}" restore

echo "==> starting throwaway server and waiting for recovery"
docker run -d --name "$scratch" "${common[@]}" "$image" \
    postgres -c archive_mode=off -c listen_addresses='' >/dev/null
for _ in $(seq 1 120); do
    state=$(docker exec "$scratch" psql -U postgres -Atqc 'select pg_is_in_recovery()' 2>/dev/null || true)
    [ "$state" = f ] && break
    sleep 2
done
[ "$state" = f ] || { echo "recovery did not finish; logs:" >&2; docker logs --tail 30 "$scratch" >&2; exit 1; }

echo "==> loading into live server as '$new' (owner $owner)"
psql_live -c "create database \"$new\" owner \"$owner\""
docker exec "$scratch" pg_dump -U postgres -Fc --no-acl "$db" \
    | docker exec -i postgres pg_restore -U postgres -d "$new" --no-owner --role="$owner" --no-acl --exit-on-error

echo "==> done: '$new' is on the live server. See README.md to swap it in or drop it."

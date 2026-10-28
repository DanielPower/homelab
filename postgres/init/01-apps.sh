#!/bin/bash
# Creates or updates each app's role and database from /apps/<name>.sql, with
# the password from <NAME>_DB_PASSWORD. Runs on first start (empty data dir).
# After adding an app, run it by hand:
#   docker compose exec postgres /docker-entrypoint-initdb.d/01-apps.sh
set -euo pipefail

for f in /apps/*.sql; do
    name=$(basename "$f" .sql)
    var="${name^^}_DB_PASSWORD"
    psql -v ON_ERROR_STOP=1 -U postgres -q -v pw="${!var:?$var is not set}" -f "$f"
    echo "app $name: ok"
done

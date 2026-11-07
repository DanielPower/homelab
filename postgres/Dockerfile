FROM postgres:18.6@sha256:e3d24f6906d0760bf4da0dae872415391ededefad23fd471c47dc53b0ddf3c42

RUN apt-get update \
    && apt-get install -y --no-install-recommends pgbackrest curl ca-certificates postgresql-18-pgvector \
    && rm -rf /var/lib/apt/lists/*

COPY pgbackrest.conf /etc/pgbackrest/pgbackrest.conf
COPY backup.sh /usr/local/bin/backup.sh

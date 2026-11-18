FROM postgres:18.7@sha256:2ea8630df176ad090ec92136dee850397c5af8781e4bcf2e4162593691c61bbc

RUN apt-get update \
    && apt-get install -y --no-install-recommends pgbackrest curl ca-certificates postgresql-18-pgvector \
    && rm -rf /var/lib/apt/lists/*

COPY pgbackrest.conf /etc/pgbackrest/pgbackrest.conf
COPY backup.sh /usr/local/bin/backup.sh

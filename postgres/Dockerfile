FROM postgres:18.6@sha256:979bccfde35445db618c65107d27d08c6c21339d8dc3ad4c830c6633947be0e4

RUN apt-get update \
    && apt-get install -y --no-install-recommends pgbackrest curl ca-certificates postgresql-18-pgvector \
    && rm -rf /var/lib/apt/lists/*

COPY pgbackrest.conf /etc/pgbackrest/pgbackrest.conf
COPY backup.sh /usr/local/bin/backup.sh

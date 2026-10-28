FROM postgres:18.6

RUN apt-get update \
    && apt-get install -y --no-install-recommends pgbackrest curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY pgbackrest.conf /etc/pgbackrest/pgbackrest.conf
COPY backup.sh /usr/local/bin/backup.sh

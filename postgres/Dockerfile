FROM postgres:18.6@sha256:edb0c08dc33befd0262ab3b5cf1c4f3f8cfd8b09e88c05b45adee29d6761ddb6

RUN apt-get update \
    && apt-get install -y --no-install-recommends pgbackrest curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY pgbackrest.conf /etc/pgbackrest/pgbackrest.conf
COPY backup.sh /usr/local/bin/backup.sh

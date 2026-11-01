FROM postgres:18.6@sha256:3a4264520e121176619f54ff867d12774bc81e95e7b84db58d63bccdb6144b81

RUN apt-get update \
    && apt-get install -y --no-install-recommends pgbackrest curl ca-certificates postgresql-18-pgvector \
    && rm -rf /var/lib/apt/lists/*

COPY pgbackrest.conf /etc/pgbackrest/pgbackrest.conf
COPY backup.sh /usr/local/bin/backup.sh

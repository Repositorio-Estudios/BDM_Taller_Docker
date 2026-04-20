FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y \
        tzdata \
        software-properties-common \
        curl \
        wget \
        gnupg \
        perl \
        build-essential \
        libsqlite3-dev \
        sqlite3 \
        libmariadb-dev \
        default-mysql-client

RUN wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | apt-key add - && \
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list && \
    apt-get update && \
    apt-get install -y mongodb-mongosh

RUN apt-get update && \
    apt-get install -y mongodb-org-tools && \
    rm -rf /var/lib/apt/lists/*

RUN curl -L https://cpanmin.us | perl - App::cpanminus

RUN cpanm --notest Mojolicious && \
    cpanm --notest DBD::SQLite && \
    cpanm --notest MongoDB && \
    cpanm --notest JSON && \
    cpanm --notest File::Slurp && \
    cpanm --notest Log::Log4perl

COPY almacen.sqlite /app/data/almacen.sqlite
COPY mojo_app.pl /app/mojo_app.pl

WORKDIR /app

CMD ["perl", "mojo_app.pl", "daemon", "-m", "production", "-l", "http://*:8080"]
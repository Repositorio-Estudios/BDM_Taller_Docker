FROM ubuntu:22.04

# Configurar el entorno para evitar preguntas interactivas
ENV DEBIAN_FRONTEND=noninteractive

# Instalar dependencias básicas
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

# Agregar el repositorio para mongosh
RUN wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | apt-key add - && \
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list && \
    apt-get update && \
    apt-get install -y mongodb-mongosh

# Instalar las herramientas de administración de MongoDB
RUN apt-get update && \
    apt-get install -y mongodb-org-tools && \
    rm -rf /var/lib/apt/lists/*

# Instalar cpanminus
RUN curl -L https://cpanmin.us | perl - App::cpanminus

# Instalar Mojolicious, DBD::SQLite, MongoDB, JSON, File::Slurp y Log::Log4perl
RUN cpanm --notest Mojolicious && \
    cpanm --notest DBD::SQLite && \
    cpanm --notest MongoDB && \
    cpanm --notest JSON && \
    cpanm --notest File::Slurp && \
    cpanm --notest Log::Log4perl

# Copiar la base de datos SQLite a la ubicación correcta
COPY almacen.sqlite /app/data/almacen.sqlite

# Copiar el archivo mojo_app.pl
COPY mojo_app.pl /app/mojo_app.pl

# Establecer el directorio de trabajo
WORKDIR /app

# Comando para ejecutar la aplicación
CMD ["perl", "mojo_app.pl", "daemon", "-m", "production", "-l", "http://*:8080"]


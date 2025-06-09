#!/bin/fish

set REL_ROOT_DIR (dirname (status --current-filename))
set ROOT_DIR (
    set relativePath $REL_ROOT_DIR
    set currentPath (pwd)
    cd $relativePath
    set absolutePath (pwd)
    cd $currentPath
    echo $absolutePath
)
set DOCKERS_DIR "$ROOT_DIR/dockers"
set compose_content "
version: '3'

services:
  $docker_name:
    image: $docker_name
    container_name: $docker_name
    ports:
      - '80:80'
"

if not test -d $DOCKERS_DIR
    mkdir -p $DOCKERS_DIR
    echo "Directorio 'dockers' creado"
end

set IMAGES "php:8.4-cli php:8.2-cli php:8.0-cli php:7.4-cli php:7.2-cli php:7.0-cli adminer mysql:latest"


switch $argv[1]
  case "--install-dockers"
    # Rango de versiones PHP
    set PHP_VERSIONS 84 82 80 74 72 70

    # Generar Dockerfiles y construir imágenes de php
    for ver in $PHP_VERSIONS
        set TAG (string sub -s 1 -l 1 $ver).(string sub -s 2 -l 1 $ver)
        set NAME "php$ver"
        set FILE "$DOCKERS_DIR/php/$NAME.dockerfile"

        echo "📝 Generando Dockerfile para PHP $TAG -> $FILE"

        echo "FROM php:$TAG-cli" > $FILE

        echo "🐳 Construyendo imagen $NAME..."
        docker build -f $FILE -t $NAME .
    end

    # Generar Dockerfile y construir imágen de adminer
    set ADMINER_FILE "$DOCKERS_DIR/adminer.dockerfile"

    echo "📝 Generando Dockerfile para Adminer -> $ADMINER_FILE"
    echo "FROM adminer" > $ADMINER_FILE
    echo "EXPOSE 8080" >> $ADMINER_FILE

    echo "🐳 Construyendo imagen adminer..."
    docker build -f $ADMINER_FILE -t adminer .

    # Generar Dockerfile y construir imágen de mysql

    set MYSQL_FILE "$DOCKERS_DIR/mysql.dockerfile"

    echo "📝 Generando Dockerfile para MySQL -> $MYSQL_FILE"
    echo "FROM mysql:latest" > $MYSQL_FILE
    echo "ENV MYSQL_ROOT_PASSWORD=root" >> $MYSQL_FILE
    echo "ENV MYSQL_DATABASE=facturascripts" >> $MYSQL_FILE
    echo "EXPOSE 3306" >> $MYSQL_FILE

    echo "✅ Todo listo. Dockerfiles y imágenes generados."  
end
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



switch $argv[1]
  case "--install-dockers"
    # Rango de versiones PHP
    set PHP_VERSIONS 84 82 80 74 72 70

    # Generar Dockerfiles y construir imágenes
    for ver in $PHP_VERSIONS
        set TAG (string sub -s 1 -l 1 $ver).(string sub -s 2 -l 1 $ver)
        set NAME "php$ver"
        set FILE "$DOCKERS_DIR/php/$NAME.dockerfile"

        echo "📝 Generando Dockerfile para PHP $TAG -> $FILE"

        echo "FROM php:$TAG-cli

          RUN apt-get update && apt-get install -y \\
              default-mysql-client \\
              && docker-php-ext-install pdo pdo_mysql

          WORKDIR /var/www
        " > $FILE
          

        echo "🐳 Construyendo imagen $NAME..."
        docker build -f $FILE -t $NAME .
    end

    echo "✅ Todo listo. Dockerfiles y imágenes generados."  
end
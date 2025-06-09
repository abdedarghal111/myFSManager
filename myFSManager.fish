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
set CACHE_DIR "$ROOT_DIR/.cache"
set DOCKERS_DIR "$ROOT_DIR/.dockers"

if not test -d $DOCKERS_DIR
    mkdir -p $DOCKERS_DIR
    echo "Directorio '.dockers' creado"
end

if not test -d $CACHE_DIR
    mkdir -p $CACHE_DIR
    echo "Directorio '.cache' creado"
end

set PHP_VERSIONS 84 82 80 74 72 70
set DOCKER_IMAGES adminer mysql:latest


switch $argv[1]
  case "--install"

    # install php
    for ver in $PHP_VERSIONS
        set TAG (string sub -s 1 -l 1 $ver).(string sub -s 2 -l 1 $ver)
        set NAME "php$ver"
        set DOCKER_TAG "php$ver-cli-fs-dev"
        set FILE "$DOCKERS_DIR/$NAME.dockerfile"

        echo "📝 Generando Dockerfile para PHP $TAG -> $FILE"

        echo "FROM php:$TAG-cli" > $FILE
        echo "ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/" >> $FILE
        echo "RUN install-php-extensions json fileinfo simplexml zip dom pdo pdo_mysql mysql mysqli pgsql pdo_pgsql bcmath gd curl soap"

        echo "🐳 Construyendo imagen $NAME..."
        docker build --no-cache -f $FILE -t $DOCKER_TAG $DOCKERS_DIR
    end

    # install dockers
    for image in $DOCKER_IMAGES
        echo "🔽 Descargando $image ..."
        docker pull $image

        set name (string replace -a ":" "-" $image)
        set fs_tag "$name-fs-dev"

        echo "🏷️ Etiquetando $image como $fs_tag"
        docker tag $image $fs_tag
    end

    echo "✅ Imágenes descargadas y etiquetadas con ':fs-dev'."

    # cache facturascripts
    set FS_DIR $CACHE_DIR/facturascripts
    if not test -d $FS_DIR/.git
      git clone https://github.com/NeoRazorX/facturascripts $FS_DIR
    end

    set currentPath (pwd)
    cd $FS_DIR

    git pull

    if not test -d MyFiles
      mkdir -p MyFiles
      touch MyFiles/plugins.json
    end

    composer install --prefer-dist --no-interaction --no-progress --optimize-autoloader

    echo "<?php

    define('FS_COOKIES_EXPIRE', 604800);
    define('FS_LANG', 'es_ES');
    define('FS_TIMEZONE', 'Europe/Madrid');
    define('FS_ROUTE', '');

    define('FS_DB_TYPE', 'mysql');
    define('FS_DB_HOST', '127.0.0.1');
    define('FS_DB_PORT', '3306');
    define('FS_DB_USER', 'root');

    define('FS_DB_NAME', 'facturascripts');
    define('FS_DB_PASS', 'root');
    define('FS_DB_FOREIGN_KEYS', true);
    define('FS_DB_TYPE_CHECK', true);
    define('FS_MYSQL_CHARSET', 'utf8');
    define('FS_MYSQL_COLLATE', 'utf8_bin');

    define('FS_HIDDEN_PLUGINS', '');
    define('FS_DEBUG', false);
    define('FS_DISABLE_ADD_PLUGINS', false);
    define('FS_DISABLE_RM_PLUGINS', false);
    define('FS_NF0', 2);

    " > config.php

    cd $currentPath

    echo "✅ Facturascripts descargado y actualizado."

    docker rmi $(docker images -qa -f 'dangling=true')
    echo "✅ Borrados dockers vacios."

  case "--runTests"

    set php82 php82-cli-fs-dev
    set mysql mysql-latest-fs-dev
    set mysqlName fsTestMysql
    set adminer adminer-fs-dev

    # run mysql
    docker run -d --rm \
      --name $mysqlName \
      --tmpfs /var/lib/mysql \
      -e MYSQL_ROOT_PASSWORD=root \
      -e MYSQL_DATABASE=facturascripts \
      -p 3306:3306 \
      $mysql

    while not docker exec $mysqlName mysqladmin ping -uroot -proot --silent > /dev/null 2>&1
      echo "⏳ Esperando a que MySQL esté listo..."
      sleep 1
    end
    echo "✅ MySQL listo."

    docker stop $mysqlName
end
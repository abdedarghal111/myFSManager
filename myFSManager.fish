#!/bin/fish

# user absolute current path
set CURRENT_DIR (pwd)
# relative root file path
set CURRENT_FILE (status --current-filename)
# relative root path
set REL_ROOT_DIR (dirname (status --current-filename))
# absolute root path
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

set PHP_VERSIONS 84 82 80
set DOCKER_IMAGES adminer mysql:latest

function isPlugin
  set target $argv[1]

  if not test -f "$target/facturascripts.ini"
      echo "❌ No es un plugin: no tiene facturascripts.ini"
      return 1
  end

  if not test -d "$target/Test/main"
      echo "❌ El plugin no tiene tests: no tiene Test/main"
      return 1
  end

  echo "✅ Es un plugin de FacturaScripts"
  return 0
end

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
        echo "RUN install-php-extensions json fileinfo simplexml zip dom pdo pdo_mysql mysqli pgsql pdo_pgsql bcmath gd curl soap" >> $FILE
        echo "RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer" >> $FILE
        # echo "RUN apt update && apt install tree" >> $FILE
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
    define('FS_DB_HOST', 'fsTestMysql');
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

    if ! isPlugin .
        return 1
    end

    set php php80-cli-fs-dev
    set phpName fsTestPhp
    set mysql mysql-latest-fs-dev
    set mysqlName fsTestMysql
    set adminer adminer-fs-dev

    # run mysql
    docker run -d --rm \
      --name $mysqlName \
      --network fs-network \
      --tmpfs /var/lib/mysql \
      -e MYSQL_ROOT_PASSWORD=root \
      -e MYSQL_DATABASE=facturascripts \
      -p 3306:3306 \
      $mysql

    echo "⏳ Esperando a que MySQL esté listo..."
    while not docker exec $mysqlName mysqladmin ping -uroot -proot --silent > /dev/null 2>&1
      sleep 0.3
    end
    echo "✅ MySQL listo."

    if test -f ./composer.son
      composer install --prefer-dist --no-interaction --no-progress --optimize-autoloader
    end

    if ! test -d $CACHE_DIR/facturascripts
      echo "🚫 No se ha descargado el repositorio de facturascripts."
      echo "Ejecuta 'myFSManager --install' para descargarlo."
      return 1
    end

    cd $CACHE_DIR/facturascripts
    git pull
    composer install --prefer-dist --no-interaction --no-progress --optimize-autoloader
    cd $CURRENT_DIR

    docker run -dit \
      --name $phpName \
      --network fs-network \
      --workdir /root/facturascripts \
      $php \
      bash

    docker cp $CACHE_DIR/facturascripts/. $phpName:/root/facturascripts &&
    docker cp ./Test/main/. $phpName:/root/facturascripts/Test/Plugins &&
    docker exec -w /root/facturascripts $phpName ls &&
    docker exec -w /root/facturascripts $phpName composer install --prefer-dist --no-interaction --no-progress --optimize-autoloader &&
    docker exec -w /root/facturascripts $phpName php Test/install-plugins.php &&
    docker exec -w /root/facturascripts $phpName ./vendor/bin/phpunit -c phpunit-plugins.xml --verbose

    docker stop $phpName
    docker rm $phpName
    docker stop $mysqlName
  case "a"
    ls $CACHE_DIR/facturascripts/
end
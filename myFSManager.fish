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

set globalNetwork fs-network
set mysql mysql-latest-fs-dev
set mysqlName fsTestMysql
set adminer adminer-fs-dev

set PHP_VERSIONS 84 82 80 74 72 70
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

function isFS
    set target $argv[1]
    set -l missing 0

    for item in Core Dinamic Test
        if not test -d "$target/$item"
            set missing 1
        end
    end

    for file in .php_cs composer.json package.json phpunit.xml phpunit-plugins.xml
        if not test -f "$target/$file"
            set missing 1
        end
    end

    if test $missing -eq 1
        echo "❌ No es un proyecto de FacturaScripts"
        return 1
    end

    echo "✅ Es un proyecto principal de FacturaScripts"
    return 0
end

function startMySQL
  docker run -d --rm \
    --name $mysqlName \
    --network $globalNetwork \
    --tmpfs /var/lib/mysql \
    -e MYSQL_ROOT_PASSWORD=root \
    -e MYSQL_DATABASE=facturascripts \
    $mysql
    # -p 3307:3306 \

  echo "⏳ Esperando a que MySQL esté listo..."
  while not docker exec $mysqlName mysqladmin ping -uroot -proot --silent > /dev/null 2>&1
    sleep 0.3
  end
  sleep 2
  echo "✅ MySQL listo."
end

function stopMySQL
  docker stop $mysqlName
end


if not test -d $DOCKERS_DIR
    mkdir -p $DOCKERS_DIR
    echo "Directorio '.dockers' creado"
end

if not test -d $CACHE_DIR
    mkdir -p $CACHE_DIR
    echo "Directorio '.cache' creado"
end




switch $argv[1]
  case "--install"

    docker network inspect $globalNetwork >/dev/null 2>&1 && docker network rm $globalNetwork
    docker network create $globalNetwork

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
        echo "RUN apt update && apt install nodejs npm -y" >> $FILE
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
    define('FS_DB_HOST', '$mysqlName');
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




  case "--runPluginTests"

    if ! isPlugin .
        return 1
    end

    set php php82-cli-fs-dev
    set phpName fsTestPhp

    # run mysql
    startMySQL

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

    docker run --rm -dit \
      --name $phpName \
      --network $globalNetwork \
      --workdir /root/facturascripts \
      $php \
      bash
      # --tmpfs /root/facturascripts/vendor:rw,size=1024m \

    docker cp $CACHE_DIR/facturascripts/. $phpName:/root/facturascripts &&
    set PLUGIN_NAME (basename (pwd)) &&
    docker exec $phpName mkdir -p /root/facturascripts/Plugins/$PLUGIN_NAME &&
    docker cp . $phpName:/root/facturascripts/Plugins/$PLUGIN_NAME &&
    docker exec -w /root/facturascripts $phpName composer install --prefer-dist --no-interaction --no-progress --optimize-autoloader &&
    docker exec -w /root/facturascripts $phpName cp -r Plugins/$PLUGIN_NAME/Test/main/. Test/Plugins/ &&
    docker exec -w /root/facturascripts/Plugins/$PLUGIN_NAME $phpName bash -c '
      if [ -f composer.json ]; then
        composer install --prefer-dist --no-interaction --no-progress --optimize-autoloader
      else
        echo "-------------------------------------------"
        echo "El plugin no tiene dependencias de Composer"
        echo "-------------------------------------------"
      fi
    ' &&
    docker exec -w /root/facturascripts $phpName php Test/install-plugins.php &&
    docker exec -w /root/facturascripts $phpName bash -c '
      chmod +x ./vendor/bin/phpunit
      ./vendor/bin/phpunit -c phpunit-plugins.xml --verbose
    '

    docker stop $phpName
    # docker rm $phpName
    stopMySQL




  case "--runFSTests"

    if ! isFS .
        return 1
    end

    if ! test -d $CACHE_DIR/facturascripts
      echo "🚫 No se ha descargado el repositorio de facturascripts."
      echo "Ejecuta 'myFSManager --install' para descargarlo."
      echo "Es necesario para extraer un config.php que se genera en --install"
      return 1
    end

    set php php82-cli-fs-dev
    set phpName fsTestPhp

    # run mysql
    startMySQL


    docker run --rm -dit \
      --name $phpName \
      --network $globalNetwork \
      --workdir /root/facturascripts \
      $php \
      bash

    composer install --prefer-dist --no-interaction --no-progress --optimize-autoloader &&
    docker cp . $phpName:/root/facturascripts &&
    docker cp "$CACHE_DIR/facturascripts/config.php" "$phpName:/root/facturascripts/config.php" &&
    docker exec -w /root/facturascripts $phpName cat config.php &&
    docker exec -it -w /root/facturascripts $phpName ./vendor/bin/phpunit
    # para los test de api: docker exec -it -w /root/facturascripts $phpName ./vendor/bin/phpunit -c phpunit-api.xml Test/API/* --verbose

    #./vendor/bin/phpunit -c phpunit-plugins.xml --verbose

    docker stop $phpName
    stopMySQL




  case "--runFSInstance"
  
    set php php82-cli-fs-dev
    set phpName fsWebPhp
    set puerto 8088

    if ! isFS .
        echo "🚫 Este directorio no parece un proyecto FacturaScripts válido."
        return 1
    end

    if ! test -d $CACHE_DIR/facturascripts
        echo "🚫 No se ha descargado el repositorio de FacturaScripts."
        echo "Ejecuta 'myFSManager --install' para descargarlo."
        return 1
    end

    # Iniciar contenedor MySQL
    startMySQL

    # Crear contenedor PHP
    docker run --rm -dit \
        --name $phpName \
        --network $globalNetwork \
        --workdir /root/facturascripts \
        -p $puerto:$puerto \
        $php \
        bash

    echo "📦 Instalando dependencias de PHP con Composer..." &&
    composer install --prefer-dist --no-interaction --no-progress --optimize-autoloader &&
    echo "📦 Instalando dependencias de JavaScript con NPM..." &&
    npm install &&
    echo "📦 Copiando instancia de FacturaScripts..." &&
    docker cp . $phpName:/root/facturascripts &&
    echo "⚙️ Sobrescribiendo config.php..." &&
    docker cp "$CACHE_DIR/facturascripts/config.php" "$phpName:/root/facturascripts/config.php" &&
    echo "📦 Injectando el updater a FacturaScripts..." &&
    docker cp "$ROOT_DIR/AutoConfigure.php" "$phpName:/root/facturascripts/AutoConfigure.php" &&
    echo "⚙️ Ejecutando AutoConfigure.php..." &&
    docker exec -it -w /root/facturascripts $phpName php AutoConfigure.php &&
    echo "-----------------------------------------------------" &&
    echo "✅ Instancia ejecutándose en http://localhost:$puerto" &&
    echo "-----------------------------------------------------" &&
    docker exec -it -w /root/facturascripts $phpName php -S 0.0.0.0:$puerto -t . index.php


    echo "⏹️ Deteniendo $phpName y MySQL"
    docker stop $phpName
    stopMySQL




  case "--runFSPluginIntoNewFS"
    # Verifica si el directorio actual es un plugin
    if ! isPlugin .
        return 1
    end

    set php php82-cli-fs-dev
    set phpName fsTestPhp
    set puerto 8088

    # Verifica si el repositorio de FacturaScripts está descargado
    if ! test -d $CACHE_DIR/facturascripts
        echo "🚫 No se ha descargado el repositorio de FacturaScripts."
        echo "Ejecuta 'myFSManager --install' para descargarlo."
        return 1
    end

    # Iniciar contenedor MySQL
    startMySQL

    # Crear contenedor PHP
    docker run --rm -dit \
        --name $phpName \
        --network $globalNetwork \
        --workdir /root/facturascripts \
        -p $puerto:$puerto \
        $php \
        bash

    docker cp $CACHE_DIR/facturascripts/. $phpName:/root/facturascripts &&
    set PLUGIN_NAME (basename (pwd)) &&
    docker exec $phpName mkdir -p /root/facturascripts/Plugins/$PLUGIN_NAME &&
    docker cp . $phpName:/root/facturascripts/Plugins/$PLUGIN_NAME &&
    # docker exec -w /root/facturascripts/Plugins/$PLUGIN_NAME $phpName ls && 
    docker exec -w /root/facturascripts $phpName composer install &&
    docker exec -w /root/facturascripts $phpName npm install &&

    echo "📦 Injectando el updater a FacturaScripts..." &&
    docker cp "$ROOT_DIR/AutoConfigure.php" "$phpName:/root/facturascripts/AutoConfigure.php" &&
    echo "⚙️ Ejecutando AutoConfigure.php..." &&
    docker exec -it -w /root/facturascripts $phpName php AutoConfigure.php &&

    # Ejecutar el servidor PHP para que el plugin esté disponible
    echo "-----------------------------------------------------" &&
    echo "✅ Instancia ejecutándose en http://localhost:$puerto" &&
    echo "-----------------------------------------------------" &&
    docker exec -it -w /root/facturascripts $phpName php -S 0.0.0.0:$puerto -t . index.php

    echo "⏹️ Deteniendo $phpName y MySQL"
    docker stop $phpName
    stopMySQL




  case "*"
    echo "Comandos disponibles:"
    echo "  myFSManager --install"
    echo "  myFSManager --runPluginTests"
    echo "  myFSManager --runFSTests"
    echo "  myFSManager --runFSInstance"
    echo "  myFSManager --runFSPluginIntoNewFS"
end
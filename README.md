# Propósito

Sirve para testear sin modificar el repositorio en el que se está trabajando del plugin o facturascripts.

Trabaja sobre dockers volátiles a medida para FS.

Monta un entorno virtual con su propia red y base de datos.

Cuando monta el entorno automáticamente realiza la configuración por defecto y te lleva a la pestaña de plugins.

# Funcionalidades

De momento he creado las siguientes funcionalidades:

- install: instala el repositorio en cache y los dockers necesarios para ello
- runPluginTests: copia el plugin sobre el que se esté trabajando en un docker con fs de la rama master y una base de datos vacía y ejecuta sus tests (como si fuera github actions)
- runFSTests: copia el repositorio sobre el que se esté trabajando de FS sobre el que se esté trabajando y ejecuta los tests al estilo github actions con una base de datos vacía. Se le pueden agregar parámetros a phpunit
- runFSInstance: copia el directorio actual de FS y lo pone en funcionamiento dentro de un docker para poder probarlo. Se le puede agregar datos iniciales para que esté llena la base de datos.
- runFSPluginIntoNewFS: copia el plugin sobre el que se esté trabajando y lo coloca en una instancia de fs de la ultima versión de la rama master y abre servidor para poder probarlo
- stopAll: detiene los dockers relacionados con este script.

# Dependencias

- fish: Fish shell
- docker
- docker-compose
- docker-buildx
- git
- composer
- php
- npm
#!/usr/bin/env php
<?php
use FacturaScripts\Core\CrashReport;
use FacturaScripts\Core\Kernel;
use FacturaScripts\Core\Plugins;
use FacturaScripts\Core\Tools;

require_once __DIR__ . '/vendor/autoload.php';

define('FS_FOLDER', __DIR__);

$config = FS_FOLDER . '/config.php';
if (!file_exists($config)) {
    echo $config . " not found!\n";
    exit(1);
}

require_once $config;

@set_time_limit(0);
ignore_user_abort(true);

$timeZone = Tools::config('timezone', 'Europe/Madrid');
date_default_timezone_set($timeZone);

CrashReport::init();
Kernel::init();

foreach (['Plugins', 'Dinamic', 'MyFiles'] as $folder) {
    Tools::folderCheckOrCreate(Tools::folder($folder));
}

Plugins::deploy();

echo "Dinamic folder rebuilt successfully.\n";
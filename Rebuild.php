#!/usr/bin/env php
<?php

use FacturaScripts\Core\Base\DataBase\DataBaseWhere;
use FacturaScripts\Core\CrashReport;
use FacturaScripts\Core\Kernel;
use FacturaScripts\Core\Plugins;
use FacturaScripts\Core\Tools;
use FacturaScripts\Dinamic\Lib\Accounting\AccountingPlanImport;
use FacturaScripts\Dinamic\Model\Almacen;
use FacturaScripts\Dinamic\Model\Cuenta;
use FacturaScripts\Dinamic\Model\Ejercicio;
use FacturaScripts\Dinamic\Model\Empresa;
use FacturaScripts\Dinamic\Model\Role;
use FacturaScripts\Dinamic\Model\User;

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

date_default_timezone_set(Tools::config('timezone', 'Europe/Madrid'));

CrashReport::init();
Kernel::init();

foreach (['Plugins', 'Dinamic', 'MyFiles'] as $folder) {
    Tools::folderCheckOrCreate(Tools::folder($folder));
}

Plugins::deploy();

// ==================== Paso 1: Empresa ====================
$empresa = Empresa::all()[0] ?? new Empresa();
$empresa->nombre = 'Mi Empresa S.L.';
$empresa->nombrecorto = Tools::textBreak($empresa->nombre, 32);
$empresa->codpais = 'ESP';
$empresa->ciudad = 'Madrid';
$empresa->direccion = 'Calle Falsa 123';
$empresa->codpostal = '28080';
$empresa->provincia = 'Madrid';
$empresa->telefono1 = '911223344';
$empresa->email = 'admin@miempresa.com';
$empresa->apartado = '';
$empresa->cifnif = 'B12345678';
$empresa->personafisica = false;
$empresa->tipoidfiscal = '01';
$empresa->save();

// ==================== Paso 2: Usuario Admin ====================
$user = new User();
if (!$user->loadFromCode('admin')) {
    die("No se encontró el usuario admin.\n");
}
$user->email = $empresa->email;
$user->newPassword = 'nuevacontraseña';
$user->newPassword2 = 'nuevacontraseña';
$user->homepage = 'AdminPlugins';
$user->save();

// ==================== Paso 3: Almacén ====================
$almacen = Almacen::all([new DataBaseWhere('idempresa', $empresa->idempresa)])[0] ?? new Almacen();
$almacen->nombre = $empresa->nombrecorto;
$almacen->idempresa = $empresa->idempresa;
$almacen->direccion = $empresa->direccion;
$almacen->codpostal = $empresa->codpostal;
$almacen->provincia = $empresa->provincia;
$almacen->codpais = $empresa->codpais;
$almacen->ciudad = $empresa->ciudad;
$almacen->save();

// ==================== Paso 4: Ajustes por Defecto ====================
$defaultFile = FS_FOLDER . '/Dinamic/Data/Codpais/' . $empresa->codpais . '/default.json';
if (file_exists($defaultFile)) {
    $defaultValues = json_decode(file_get_contents($defaultFile), true) ?? [];
    foreach ($defaultValues as $group => $values) {
        foreach ($values as $key => $value) {
            Tools::settingsSet($group, $key, $value);
        }
    }
}

Tools::settingsSet('default', 'codpais', $empresa->codpais);
Tools::settingsSet('default', 'idempresa', $empresa->idempresa);
Tools::settingsSet('default', 'codalmacen', $almacen->codalmacen);
Tools::settingsSet('default', 'homepage', 'Root');
Tools::settingsSave();

// ==================== Paso 5: Plan Contable ====================
$filePlan = FS_FOLDER . '/Dinamic/Data/Codpais/' . $empresa->codpais . '/defaultPlan.csv';
if (file_exists($filePlan) && !(new Cuenta())->count()) {
    foreach (Ejercicio::all() as $ejercicio) {
        $planImport = new AccountingPlanImport();
        $planImport->importCSV($filePlan, $ejercicio->codejercicio);
        break;  // Solo una vez
    }
}

// ==================== Paso 6: Ajustes Adicionales ====================
$empresa->regimeniva = '01';
$empresa->save();

$defaultSettings = [
    'codimpuesto' => null,
    'costpricepolicy' => null,
    'updatesupplierprices' => true,
    'ventasinstock' => true,
    'site_url' => Tools::siteUrl(),
];
foreach ($defaultSettings as $key => $value) {
    Tools::settingsSet('default', $key, $value);
}
Tools::settingsSave();

// ==================== Paso 7: Rol por Defecto ====================
$role = new Role();
if ($role->loadFromCode('employee')) {
    Tools::settingsSet('default', 'codrole', $role->codrole);
    Tools::settingsSave();
}

// ==================== Paso 8: Plugins ====================
Plugins::deploy(true, true);

// ==================== Paso 9: Usuario Redireccionamiento ====================
$user = new User();
if ($user->loadFromCode('admin')) {
    $user->homepage = 'AdminPlugins';
    $user->save();
}

// ==================== Paso 10: Carga de Modelos ====================
$modelsFolder = Tools::folder('Dinamic', 'Model');
foreach (Tools::folderScan($modelsFolder) as $fileName) {
    if ('.php' === substr($fileName, -4)) {
        $name = substr($fileName, 0, -4);
        $className = '\\FacturaScripts\\Dinamic\\Model\\' . $name;
        new $className();
        echo "✔ $name OK\n";
    }
}

// ==================== Final ====================
echo "✔ Setup inicial completado correctamente.\n";

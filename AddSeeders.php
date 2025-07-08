<?php
/**
 * Script to insert sample data for a grocery store.
 */

use FacturaScripts\Core\Base\DataBase;
use FacturaScripts\Core\Cache;
use FacturaScripts\Core\Kernel;
use FacturaScripts\Core\Plugins;
use FacturaScripts\Core\Lib\Calculator;
use FacturaScripts\Core\Model\AlbaranCliente;
use FacturaScripts\Core\Model\Cliente;
use FacturaScripts\Core\Model\FacturaCliente;
use FacturaScripts\Core\Model\FacturaProveedor;
use FacturaScripts\Core\Model\Producto;
use FacturaScripts\Core\Model\Proveedor;

const FS_FOLDER = __DIR__;

require_once __DIR__ . '/vendor/autoload.php';

if (!file_exists(__DIR__ . '/config.php')) {
    echo "config.php not found" . PHP_EOL;
    exit(1);
}
require_once __DIR__ . '/config.php';

$db = new DataBase();
$db->connect();
Cache::clear();
Kernel::init();
Plugins::deploy();

$productsInfo = [
    ['ref' => 'PAN', 'name' => 'Pan de trigo', 'price' => 1.10],
    ['ref' => 'LECHE', 'name' => 'Leche entera 1L', 'price' => 0.95],
    ['ref' => 'HUEVOS', 'name' => 'Huevos docena', 'price' => 2.50],
    ['ref' => 'QUESO', 'name' => 'Queso curado', 'price' => 3.75],
    ['ref' => 'MANZANA', 'name' => 'Manzanas kilo', 'price' => 1.80],
];

$products = [];
foreach ($productsInfo as $item) {
    $product = new Producto();
    $product->referencia = $item['ref'];
    $product->descripcion = $item['name'];
    $product->precio = $item['price'];
    $product->secompra = true;
    $product->sevende = true;
    $product->save();
    $products[] = $product;
}

$suppliersData = [
    ['cif' => 'B12345678', 'name' => 'Proveedor Uno SL'],
    ['cif' => 'B87654321', 'name' => 'Proveedor Dos SA'],
];

$suppliers = [];
foreach ($suppliersData as $info) {
    $supplier = new Proveedor();
    $supplier->cifnif = $info['cif'];
    $supplier->nombre = $info['name'];
    $supplier->razonsocial = $info['name'];
    $supplier->save();
    $suppliers[] = $supplier;
}

foreach ($suppliers as $supplier) {
    $invoice = new FacturaProveedor();
    $invoice->setSubject($supplier);
    $invoice->save();

    foreach ($products as $product) {
        $line = $invoice->getNewProductLine($product->referencia);
        $line->cantidad = 10;
        $line->pvpunitario = $product->precio;
        $line->save();
    }
    Calculator::calculate($invoice, $invoice->getLines(), true);
}

$customersInfo = [
    ['cif' => '12345678A', 'name' => 'Cliente Uno SA'],
    ['cif' => '87654321B', 'name' => 'Cliente Dos SL'],
    ['cif' => '11223344C', 'name' => 'Cliente Tres CB'],
];

$customers = [];
foreach ($customersInfo as $info) {
    $customer = new Cliente();
    $customer->cifnif = $info['cif'];
    $customer->nombre = $info['name'];
    $customer->razonsocial = $info['name'];
    $customer->save();
    $customers[] = $customer;
}

$salesQty = [3, 3, 4];
foreach ($customers as $index => $customer) {
    $invoice = new FacturaCliente();
    $invoice->setSubject($customer);
    $invoice->save();

    $delivery = new AlbaranCliente();
    $delivery->setSubject($customer);
    $delivery->save();

    foreach ($products as $product) {
        $qty = $salesQty[$index];
        $lineInv = $invoice->getNewProductLine($product->referencia);
        $lineInv->cantidad = $qty;
        $lineInv->pvpunitario = $product->precio * 1.3;
        $lineInv->save();

        $lineAlb = $delivery->getNewProductLine($product->referencia);
        $lineAlb->cantidad = $qty;
        $lineAlb->pvpunitario = $product->precio * 1.3;
        $lineAlb->save();
    }
    Calculator::calculate($delivery, $delivery->getLines(), true);
    Calculator::calculate($invoice, $invoice->getLines(), true);
}

$db->close();

echo "Sample data inserted" . PHP_EOL;
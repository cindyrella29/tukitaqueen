<?php
// Tukita Queen - MySQL connection test
// Delete or protect this file before publishing the site.

require_once __DIR__ . '/db_config.php';

try {
    $connection = tq_db();

    echo 'Conexion correcta a la base de datos: ' . htmlspecialchars(DB_NAME, ENT_QUOTES, 'UTF-8');

    $connection->close();
} catch (mysqli_sql_exception $error) {
    http_response_code(500);
    echo 'Error de conexion: ' . htmlspecialchars($error->getMessage(), ENT_QUOTES, 'UTF-8');
}

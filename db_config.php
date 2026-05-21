<?php
// Tukita Queen - MySQL configuration

declare(strict_types=1);

const DB_HOST = 'localhost';
const DB_NAME = 'tukita_queen';
const DB_USER = 'root';
const DB_PASS = '';
const DB_PORT = 3306;

function tq_db(): mysqli
{
    mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

    $connection = new mysqli(
        DB_HOST,
        DB_USER,
        DB_PASS,
        DB_NAME,
        DB_PORT
    );

    $connection->set_charset('utf8mb4');

    return $connection;
}
?>

<?php
    $host = "mysql-db";
    $port = 3306;
    $username_db = "ctf";
    $password_db = "ctf";
    $database = "CHALLENGE";
    $conn = new mysqli($host, $username_db, $password_db, $database, $port);
    if ($conn->connect_error) {
        die("Connection failed: " . $conn->connect_error);
    }
?>
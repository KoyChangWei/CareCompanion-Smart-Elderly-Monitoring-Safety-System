<?php
$servername = "localhost";
$username   = "threenqs_koy_chang_wei";
$password   = "6gspmd70(**O";
$dbname     = "threenqs_carecompanion";

$conn = new mysqli($servername, $username, $password, $dbname);
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}
?>
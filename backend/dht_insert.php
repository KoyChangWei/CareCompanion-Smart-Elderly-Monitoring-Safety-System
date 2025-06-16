<?php
include 'dbconnect.php';

// Get parameters from GET request
$temp = isset($_GET['temp']) ? $_GET['temp'] : null;
$humidity = isset($_GET['humidity']) ? $_GET['humidity'] : null;

if ($temp !== null && $humidity !== null) {
    // Insert into dht_tbl
    $sql = "INSERT INTO dht_tbl (dht_temp, dht_humdity, timestamp) VALUES (?, ?, NOW())";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("dd", $temp, $humidity);
    
    if ($stmt->execute()) {
        echo "DHT data inserted successfully";
    } else {
        echo "Error: " . $stmt->error;
    }
    
    $stmt->close();
} else {
    echo "Error: Missing temperature or humidity data";
}

$conn->close();
?> 
<?php
include 'dbconnect.php';

// Get parameters from GET request
$status = isset($_GET['status']) ? $_GET['status'] : null;

if ($status !== null) {
    // Insert into vs_tbl
    $sql = "INSERT INTO vs_tbl (vs_status, timestamp) VALUES (?, NOW())";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $status);
    
    if ($stmt->execute()) {
        echo "Vibration sensor data inserted successfully";
    } else {
        echo "Error: " . $stmt->error;
    }
    
    $stmt->close();
} else {
    echo "Error: Missing vibration sensor status data";
}

$conn->close();
?> 
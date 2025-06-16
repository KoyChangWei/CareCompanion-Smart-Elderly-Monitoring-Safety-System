<?php
include 'dbconnect.php';

// Get parameters from GET request
$status = isset($_GET['status']) ? $_GET['status'] : null;
$duration = isset($_GET['duration']) ? intval($_GET['duration']) : 0;

if ($status !== null) {
    // Insert into PIR_tbl with act_time (duration in seconds)
    $sql = "INSERT INTO PIR_tbl (PIR_status, act_time, timestamp) VALUES (?, ?, NOW())";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("si", $status, $duration);
    
    if ($stmt->execute()) {
        echo "PIR data inserted successfully - Status: $status, Duration: $duration seconds";
    } else {
        echo "Error: " . $stmt->error;
    }
    
    $stmt->close();
} else {
    echo "Error: Missing PIR status data";
}

$conn->close();
?> 
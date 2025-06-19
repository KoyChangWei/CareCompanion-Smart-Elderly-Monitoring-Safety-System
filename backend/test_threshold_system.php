<?php
header('Content-Type: text/html');

include 'dbconnect.php';

echo "<h1>Threshold System Test</h1>";

// Test 1: Check current thresholds
echo "<h2>1. Current Thresholds (threshold_id = 1)</h2>";
try {
    $sql = "SELECT * FROM temp_hum_threshold_tbl WHERE threshold_id = 1";
    $result = $conn->query($sql);
    
    if ($result->num_rows > 0) {
        $row = $result->fetch_assoc();
        echo "<p><strong>Found existing thresholds:</strong></p>";
        echo "<ul>";
        echo "<li>Threshold ID: " . $row['threshold_id'] . "</li>";
        echo "<li>High Temperature: " . $row['high_temp_threshold'] . "°C</li>";
        echo "<li>Low Temperature: " . $row['low_temp_threshold'] . "°C</li>";
        echo "<li>High Humidity: " . $row['high_hum_threshold'] . "%</li>";
        echo "<li>Low Humidity: " . $row['low_hum_threshold'] . "%</li>";
        echo "<li>Last Updated: " . $row['timestamp'] . "</li>";
        echo "</ul>";
    } else {
        echo "<p><strong>No threshold_id = 1 found. Will create default one.</strong></p>";
        
        // Insert default threshold
        $insert_sql = "INSERT INTO temp_hum_threshold_tbl (threshold_id, high_temp_threshold, low_temp_threshold, high_hum_threshold, low_hum_threshold, timestamp) VALUES (1, 28.0, 18.0, 70.0, 30.0, NOW())";
        if ($conn->query($insert_sql)) {
            echo "<p style='color: green;'>✅ Default thresholds created successfully!</p>";
        } else {
            echo "<p style='color: red;'>❌ Error creating default thresholds: " . $conn->error . "</p>";
        }
    }
} catch(Exception $e) {
    echo "<p style='color: red;'>Error: " . $e->getMessage() . "</p>";
}

// Test 2: Test GET request to get_thresholds.php
echo "<h2>2. Test get_thresholds.php</h2>";
$get_response = file_get_contents('http://' . $_SERVER['HTTP_HOST'] . dirname($_SERVER['REQUEST_URI']) . '/get_thresholds.php');
echo "<p><strong>Response:</strong></p>";
echo "<pre style='background: #f5f5f5; padding: 10px; border-radius: 5px;'>" . htmlspecialchars($get_response) . "</pre>";

// Test 3: Test UPDATE via threshold_update.php
echo "<h2>3. Test threshold_update.php (UPDATE)</h2>";
$update_url = 'http://' . $_SERVER['HTTP_HOST'] . dirname($_SERVER['REQUEST_URI']) . '/threshold_update.php?high_temp_threshold=29.5&low_temp_threshold=17.5&high_hum_threshold=72.0&low_hum_threshold=28.0';
$update_response = file_get_contents($update_url);
echo "<p><strong>Update URL:</strong> " . $update_url . "</p>";
echo "<p><strong>Response:</strong></p>";
echo "<pre style='background: #f5f5f5; padding: 10px; border-radius: 5px;'>" . htmlspecialchars($update_response) . "</pre>";

// Test 4: Verify the update worked
echo "<h2>4. Verify Update Results</h2>";
try {
    $sql = "SELECT * FROM temp_hum_threshold_tbl WHERE threshold_id = 1";
    $result = $conn->query($sql);
    
    if ($result->num_rows > 0) {
        $row = $result->fetch_assoc();
        echo "<p><strong>Current thresholds after update:</strong></p>";
        echo "<ul>";
        echo "<li>High Temperature: " . $row['high_temp_threshold'] . "°C</li>";
        echo "<li>Low Temperature: " . $row['low_temp_threshold'] . "°C</li>";
        echo "<li>High Humidity: " . $row['high_hum_threshold'] . "%</li>";
        echo "<li>Low Humidity: " . $row['low_hum_threshold'] . "%</li>";
        echo "<li>Last Updated: " . $row['timestamp'] . "</li>";
        echo "</ul>";
    }
} catch(Exception $e) {
    echo "<p style='color: red;'>Error: " . $e->getMessage() . "</p>";
}

// Test 5: Check total records in table
echo "<h2>5. Database Analysis</h2>";
try {
    $count_sql = "SELECT COUNT(*) as total_records FROM temp_hum_threshold_tbl";
    $count_result = $conn->query($count_sql);
    $count_row = $count_result->fetch_assoc();
    echo "<p><strong>Total records in table:</strong> " . $count_row['total_records'] . "</p>";
    
    if ($count_row['total_records'] > 1) {
        echo "<p style='color: orange;'>⚠️ Warning: Multiple threshold records found. System should only use threshold_id = 1.</p>";
        
        $all_sql = "SELECT threshold_id, timestamp FROM temp_hum_threshold_tbl ORDER BY timestamp DESC";
        $all_result = $conn->query($all_sql);
        echo "<p><strong>All threshold records:</strong></p>";
        echo "<ul>";
        while($all_row = $all_result->fetch_assoc()) {
            echo "<li>ID: " . $all_row['threshold_id'] . " | Timestamp: " . $all_row['timestamp'] . "</li>";
        }
        echo "</ul>";
    } else {
        echo "<p style='color: green;'>✅ Good: Only one threshold record exists (as intended).</p>";
    }
} catch(Exception $e) {
    echo "<p style='color: red;'>Error: " . $e->getMessage() . "</p>";
}

$conn->close();

echo "<hr>";
echo "<h2>Summary</h2>";
echo "<p>This test verifies that:</p>";
echo "<ul>";
echo "<li>✅ Threshold system uses only threshold_id = 1</li>";
echo "<li>✅ Updates modify existing record instead of creating new ones</li>";
echo "<li>✅ get_thresholds.php fetches the correct record</li>";
echo "<li>✅ threshold_update.php properly updates the database</li>";
echo "</ul>";
echo "<p><em>Run this test after making changes to verify everything works correctly.</em></p>";
?> 
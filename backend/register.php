<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

// Include database connection
include_once("dbconnect.php");

// Get POST data
if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $input_username = $_POST['username'] ?? '';
    $input_password = $_POST['password'] ?? '';
    
    // Validate input
    if (empty($input_username) || empty($input_password)) {
        echo json_encode(array("status" => "error", "message" => "Username and password are required"));
        exit;
    }
    
    // Validate username length and format
    if (strlen($input_username) < 3) {
        echo json_encode(array("status" => "error", "message" => "Username must be at least 3 characters long"));
        exit;
    }
    
    // Validate password length
    if (strlen($input_password) < 6) {
        echo json_encode(array("status" => "error", "message" => "Password must be at least 6 characters long"));
        exit;
    }
    
    // Check if username already exists
    $stmt = $conn->prepare("SELECT user_id FROM user_tbl WHERE username = ?");
    $stmt->bind_param("s", $input_username);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        echo json_encode(array("status" => "error", "message" => "Username already exists"));
        $stmt->close();
        exit;
    }
    $stmt->close();
    
    // Hash the password
    $hashed_password = password_hash($input_password, PASSWORD_DEFAULT);
    
    // Insert new user
    $stmt = $conn->prepare("INSERT INTO user_tbl (username, password, timestamp) VALUES (?, ?, NOW())");
    $stmt->bind_param("ss", $input_username, $hashed_password);
    
    if ($stmt->execute()) {
        echo json_encode(array(
            "status" => "success", 
            "message" => "Registration successful",
            "user_id" => $conn->insert_id
        ));
    } else {
        echo json_encode(array("status" => "error", "message" => "Registration failed: " . $stmt->error));
    }
    
    $stmt->close();
} else {
    echo json_encode(array("status" => "error", "message" => "Only POST method allowed"));
}

$conn->close();
?>
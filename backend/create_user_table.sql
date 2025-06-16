-- SQL script to create the user_tbl table
-- Run this in your MySQL database

-- Create database
CREATE DATABASE IF NOT EXISTS elderly_monitoring;
USE elderly_monitoring;

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create PIR sensor table with duration tracking
CREATE TABLE IF NOT EXISTS PIR_tbl (
    PIR_id INT AUTO_INCREMENT PRIMARY KEY,
    PIR_status VARCHAR(20) NOT NULL,
    act_time INT DEFAULT 0 COMMENT 'Motion duration in seconds',
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create other sensor tables (unchanged)
CREATE TABLE IF NOT EXISTS dht_tbl (
    dht_id INT AUTO_INCREMENT PRIMARY KEY,
    temperature FLOAT NOT NULL,
    humidity FLOAT NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS vs_tbl (
    vs_id INT AUTO_INCREMENT PRIMARY KEY,
    vs_status VARCHAR(20) NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS relay_tbl (
    relay_id INT AUTO_INCREMENT PRIMARY KEY,
    relay_status VARCHAR(10) NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Optional: Insert a test user (password is 'password123')
-- Username: testuser, Password: password123
INSERT INTO `user_tbl` (`username`, `password`, `timestamp`) VALUES 
('testuser', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', NOW());

-- Show the table structure
DESCRIBE `user_tbl`; 
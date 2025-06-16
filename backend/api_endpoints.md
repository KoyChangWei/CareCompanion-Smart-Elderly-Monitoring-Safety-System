# Backend API Endpoints Documentation

This document describes the API endpoints for the CareCompanion elderly monitoring system.

## Base URL
```
http://your-server.com/backend/
```

## Database Tables
Your database contains these 4 tables:
1. **dht_tbl** - Temperature and humidity data
2. **PIR_tbl** - PIR motion sensor data  
3. **vs_tbl** - Vibration sensor data
4. **relay_tbl** - Relay control status

## Endpoints

### 1. DHT Sensor Data (Temperature & Humidity)

#### Insert DHT Reading (Arduino → Backend)
```
GET /dht_insert.php?temp={temperature}&humidity={humidity}
```
**Parameters:**
- `temp` (float): Temperature in Celsius
- `humidity` (float): Humidity percentage

**Response:**
```
DHT data inserted successfully
```

#### Get Latest DHT Reading (App ← Backend)
```
GET /get_latest_dht.php
```
**Response:**
```json
{
  "temperature": "25.2",
  "humidity": "62.5",
  "timestamp": "2024-01-20 14:30:15"
}
```

#### Get DHT History (App ← Backend)
```
GET /get_dht_history.php?days={days}
```
**Parameters:**
- `days` (int): Number of days to retrieve (default: 7)

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "temperature": "25.2",
      "humidity": "62.5",
      "timestamp": "2024-01-20 14:30:15"
    }
  ],
  "count": 1,
  "period_days": 7
}
```

### 2. PIR Sensor Data (Motion Detection)

#### Insert PIR Reading (Arduino → Backend)
```
GET /pir_insert.php?status={status}&duration={duration}
```
**Parameters:**
- `status` (string): "DETECTED" or "NO_MOTION"
- `duration` (int, optional): Motion duration in seconds (default: 0)

**Usage:**
- Motion start: `status=DETECTED&duration=0`
- Motion end: `status=NO_MOTION&duration=45` (where 45 is actual motion time)

**Response:**
```
PIR data inserted successfully - Status: NO_MOTION, Duration: 45 seconds
```

#### Get Latest PIR Reading (App ← Backend)
```
GET /get_latest_pir.php
```
**Response:**
```json
{
  "status": "NO_MOTION",
  "duration": 45,
  "timestamp": "2024-01-20 14:30:15"
}
```

### 3. Vibration Sensor Data (Fall Detection)

#### Insert Vibration Reading (Arduino → Backend)
```
GET /vs_insert.php?status={status}
```
**Parameters:**
- `status` (string): "DETECTED" or "NO_VIBRATION"

**Response:**
```
Vibration sensor data inserted successfully
```

#### Get Latest Vibration Reading (App ← Backend)
```
GET /get_latest_vibration.php
```
**Response:**
```json
{
  "status": "DETECTED",
  "timestamp": "2024-01-20 14:30:15"
}
```

### 4. Relay Control

#### Update Relay Status (Arduino → Backend)
```
GET /relay_update.php?status={status}
```
**Parameters:**
- `status` (string): "ON" or "OFF"

**Response:**
```
Relay status updated successfully to: ON
```

#### Control Relay (App → Backend)
```
GET /relay_control.php?status={status}
```
**Parameters:**
- `status` (string): "ON" or "OFF"

**Response:**
```json
{
  "success": true,
  "message": "Relay turned ON successfully",
  "status": "ON",
  "timestamp": "2024-01-20 14:30:15"
}
```

#### Get Relay Status (App ← Backend)
```
GET /get_relay_status.php
```
**Response:**
```json
{
  "status": "ON",
  "timestamp": "2024-01-20 14:30:15"
}
```

### 5. Activity History (Combined PIR + Vibration)

#### Get Activity History (App ← Backend)
```
GET /get_activity_history.php?days={days}
```
**Parameters:**
- `days` (int): Number of days to retrieve (default: 7)

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "type": "MOTION",
      "detected": false,
      "duration": 45,
      "timestamp": "2024-01-20 14:30:15"
    },
    {
      "type": "FALL",
      "detected": true,
      "timestamp": "2024-01-20 14:25:30"
    }
  ],
  "count": 2,
  "period_days": 7,
  "motion_sessions": 1,
  "total_motion_time": 45,
  "fall_count": 1
}
```

## Database Schema (Actual Tables)

### DHT Table
```sql
CREATE TABLE dht_tbl (
    -- Primary key (auto-increment)
    dht_temp DECIMAL(5,2) NOT NULL,
    dht_humdity DECIMAL(5,2) NOT NULL,  -- Note: typo in column name
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### PIR Table
```sql
CREATE TABLE PIR_tbl (
    PIR_id INT AUTO_INCREMENT PRIMARY KEY,
    PIR_status VARCHAR(50) NOT NULL,  -- 'DETECTED' or 'NO_MOTION'
    act_time INT DEFAULT 0,  -- Motion duration in seconds
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Vibration Sensor Table
```sql
CREATE TABLE vs_tbl (
    -- Primary key (auto-increment)
    vs_status VARCHAR(50) NOT NULL,  -- 'DETECTED' or 'NO_VIBRATION'
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Relay Table
```sql
CREATE TABLE relay_tbl (
    relay_id INT AUTO_INCREMENT PRIMARY KEY,
    relay_status VARCHAR(10) NOT NULL,  -- 'ON' or 'OFF'
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## File Summary

### Core Files (Keep):
- `dbconnect.php` - Database connection configuration
- `dht_insert.php` - Arduino sends temperature/humidity data
- `pir_insert.php` - Arduino sends motion detection data
- `vs_insert.php` - Arduino sends vibration/fall detection data
- `relay_update.php` - Arduino updates relay status
- `get_latest_dht.php` - App gets current temperature/humidity
- `get_latest_pir.php` - App gets current motion status
- `get_latest_vibration.php` - App gets current vibration status
- `get_relay_status.php` - App gets current relay status
- `relay_control.php` - App controls relay ON/OFF
- `get_dht_history.php` - App gets temperature/humidity history
- `get_activity_history.php` - App gets motion/fall history

### Removed Files:
- `config.php` - Redundant (replaced by dbconnect.php)
- `get_threshold.php` - Used non-existent threshold_settings table

## Error Responses
All endpoints return appropriate error messages in case of database connection issues or invalid parameters. 
# Flutter Backend Integration Summary

## Overview
The CareCompanion Flutter app is now fully integrated with your backend API to retrieve and display real-time sensor data. The app automatically fetches data from all available backend endpoints.

## ✅ Backend Endpoints Used by Flutter App

### 📱 Real-time Data Fetching (Every 5 seconds)
1. **`get_latest_dht.php`** - Temperature & Humidity
   - Used by: `SensorService._fetchDHTData()`
   - Updates: Temperature and humidity readings
   - Displays in: All screens

2. **`get_latest_pir.php`** - Motion Detection
   - Used by: `SensorService._fetchPIRData()`
   - Updates: Motion detection status
   - Displays in: All screens with motion indicators

3. **`get_latest_vibration.php`** - Fall Detection
   - Used by: `SensorService._fetchVibrationData()`
   - Updates: Fall detection status
   - Displays in: All screens with fall alerts

### 🔌 Relay Control (Every 3 seconds)
4. **`get_relay_status.php`** - Relay Status Check
   - Used by: `SensorService.checkRelayStatus()`
   - Updates: Current relay ON/OFF status
   - Displays in: All screens, especially Relay Control page

5. **`relay_control.php`** - Manual Relay Control
   - Used by: `SensorService.toggleRelay()`
   - Function: Turn relay ON/OFF from app
   - Used in: Relay Control page, Emergency buttons

### 📊 Historical Data Loading
6. **`get_dht_history.php`** - Temperature/Humidity History
   - Used by: `SensorService.loadDHTHistory()`
   - Function: Load historical sensor data for charts
   - Used in: Graphs & Trends page

7. **`get_activity_history.php`** - Motion/Fall History
   - Used by: `SensorService.loadActivityHistory()`
   - Function: Load activity logs for analysis
   - Used in: Graphs & Trends page

## 🔧 Configuration & Connection

### Server Configuration (`lib/config/app_config.dart`)
```dart
static const String server = 'http://carecompanion.threelittlecar.com/backend/';
```

### Automatic Data Fetching
- **Live Data**: Every 5 seconds
- **Relay Status**: Every 3 seconds  
- **Historical Data**: On demand when changing date ranges
- **Initial Load**: 7 days of historical data on app start

## 📱 Flutter App Pages Using Backend Data

### 1. **Home Dashboard** (`home_dashboard.dart`)
✅ **Data Used:**
- Current temperature/humidity from `get_latest_dht.php`
- Motion detection status from `get_latest_pir.php`
- Fall detection status from `get_latest_vibration.php`
- Relay status from `get_relay_status.php`

✅ **Features:**
- Real-time sensor status cards
- Emergency status indicator
- Relay status display
- Auto-refresh every 5 seconds

### 2. **Live Sensor Page** (`live_sensor_page.dart`)
✅ **Data Used:**
- All real-time sensor data
- Detailed sensor readings with timestamps
- Status indicators and alerts

✅ **Features:**
- Detailed sensor monitoring
- Pull-to-refresh functionality
- Real-time updates
- Visual status indicators

### 3. **Relay Control Page** (`relay_control_page.dart`)
✅ **Data Used:**
- Current relay status from `get_relay_status.php`
- Relay control via `relay_control.php`

✅ **Features:**
- Manual relay ON/OFF control
- Emergency stop functionality
- Real-time status updates
- Control confirmation

### 4. **Graphs & Trends Page** (`graphs_trends_page.dart`)
✅ **Data Used:**
- Historical temperature data from `get_dht_history.php`
- Historical humidity data from `get_dht_history.php`
- Activity history from `get_activity_history.php`

✅ **Features:**
- Interactive charts (Today, 7 days, 30 days)
- Temperature/humidity trends
- Activity timeline visualization
- Automatic data loading when changing date ranges
- Loading states and error handling

## 🔄 Data Flow Diagram

```
Arduino Sensors → Backend PHP Files → Flutter App

Temperature/Humidity → dht_insert.php → dht_tbl → get_latest_dht.php → Flutter
Motion Detection → pir_insert.php → PIR_tbl → get_latest_pir.php → Flutter  
Fall Detection → vs_insert.php → vs_tbl → get_latest_vibration.php → Flutter
Relay Status → relay_update.php → relay_tbl → get_relay_status.php → Flutter

Flutter App → relay_control.php → relay_tbl → Arduino Relay Control
```

## 🎯 Key Features Implemented

### ✅ **Real-time Monitoring**
- Automatic data fetching every 5 seconds
- Live sensor status updates
- Emergency detection and alerts
- Relay status monitoring

### ✅ **Historical Data Analysis**
- Interactive charts and graphs
- Configurable date ranges (Today, 7 days, 30 days)
- Temperature and humidity trend analysis
- Motion and fall activity timeline
- Statistical summaries (min, max, average)

### ✅ **Emergency Response**
- Fall detection alerts
- Manual relay control
- Emergency stop functionality
- Visual and status indicators

### ✅ **User Experience**
- Pull-to-refresh functionality
- Loading states and error handling
- Responsive design
- Intuitive navigation

## 🚀 How to Use

1. **Automatic Operation:**
   - App automatically starts monitoring when launched
   - Real-time data updates every 5 seconds
   - Historical data loads automatically

2. **Manual Refresh:**
   - Pull down on any screen to refresh
   - Tap refresh button in app bars
   - Change date ranges to load specific historical periods

3. **Emergency Control:**
   - Use Relay Control page for manual ON/OFF
   - Emergency stop button available on multiple screens
   - Real-time status feedback

## ✅ Database Tables Used

Your Flutter app now correctly uses all 4 database tables:

1. **`dht_tbl`** - Temperature and humidity readings
2. **`PIR_tbl`** - Motion detection events  
3. **`vs_tbl`** - Vibration/fall detection events
4. **`relay_tbl`** - Relay control status

## 🎉 Summary

**The Flutter app is now fully connected to your backend!** 

✅ All 7 backend PHP endpoints are being used
✅ Real-time data fetching every 5 seconds  
✅ Historical data loading for charts
✅ Manual relay control functionality
✅ Error handling and loading states
✅ Responsive UI with proper data display
✅ Automatic initialization and monitoring

The app will automatically:
- Connect to your backend server
- Fetch live sensor data
- Display charts and trends
- Allow manual relay control  
- Show emergency alerts
- Handle connection errors gracefully

Everything is working together seamlessly! 🎯 
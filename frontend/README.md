# CareCompanion - Elderly Monitoring System

A comprehensive Flutter-based mobile app for monitoring elderly care using Arduino sensors. The system provides real-time fall detection, motion monitoring, environmental tracking, and emergency relay control.

## 🚀 Features

### 📱 Mobile App Features
- **Home Dashboard**: Quick overview of all sensor statuses
- **Live Sensor Monitoring**: Detailed real-time sensor readings
- **Relay Control**: Manual emergency relay control with safety features
- **Trends & Analytics**: Interactive charts for temperature, humidity, and activity data
- **Emergency Alerts**: Real-time notifications for falls and environmental concerns

### 🔧 Arduino Sensor System
- **Fall Detection**: Vibration sensor (SW-420) for impact detection
- **Motion Monitoring**: PIR sensor for presence detection
- **Environmental Monitoring**: DHT11 for temperature and humidity
- **OLED Display**: Real-time local display of sensor data
- **Emergency Relay**: Buzzer control for emergency alerts
- **WiFi Connectivity**: Local web server for app communication

## 🛠️ Hardware Requirements

### Arduino Components
- ESP32 Development Board
- SW-420 Vibration Sensor (Pin 26)
- PIR Motion Sensor (Pin 13)
- DHT11 Temperature/Humidity Sensor (Pin 4)
- SSD1306 OLED Display (I2C: SDA-21, SCL-22)
- Relay Module (Pin 25)
- Buzzer (connected via relay)
- Jumper wires and breadboard

### Mobile Device
- Android device with Flutter support
- WiFi connection to same network as Arduino

## 📋 Setup Instructions

### 1. Arduino Setup

1. **Install Arduino IDE Libraries:**
   ```
   - WiFi (ESP32)
   - HTTPClient
   - Wire
   - Adafruit_GFX
   - Adafruit_SSD1306
   - DHT sensor library
   - WebServer (ESP32)
   ```

2. **Hardware Connections:**
   ```
   ESP32 Pin | Component
   ---------|----------
   26       | Vibration Sensor Data
   13       | PIR Sensor Data
   4        | DHT11 Data
   25       | Relay Control
   21       | OLED SDA
   22       | OLED SCL
   3.3V     | Sensors VCC
   GND      | Sensors GND
   ```

3. **Configure WiFi:**
   - Open `arduinosensor/arduinoCode.ino`
   - Update WiFi credentials:
   ```cpp
   const char* ssid = "YOUR_WIFI_SSID";
   const char* password = "YOUR_WIFI_PASSWORD";
   ```

4. **Upload Code:**
   - Connect ESP32 to computer
   - Select correct board and port in Arduino IDE
   - Upload `arduinoCode.ino`
   - Note the IP address displayed in Serial Monitor

### 2. Flutter App Setup

1. **Install Flutter Dependencies:**
   ```bash
   flutter pub get
   ```

2. **Configure Arduino IP:**
   - Open `lib/services/sensor_service.dart`
   - Update the baseUrl with your Arduino's IP:
   ```dart
   static const String baseUrl = 'http://YOUR_ARDUINO_IP/';
   ```

3. **Run the App:**
   ```bash
   flutter run
   ```

## 🎯 How It Works

### Fall Detection System
1. **Vibration Detection**: SW-420 sensor detects impacts/falls
2. **Automatic Relay Activation**: Emergency buzzer turns ON immediately
3. **App-Only Control**: Relay stays ON until manually turned OFF via app
4. **No Auto-Shutdown**: Ensures emergency alerts persist until acknowledged

### Motion Monitoring
- PIR sensor detects presence and movement
- Inactivity alerts after 5 minutes of no motion
- Motion data logged for activity analysis

### Environmental Monitoring
- Temperature monitoring (alerts: <18°C or >28°C)
- Humidity monitoring (alerts: <30% or >70%)
- Environmental alerts for comfort monitoring (no relay activation)

### Emergency Relay Control
- **Fall Triggered**: Automatically activates on fall detection
- **Manual Control**: Turn ON/OFF via app interface
- **Emergency Stop**: Immediate safety shutdown button
- **App-Only Off**: Once activated by fall, only app can turn it off

## 📊 App Structure

### 1. Home Dashboard
- Real-time status overview
- Emergency status alerts
- Quick navigation to other pages
- Last update timestamp

### 2. Live Sensor Page
- Detailed sensor readings
- Color-coded status indicators
- Real-time data refresh
- OLED status monitoring

### 3. Relay Control Page
- Manual relay ON/OFF controls
- Emergency stop button
- Auto-control settings display
- Safety instructions

### 4. Graphs & Trends Page
- Temperature line charts
- Humidity trend analysis
- Activity timeline visualization
- Date range filtering (Today/7 Days/30 Days)

## 🚨 Safety Features

### Emergency Protocols
1. **Fall Detection**: Immediate relay activation with persistent alert
2. **Manual Override**: App-based emergency stop functionality
3. **No Auto-Timeout**: Relay stays active until manually deactivated
4. **Visual Alerts**: OLED display shows emergency status
5. **Persistent Notifications**: Buzzer continues until acknowledged

### Data Monitoring
- Real-time sensor data collection
- Historical data storage for trend analysis
- Environmental comfort alerts
- Motion pattern analysis

## 🔧 Troubleshooting

### Arduino Issues
- **WiFi Connection**: Check SSID/password, verify network
- **Sensor Readings**: Verify wiring connections
- **IP Address**: Check Serial Monitor for Arduino IP
- **Web Server**: Ensure Arduino and phone on same network

### App Issues
- **Connection Failed**: Update Arduino IP in `sensor_service.dart`
- **No Data**: Verify Arduino web server is running
- **Relay Control**: Check network connectivity and Arduino response

### Common Problems
1. **Relay Not Responding**: Check pin connections and relay module
2. **False Fall Alerts**: Adjust vibration sensor sensitivity
3. **Environmental Errors**: Verify DHT11 connections and power
4. **Display Issues**: Check OLED I2C connections (SDA/SCL)

## 📈 Future Enhancements

- Push notifications for emergency alerts
- Cloud data backup and synchronization
- Multiple device monitoring
- Advanced analytics and reporting
- Integration with healthcare systems
- Voice alerts and commands

## 🤝 Contributing

This is an educational project for elderly care monitoring. Feel free to contribute improvements for sensor accuracy, UI enhancements, or additional safety features.

## 📄 License

This project is for educational and care purposes. Use responsibly and ensure proper testing before deployment in real care environments.

---

**⚠️ Important Safety Note**: This system is designed for monitoring assistance only. It should not replace professional medical care or emergency services. Always ensure proper emergency contacts and procedures are in place.

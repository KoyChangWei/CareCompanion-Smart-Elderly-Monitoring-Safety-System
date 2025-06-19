import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class SensorService extends ChangeNotifier {
  // Server configuration
  static String get baseUrl => MyConfig.server;
  
  // Sensor data variables
  bool _fallDetected = false;
  bool _motionDetected = false;
  double _temperature = 0.0;
  double _humidity = 0.0;
  bool _relayStatus = false;
  DateTime _lastUpdate = DateTime.now();
  String _vibrationStatus = 'NO_VIBRATION';
  String _pirStatus = 'NO_MOTION';
  
  // Fall risk assessment data
  String _fallRiskLevel = 'SAFE';
  int _motionDuration = 0;
  int _motionBursts = 0;
  int _unsteadyMotions = 0;
  int _transferMotions = 0;
  int _steadyMotions = 0;
  
  // Fall detection state management
  bool _pendingFallReset = false;
  bool _manualRelayControl = false;
  DateTime? _lastFallDetection;
  
  // Historical data for graphs
  List<TemperatureReading> _temperatureHistory = [];
  List<HumidityReading> _humidityHistory = [];
  List<ActivityReading> _activityHistory = [];
  
  // Timers for data fetching
  Timer? _dataFetchTimer;
  Timer? _relayCheckTimer;
  
  // Loading states
  bool _isLoading = false;
  String? _errorMessage;
  bool _isConnected = false;
  DateTime? _lastSuccessfulConnection;
  
  // Getters
  bool get fallDetected => _fallDetected;
  bool get motionDetected => _motionDetected;
  
  // Get the latest motion duration from activity history
  int get latestMotionDuration {
    final recentMotion = _activityHistory
        .where((a) => a.type == 'MOTION' && !a.detected && a.duration > 0)
        .toList();
    if (recentMotion.isNotEmpty) {
      recentMotion.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return recentMotion.first.duration;
    }
    return 0;
  }
  double get temperature => _temperature;
  double get humidity => _humidity;
  bool get relayStatus => _relayStatus;
  DateTime get lastUpdate => _lastUpdate;
  String get vibrationStatus => _vibrationStatus;
  String get pirStatus => _pirStatus;
  
  // Fall risk assessment getters
  String get fallRiskLevel => _fallRiskLevel;
  int get motionDuration => _motionDuration;
  int get motionBursts => _motionBursts;
  int get unsteadyMotions => _unsteadyMotions;
  int get transferMotions => _transferMotions;
  int get steadyMotions => _steadyMotions;
  List<TemperatureReading> get temperatureHistory => _temperatureHistory;
  List<HumidityReading> get humidityHistory => _humidityHistory;
  List<ActivityReading> get activityHistory => _activityHistory;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get pendingFallReset => _pendingFallReset;
  bool get isConnected => _isConnected;
  DateTime? get lastSuccessfulConnection => _lastSuccessfulConnection;
  
  void startMonitoring() {
    // Fetch sensor data every 5 seconds
    _dataFetchTimer = Timer.periodic(MyConfig.dataRefreshInterval, (timer) {
      fetchSensorData();
    });
    
    // Check relay status every 3 seconds
    _relayCheckTimer = Timer.periodic(MyConfig.relayCheckInterval, (timer) {
      checkRelayStatus();
    });
    
    // Initial fetch
    fetchSensorData();
    checkRelayStatus();
    loadHistoricalData();
  }
  
  void stopMonitoring() {
    _dataFetchTimer?.cancel();
    _relayCheckTimer?.cancel();
  }
  
  Future<void> fetchSensorData() async {
    try {
      _errorMessage = null;
      
      // Fetch temperature and humidity data
      await _fetchDHTData();
      
      // Fetch PIR sensor data
      await _fetchPIRData();
      
      // Fetch vibration sensor data
      await _fetchVibrationData();
      
      _lastUpdate = MyConfig.malaysiaTime;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error fetching sensor data: $e';
      if (kDebugMode) {
        print('Error fetching sensor data: $e');
      }
      notifyListeners();
    }
  }
  
  Future<void> _fetchDHTData() async {
    try {
      final response = await http.get(
        Uri.parse('${baseUrl}${MyConfig.getLatestDhtEndpoint}'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(MyConfig.httpTimeout);
      
      if (kDebugMode) {
        print('DHT Response: Status=${response.statusCode}, Body=${response.body}');
      }
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data is Map && data.containsKey('temperature') && data.containsKey('humidity')) {
          final newTemp = double.tryParse(data['temperature']?.toString() ?? '0') ?? 0.0;
          final newHumidity = double.tryParse(data['humidity']?.toString() ?? '0') ?? 0.0;
          
          // Only update if we got valid data (not just zeros from empty database)
          if (newTemp > 0 || newHumidity > 0) {
            _temperature = newTemp;
            _humidity = newHumidity;
            _isConnected = true;
            _lastSuccessfulConnection = MyConfig.malaysiaTime;
            
            if (kDebugMode) {
              print('DHT Parsed: Temperature=$_temperature°C, Humidity=$_humidity%');
            }
            
            // Note: History data comes from database via loadHistoricalData(), not added here
            // ESP32 inserts data directly to database, frontend only reads from database
          } else {
            _isConnected = false;
            if (kDebugMode) {
              print('DHT: No valid data received (ESP likely disconnected)');
            }
          }
        } else {
          _isConnected = false;
        }
      } else {
        _isConnected = false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching DHT data: $e');
      }
    }
  }
  
  Future<void> _fetchPIRData() async {
    try {
      final response = await http.get(
        Uri.parse('${baseUrl}${MyConfig.getLatestPirEndpoint}'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(MyConfig.httpTimeout);
      
      if (kDebugMode) {
        print('PIR Response: Status=${response.statusCode}, Body=${response.body}');
      }
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data is Map && data.containsKey('status')) {
          _pirStatus = data['status']?.toString() ?? 'NO_MOTION';
          _motionDetected = _pirStatus == 'DETECTED';
          
          // Extract motion duration and fall risk information (now decoded by backend)
          if (data.containsKey('duration')) {
            _motionDuration = int.tryParse(data['duration']?.toString() ?? '0') ?? 0;
          }
          
          // Get fall risk level from backend (already decoded)
          if (data.containsKey('fall_risk_level')) {
            _fallRiskLevel = data['fall_risk_level']?.toString() ?? 'NORMAL';
          } else {
            // Fallback to old decoding method if backend doesn't provide fall_risk_level
            final rawDuration = int.tryParse(data['raw_duration']?.toString() ?? data['duration']?.toString() ?? '0') ?? 0;
            if (rawDuration >= 5000) {
              _fallRiskLevel = 'CRITICAL';
            } else if (rawDuration >= 4000) {
              _fallRiskLevel = 'HIGH_RISK';
            } else if (rawDuration >= 3000) {
              _fallRiskLevel = 'MODERATE_RISK';
            } else if (rawDuration >= 2000) {
              _fallRiskLevel = 'LOW_RISK';
            } else if (rawDuration >= 1000) {
              _fallRiskLevel = 'SAFE';
            } else {
              _fallRiskLevel = 'NORMAL';
            }
          }
          
          // Only add to history if ESP is connected (we got real sensor data)
          if (_isConnected) {
            if (kDebugMode) {
              print('PIR Parsed: Status=$_pirStatus, Detected=$_motionDetected, Duration=$_motionDuration, FallRisk=$_fallRiskLevel');
            }
            
            // Note: Activity history comes from database via loadHistoricalData(), not added here
            // ESP32 inserts PIR data directly to database, frontend only reads from database
          } else {
            if (kDebugMode) {
              print('PIR: Skipping history update - ESP not connected');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching PIR data: $e');
      }
    }
  }
  
  Future<void> _fetchVibrationData() async {
    try {
      final response = await http.get(
        Uri.parse('${baseUrl}${MyConfig.getLatestVibrationEndpoint}'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(MyConfig.httpTimeout);
      
      if (kDebugMode) {
        print('Vibration Response: Status=${response.statusCode}, Body=${response.body}');
      }
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data is Map) {
          final newVibrationStatus = data['status']?.toString() ?? 'NO_VIBRATION';
          final newFallDetected = newVibrationStatus == 'DETECTED';
          
          if (kDebugMode) {
            print('Vibration Parsed: Status=$newVibrationStatus, FallDetected=$newFallDetected');
          }
          
          // Handle fall detection logic
          if (newFallDetected && !_fallDetected) {
            // New fall detected
            _fallDetected = true;
            _lastFallDetection = MyConfig.malaysiaTime;
            _pendingFallReset = false;
            _manualRelayControl = false;
            
            if (kDebugMode) {
              print('🚨 NEW FALL DETECTED! Auto-turning ON relay...');
            }
            
            // Automatically turn on relay when fall is detected
            await _autoTurnOnRelay();
            
            // Note: Fall detection data comes from database via loadHistoricalData(), not added here
            // ESP32 inserts vibration sensor data directly to database, frontend only reads from database
            
          } else if (!newFallDetected && _fallDetected && _pendingFallReset) {
            // Fall detection returned to normal after manual relay turn off
            _fallDetected = false;
            _pendingFallReset = false;
            
            if (kDebugMode) {
              print('✅ Fall detection reset to normal');
            }
          }
          
          _vibrationStatus = newVibrationStatus;
          
          // Keep only last 100 readings
          if (_activityHistory.length > MyConfig.maxHistoryRecords) {
            _activityHistory.removeAt(0);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching vibration data: $e');
      }
    }
  }
  
  Future<void> _autoTurnOnRelay() async {
    try {
      final success = await toggleRelay(true);
      if (success) {
        if (kDebugMode) {
          print('✅ Auto relay ON successful');
        }
      } else {
        if (kDebugMode) {
          print('❌ Auto relay ON failed');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error auto-turning ON relay: $e');
      }
    }
  }
  
  Future<void> checkRelayStatus() async {
    try {
      final response = await http.get(
        Uri.parse('${baseUrl}${MyConfig.getRelayStatusEndpoint}'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(MyConfig.httpTimeout);
      
      if (kDebugMode) {
        print('Relay Response: Status=${response.statusCode}, Body=${response.body}');
      }
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data is Map) {
          final newRelayStatus = data['status']?.toString().toUpperCase() == 'ON';
          
          // Detect manual relay turn off
          if (_relayStatus && !newRelayStatus && _fallDetected && !_manualRelayControl) {
            // Relay was turned off manually while fall was detected
            _pendingFallReset = true;
            _manualRelayControl = true;
            
            if (kDebugMode) {
              print('🔄 Manual relay turn OFF detected - fall reset pending');
            }
          }
          
          _relayStatus = newRelayStatus;
          
          if (kDebugMode) {
            print('Relay Parsed: Status=${data['status']}, RelayOn=$_relayStatus');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking relay status: $e');
      }
    }
  }
  
  Future<bool> toggleRelay(bool turnOn) async {
    try {
      final status = turnOn ? 'ON' : 'OFF';
      final response = await http.get(
        Uri.parse('${baseUrl}${MyConfig.relayControlEndpoint}?status=$status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(MyConfig.httpTimeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['success'] == true) {
          _relayStatus = turnOn;
          
          // Handle manual relay control
          if (!turnOn && _fallDetected) {
            // Manual turn OFF during fall detection
            _manualRelayControl = true;
            _pendingFallReset = true;
            
            if (kDebugMode) {
              print('🔄 Manual relay turn OFF - fall reset will occur when vibration returns to normal');
            }
          }
          
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error controlling relay: $e');
      }
      return false;
    }
  }
  
  Future<bool> emergencyStop() async {
    return await toggleRelay(false);
  }
  
  // Reset fall detection manually (for testing or emergency reset)
  void resetFallDetection() {
    _fallDetected = false;
    _pendingFallReset = false;
    _manualRelayControl = false;
    _lastFallDetection = null;
    
    if (kDebugMode) {
      print('🔄 Fall detection manually reset');
    }
    
    notifyListeners();
  }
  
  // Get fall detection status info
  String getFallDetectionStatusInfo() {
    if (!_fallDetected) {
      return 'Normal - No fall detected';
    } else if (_pendingFallReset) {
      return 'Fall detected - Reset pending (waiting for vibration to clear)';
    } else {
      return 'Fall detected - Relay auto-activated';
    }
  }
  
  // Load historical data from backend
  Future<void> loadHistoricalData({int days = 7, bool silent = false}) async {
    try {
      if (!silent) {
        _isLoading = true;
        notifyListeners();
      }
      
      // Load DHT history and activity history in parallel
      await Future.wait([
        loadDHTHistory(days: days),
        loadActivityHistory(days: days),
      ]);
      
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    } catch (e) {
      if (!silent) {
        _isLoading = false;
        _errorMessage = 'Error loading historical data: $e';
        if (kDebugMode) {
          print('Error loading historical data: $e');
        }
      }
      notifyListeners();
    }
  }
  
  // Load DHT historical data from backend
  Future<void> loadDHTHistory({int days = 7}) async {
    try {
      final response = await http.get(
        Uri.parse('${baseUrl}${MyConfig.getDhtHistoryEndpoint}?days=$days'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(MyConfig.httpTimeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['status'] == 'success' && data['data'] != null) {
          _temperatureHistory.clear();
          _humidityHistory.clear();
          
          for (var item in data['data']) {
            final timestamp = DateTime.tryParse(item['timestamp'].toString()) ?? DateTime.now();
            final temp = double.tryParse(item['temperature'].toString()) ?? 0.0;
            final humidity = double.tryParse(item['humidity'].toString()) ?? 0.0;
            
            _temperatureHistory.add(TemperatureReading(
              timestamp: timestamp,
              value: temp,
            ));
            
            _humidityHistory.add(HumidityReading(
              timestamp: timestamp,
              value: humidity,
            ));
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading DHT history: $e');
      }
    }
  }
  
  // Load activity historical data from backend
  Future<void> loadActivityHistory({int days = 7}) async {
    try {
      final response = await http.get(
        Uri.parse('${baseUrl}${MyConfig.getActivityHistoryEndpoint}?days=$days'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(MyConfig.httpTimeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['status'] == 'success' && data['data'] != null) {
          _activityHistory.clear();
          
          for (var item in data['data']) {
            final timestamp = DateTime.tryParse(item['timestamp'].toString()) ?? DateTime.now();
            final type = item['type']?.toString() ?? 'UNKNOWN';
            final detected = item['detected'] == true;
            final duration = int.tryParse(item['duration']?.toString() ?? '0') ?? 0;
            final fallRiskLevel = item['fall_risk_level']?.toString() ?? 'NORMAL';
            
            _activityHistory.add(ActivityReading(
              timestamp: timestamp,
              type: type,
              detected: detected,
              duration: duration,
              fallRiskLevel: fallRiskLevel,
            ));
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading activity history: $e');
      }
    }
  }
  
  // Get temperature and humidity statistics
  Map<String, double> getTemperatureStats() {
    if (_temperatureHistory.isEmpty) return {'min': 0, 'max': 0, 'avg': 0};
    
    final values = _temperatureHistory.map((r) => r.value).toList();
    return {
      'min': values.reduce((a, b) => a < b ? a : b),
      'max': values.reduce((a, b) => a > b ? a : b),
      'avg': values.reduce((a, b) => a + b) / values.length,
    };
  }
  
  Map<String, double> getHumidityStats() {
    if (_humidityHistory.isEmpty) return {'min': 0, 'max': 0, 'avg': 0};
    
    final values = _humidityHistory.map((r) => r.value).toList();
    return {
      'min': values.reduce((a, b) => a < b ? a : b),
      'max': values.reduce((a, b) => a > b ? a : b),
      'avg': values.reduce((a, b) => a + b) / values.length,
    };
  }
  
  // Get activity counts
  Map<String, int> getActivityCounts({int days = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final recentActivity = _activityHistory.where((a) => a.timestamp.isAfter(cutoff)).toList();
    
    return {
      'motionCount': recentActivity.where((a) => a.type == 'MOTION' && a.detected).length,
      'fallCount': recentActivity.where((a) => a.type == 'FALL' && a.detected).length,
      'totalEvents': recentActivity.where((a) => a.detected).length,
    };
  }
  
  // Helper methods for fall risk assessment
  String getFallRiskDescription() {
    switch (_fallRiskLevel) {
      case 'CRITICAL':
        return 'Emergency - May need immediate assistance';
      case 'HIGH_RISK':
        return 'High fall risk - Monitor closely';
      case 'MODERATE_RISK':
        return 'Moderate fall risk - Stay alert';
      case 'LOW_RISK':
        return 'Low fall risk - Normal activity';
      case 'SAFE':
        return 'Safe movement - Good mobility';
      default:
        return 'No assessment available';
    }
  }
  
  Color getFallRiskColor() {
    switch (_fallRiskLevel) {
      case 'CRITICAL':
        return const Color(0xFFD32F2F); // Red 700
      case 'HIGH_RISK':
        return const Color(0xFFE53935); // Red 600
      case 'MODERATE_RISK':
        return const Color(0xFFFF9800); // Orange 500
      case 'LOW_RISK':
        return const Color(0xFFFFC107); // Amber 500
      case 'SAFE':
        return const Color(0xFF4CAF50); // Green 500
      default:
        return const Color(0xFF9E9E9E); // Grey 500
    }
  }
  
  IconData getFallRiskIcon() {
    switch (_fallRiskLevel) {
      case 'CRITICAL':
        return Icons.emergency;
      case 'HIGH_RISK':
        return Icons.warning;
      case 'MODERATE_RISK':
        return Icons.info_outline;
      case 'LOW_RISK':
        return Icons.check_circle_outline;
      case 'SAFE':
        return Icons.verified_user;
      default:
        return Icons.help_outline;
    }
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}

// Data models
class TemperatureReading {
  final DateTime timestamp;
  final double value;
  
  TemperatureReading({required this.timestamp, required this.value});
}

class HumidityReading {
  final DateTime timestamp;
  final double value;
  
  HumidityReading({required this.timestamp, required this.value});
}

class ActivityReading {
  final DateTime timestamp;
  final String type; // 'MOTION' or 'FALL'
  final bool detected;
  final int duration; // Duration in seconds (for motion events)
  final String fallRiskLevel; // Fall risk level for motion events
  
  ActivityReading({
    required this.timestamp,
    required this.type,
    required this.detected,
    this.duration = 0,
    this.fallRiskLevel = 'NORMAL',
  });
} 
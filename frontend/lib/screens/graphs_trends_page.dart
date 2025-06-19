import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:async';
import '../services/sensor_service.dart';
import '../config/app_config.dart';
import '../widgets/image_background_widget.dart';

// Activity status enum
enum ActivityStatus {
  normalMotion,
  fallDetected,
  noMotion,
}

// Activity segment class for timeline visualization
class ActivitySegment {
  final DateTime time;
  final ActivityStatus status;

  ActivitySegment({
    required this.time,
    required this.status,
  });

  ActivitySegment copyWith({
    DateTime? time,
    ActivityStatus? status,
  }) {
    return ActivitySegment(
      time: time ?? this.time,
      status: status ?? this.status,
    );
  }
}

// Vibration reading class (if not already defined in sensor service)
class VibrationReading {
  final DateTime timestamp;
  final bool detected;

  VibrationReading({
    required this.timestamp,
    required this.detected,
  });
}

class GraphsTrendsPage extends StatefulWidget {
  const GraphsTrendsPage({super.key});

  @override
  State<GraphsTrendsPage> createState() => _GraphsTrendsPageState();
}

class _GraphsTrendsPageState extends State<GraphsTrendsPage> with TickerProviderStateMixin {
  int _selectedDateRange = 1; // 0: Today, 1: Last 7 days, 2: Last 30 days (Default to Last 7 Days)
  final List<String> _dateRangeLabels = ['Today', 'Last 7 Days', 'Last 30 Days'];
  int _selectedChartType = 0; // 0: Temperature, 1: Humidity, 2: Activity
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Auto-refresh functionality
  Timer? _refreshTimer;
  bool _isAutoRefreshEnabled = true;
  DateTime? _lastRefreshTime;
  bool _isBackgroundRefresh = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    
    _fadeController.forward();
    _slideController.forward();
    
    // Load initial data for Last 7 Days
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDataForSelectedRange();
      _startAutoRefresh();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ImageBackgroundWidget(
        backgroundType: BackgroundType.analytics,
        opacity: 0.3,
        child: Consumer<SensorService>(
          builder: (context, sensorService, child) {
            return CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, sensorService),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          _buildDateRangeSelector(),
                          const SizedBox(height: 24),
                          if (sensorService.isLoading && !_isBackgroundRefresh)
                            _buildLoadingCard()
                          else ...[
                            _buildSummaryCards(sensorService),
                            const SizedBox(height: 24),
                            _buildChartSelector(),
                            const SizedBox(height: 20),
                                                      _buildSelectedChart(sensorService),
                          const SizedBox(height: 24),
                          _buildMotionActivityLog(sensorService),
                          const SizedBox(height: 24),
                          _buildInsightsCard(sensorService),
                          ],
                          if (sensorService.errorMessage != null)
                            _buildErrorCard(sensorService.errorMessage!),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, SensorService sensorService) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF8E24AA),
      flexibleSpace: FlexibleSpaceBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.analytics_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Data Analytics',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFF8E24AA), const Color(0xFF7B1FA2)],
            ),
          ),
        ),
      ),
      actions: [
        // Auto-refresh toggle button
        IconButton(
          icon: Icon(
            _isAutoRefreshEnabled ? Icons.pause_circle_outline : Icons.play_circle_outline,
            color: _isAutoRefreshEnabled ? Colors.green : Colors.white,
          ),
          onPressed: _toggleAutoRefresh,
          tooltip: _isAutoRefreshEnabled ? 'Pause auto-refresh' : 'Start auto-refresh',
        ),
        
        // Manual refresh button
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () {
            _manualRefreshData();
            _fadeController.reset();
            _fadeController.forward();
          },
          tooltip: 'Manual refresh',
        ),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading analytics data...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.blue[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.date_range_rounded,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Time Range',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    if (_lastRefreshTime != null)
                      Text(
                        'Updated: ${DateFormat('HH:mm:ss').format(_lastRefreshTime!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              // Live indicator with refresh animation
              if (_isAutoRefreshEnabled)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isBackgroundRefresh 
                        ? Colors.orange.withOpacity(0.15)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isBackgroundRefresh 
                          ? Colors.orange.withOpacity(0.4)
                          : Colors.green.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _isBackgroundRefresh ? Colors.orange : Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _isBackgroundRefresh ? Colors.orange : Colors.green,
                        ),
                        child: Text(_isBackgroundRefresh ? 'SYNC' : 'LIVE'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: List.generate(
              _dateRangeLabels.length,
              (index) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index < _dateRangeLabels.length - 1 ? 8 : 0,
                    left: index > 0 ? 8 : 0,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedDateRange = index;
                        });
                        _loadDataForSelectedRangeSilent();
                        
                        // Restart auto-refresh for new time range
                        if (_isAutoRefreshEnabled) {
                          _startAutoRefresh();
                        }
                        
                        // Add a small animation feedback
                        _fadeController.reset();
                        _fadeController.forward();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedDateRange == index
                            ? Colors.blue
                            : Colors.white,
                        foregroundColor: _selectedDateRange == index
                            ? Colors.white
                            : Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: _selectedDateRange == index ? 4 : 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _dateRangeLabels[index],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(SensorService sensorService) {
    final filteredTempData = _getFilteredTemperatureData(sensorService);
    final filteredHumidityData = _getFilteredHumidityData(sensorService);
    final filteredActivityData = _getFilteredActivityData(sensorService);

    double avgTemp = 0;
    double avgHumidity = 0;
    int totalActivities = 0;

    if (filteredTempData.isNotEmpty) {
      avgTemp = filteredTempData.map((e) => e.value).reduce((a, b) => a + b) / filteredTempData.length;
    }

    if (filteredHumidityData.isNotEmpty) {
      avgHumidity = filteredHumidityData.map((e) => e.value).reduce((a, b) => a + b) / filteredHumidityData.length;
    }

    if (filteredActivityData.isNotEmpty) {
      // Calculate walking sessions (pairs of DETECTED + NO_MOTION)
      int walkingSessions = 0;
      for (int i = 0; i < filteredActivityData.length - 1; i++) {
        final current = filteredActivityData[i];
        if (current.detected && current.type == 'MOTION') {
          walkingSessions++;
        }
      }
      totalActivities = (walkingSessions / 2).ceil(); // Each session has start + end
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Summary Statistics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Text(
                _dateRangeLabels[_selectedDateRange],
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildModernSummaryCard(
                title: 'Avg Temperature',
                value: '${avgTemp.toStringAsFixed(1)}°C',
                icon: Icons.thermostat_rounded,
                color: _getTemperatureColor(avgTemp),
                gradient: [Colors.red[50]!, Colors.red[100]!],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildModernSummaryCard(
                title: 'Avg Humidity',
                value: '${avgHumidity.toStringAsFixed(1)}%',
                icon: Icons.water_drop_rounded,
                color: _getHumidityColor(avgHumidity),
                gradient: [Colors.blue[50]!, Colors.blue[100]!],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildModernSummaryCard(
                title: 'Walking Sessions',
                value: '$totalActivities',
                icon: FontAwesomeIcons.personWalking,
                color: Colors.orange,
                gradient: [Colors.orange[50]!, Colors.orange[100]!],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildModernSummaryCard(
                title: 'DHT Records',
                value: '${filteredTempData.length}',
                icon: Icons.analytics_rounded,
                color: Colors.purple,
                gradient: [Colors.purple[50]!, Colors.purple[100]!],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModernSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChartSelector() {
    final chartTypes = [
      {'label': 'Temperature', 'icon': Icons.thermostat_rounded, 'color': Colors.red},
      {'label': 'Humidity', 'icon': Icons.water_drop_rounded, 'color': Colors.blue},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Chart View',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (_isAutoRefreshEnabled && _selectedDateRange == 0)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isBackgroundRefresh 
                        ? Colors.orange.withOpacity(0.15)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isBackgroundRefresh 
                          ? Colors.orange.withOpacity(0.4)
                          : Colors.green.withOpacity(0.3),
                    ),
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _isBackgroundRefresh ? Colors.orange : Colors.green,
                    ),
                    child: Text(_isBackgroundRefresh ? 'Syncing...' : 'Real-time'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(
              chartTypes.length,
              (index) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index < chartTypes.length - 1 ? 8 : 0,
                    left: index > 0 ? 8 : 0,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedChartType = index;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _selectedChartType == index
                              ? chartTypes[index]['color'] as Color
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              chartTypes[index]['icon'] as IconData,
                              color: _selectedChartType == index
                                  ? Colors.white
                                  : chartTypes[index]['color'] as Color,
                              size: 20,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              chartTypes[index]['label'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _selectedChartType == index
                                    ? Colors.white
                                    : chartTypes[index]['color'] as Color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedChart(SensorService sensorService) {
    switch (_selectedChartType) {
      case 0:
        return _buildTemperatureChart(sensorService);
      case 1:
        return _buildHumidityChart(sensorService);
      default:
        return _buildTemperatureChart(sensorService);
    }
  }

  Widget _buildInsightsCard(SensorService sensorService) {
    final insights = _generateInsights(sensorService);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[50]!, Colors.green[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.lightbulb_rounded,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Smart Insights',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...insights.map((insight) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    insight,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green[700],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String errorMessage) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[600], size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Error Loading Data',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  errorMessage,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Auto-refresh methods
  void _startAutoRefresh() {
    if (!_isAutoRefreshEnabled) return;
    
    _refreshTimer?.cancel(); // Cancel any existing timer
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _isAutoRefreshEnabled) {
        _refreshSensorData();
      }
    });
    
    if (kDebugMode) {
      print('📊 Auto-refresh started: updating every 5 seconds');
    }
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    
    if (kDebugMode) {
      print('📊 Auto-refresh stopped');
    }
  }

  void _refreshSensorData() async {
    final sensorService = Provider.of<SensorService>(context, listen: false);
    
    // Silent refresh - don't trigger loading state
    await _silentDataRefresh(sensorService);
    
    // Update last refresh time
    if (mounted) {
      setState(() {
        _lastRefreshTime = DateTime.now();
      });
    }
    
    if (kDebugMode) {
      print('📊 Sensor data refreshed silently at ${DateFormat('HH:mm:ss').format(_lastRefreshTime!)}');
    }
  }

  // Silent data refresh without loading indicators
  Future<void> _silentDataRefresh(SensorService sensorService) async {
    try {
      // Set background refresh flag to prevent loading UI
      setState(() {
        _isBackgroundRefresh = true;
      });
      
      // Update current sensor readings silently
      await sensorService.fetchSensorData();
      await sensorService.checkRelayStatus();
      
      // For "Today" view, also refresh historical data to get latest entries (silent mode)
      if (_selectedDateRange == 0) {
        await sensorService.loadHistoricalData(days: 1, silent: true);
      }
    } catch (e) {
      if (kDebugMode) {
        print('📊 Silent refresh error: $e');
      }
      // Don't show error to user during background refresh
    } finally {
      // Reset background refresh flag
      if (mounted) {
        setState(() {
          _isBackgroundRefresh = false;
        });
      }
    }
  }

  void _toggleAutoRefresh() {
    setState(() {
      _isAutoRefreshEnabled = !_isAutoRefreshEnabled;
    });
    
    if (_isAutoRefreshEnabled) {
      _startAutoRefresh();
    } else {
      _stopAutoRefresh();
    }
  }

  // Manual refresh data without showing loading indicators
  void _manualRefreshData() async {
    final sensorService = Provider.of<SensorService>(context, listen: false);
    
    try {
      // Set background refresh flag to prevent loading UI during manual refresh
      setState(() {
        _isBackgroundRefresh = true;
      });
      
      int days = 1; // Today
      
      switch (_selectedDateRange) {
        case 0: // Today
          days = 1;
          break;
        case 1: // Last 7 days
          days = 7;
          break;
        case 2: // Last 30 days
          days = 30;
          break;
      }
      
      // Load data silently and refresh sensor data
      await Future.wait([
        sensorService.loadHistoricalData(days: days, silent: true),
        sensorService.fetchSensorData(),
        sensorService.checkRelayStatus(),
      ]);
      
      // Update last refresh time
      if (mounted) {
        setState(() {
          _lastRefreshTime = DateTime.now();
        });
      }
      
      if (kDebugMode) {
        print('📊 Manual refresh completed at ${DateFormat('HH:mm:ss').format(_lastRefreshTime!)}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('📊 Manual refresh error: $e');
      }
    } finally {
      // Reset background refresh flag
      if (mounted) {
        setState(() {
          _isBackgroundRefresh = false;
        });
      }
    }
  }

  void _loadDataForSelectedRange() {
    final sensorService = Provider.of<SensorService>(context, listen: false);
    int days = 1; // Today
    
    switch (_selectedDateRange) {
      case 0: // Today
        days = 1;
        break;
      case 1: // Last 7 days
        days = 7;
        break;
      case 2: // Last 30 days
        days = 30;
        break;
    }
    
    if (kDebugMode) {
      print('📊 Loading analytics data for: ${_dateRangeLabels[_selectedDateRange]} ($days days)');
    }
    
    // Load historical data from backend with the selected days
    sensorService.loadHistoricalData(days: days);
  }

  // Load data for selected range without showing loading indicators
  void _loadDataForSelectedRangeSilent() async {
    final sensorService = Provider.of<SensorService>(context, listen: false);
    int days = 1; // Today
    
    switch (_selectedDateRange) {
      case 0: // Today
        days = 1;
        break;
      case 1: // Last 7 days
        days = 7;
        break;
      case 2: // Last 30 days
        days = 30;
        break;
    }
    
    try {
      // Set background refresh flag to prevent loading UI
      setState(() {
        _isBackgroundRefresh = true;
      });
      
      if (kDebugMode) {
        print('📊 Loading analytics data silently for: ${_dateRangeLabels[_selectedDateRange]} ($days days)');
      }
      
      // Load historical data silently
      await sensorService.loadHistoricalData(days: days, silent: true);
      
      // Update last refresh time for the new range
      if (mounted) {
        setState(() {
          _lastRefreshTime = DateTime.now();
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('📊 Silent range load error: $e');
      }
    } finally {
      // Reset background refresh flag
      if (mounted) {
        setState(() {
          _isBackgroundRefresh = false;
        });
      }
    }
  }

  List<String> _generateInsights(SensorService sensorService) {
    final insights = <String>[];
    final tempData = _getFilteredTemperatureData(sensorService);
    final humidityData = _getFilteredHumidityData(sensorService);
    final activityData = _getFilteredActivityData(sensorService);

    if (tempData.isNotEmpty) {
      final avgTemp = tempData.map((e) => e.value).reduce((a, b) => a + b) / tempData.length;
      if (avgTemp > 28) {
        insights.add('Temperature is above comfort range. Consider improving ventilation.');
      } else if (avgTemp < 18) {
        insights.add('Temperature is below comfort range. Consider adjusting heating.');
      } else {
        insights.add('Temperature levels are within the optimal comfort range.');
      }
    }

    if (humidityData.isNotEmpty) {
      final avgHumidity = humidityData.map((e) => e.value).reduce((a, b) => a + b) / humidityData.length;
      if (avgHumidity > 70) {
        insights.add('Humidity is high. Consider using a dehumidifier to prevent mold.');
      } else if (avgHumidity < 30) {
        insights.add('Humidity is low. Consider using a humidifier for comfort.');
      } else {
        insights.add('Humidity levels are within the healthy range.');
      }
    }

    if (activityData.isNotEmpty) {
      final fallEvents = activityData.where((e) => e.detected && e.type == 'FALL').length;
      final timeRange = _dateRangeLabels[_selectedDateRange].toLowerCase();
      
      // Calculate walking sessions (NO_MOTION events with duration > 0)
      final walkingSessions = activityData.where((e) => 
        e.type == 'MOTION' && !e.detected && e.duration > 0
      ).length;
      
      // Calculate total motion time
      final totalMotionTime = activityData.where((e) => 
        e.type == 'MOTION' && !e.detected && e.duration > 0
      ).fold<int>(0, (sum, e) => sum + e.duration);
      
      if (fallEvents > 0) {
        insights.add('⚠️ $fallEvents fall event(s) detected $timeRange. Please review safety measures.');
      }
      
      if (walkingSessions > 15) {
        insights.add('✅ High mobility detected: $walkingSessions walking sessions $timeRange. Elderly person is very active.');
      } else if (walkingSessions < 3) {
        insights.add('⚠️ Low mobility: Only $walkingSessions walking sessions $timeRange. Consider encouraging more movement.');
      } else {
        insights.add('✅ Normal mobility: $walkingSessions walking sessions $timeRange. Good activity level maintained.');
      }
      
      // Add motion time insights
      if (totalMotionTime > 0) {
        final minutes = totalMotionTime ~/ 60;
        final seconds = totalMotionTime % 60;
        if (minutes > 0) {
          insights.add('⏱️ Total active time: ${minutes}m ${seconds}s across $walkingSessions sessions');
        } else {
          insights.add('⏱️ Total active time: ${seconds}s across $walkingSessions sessions');
        }
      }
      
      // Add specific insights for 7-day period
      if (_selectedDateRange == 1) {
        final dailyAverage = walkingSessions / 7;
        final dailyMotionTime = totalMotionTime / 7;
        insights.add('📊 Daily average: ${dailyAverage.toStringAsFixed(1)} sessions, ${(dailyMotionTime / 60).toStringAsFixed(1)} minutes');
        
        if (dailyAverage >= 3) {
          insights.add('💪 Excellent daily mobility pattern maintained over the week.');
        } else if (dailyAverage >= 1.5) {
          insights.add('👍 Moderate daily activity - consider gentle encouragement for more movement.');
        } else {
          insights.add('🚨 Low daily activity pattern - may need assistance or health check.');
        }
      }
    }

    if (insights.isEmpty) {
      insights.add('Insufficient data for generating insights. Please check sensor connections.');
    }
    
    // Add auto-refresh information
    if (_isAutoRefreshEnabled) {
      if (_selectedDateRange == 0) {
        insights.add('📡 Real-time monitoring active: Charts update silently every 5 seconds with fresh sensor data.');
      } else {
        insights.add('⏱️ Auto-refresh enabled: Current readings update silently every 5 seconds (historical data refreshes manually).');
      }
      if (_isBackgroundRefresh) {
        insights.add('🔄 Currently syncing data in the background...');
      }
    } else {
      insights.add('⏸️ Auto-refresh paused: Use the play button in the header to enable real-time updates.');
    }

    return insights;
  }

  Widget _buildTemperatureChart(SensorService sensorService) {
    final data = _getFilteredTemperatureData(sensorService);
    
    if (data.isEmpty) {
      return _buildNoDataCard('No temperature data available for the selected period');
    }

    return _buildModernChartCard(
      title: 'Temperature Trends',
      icon: Icons.thermostat_rounded,
      color: const Color(0xFF8E24AA),
      gradient: [const Color(0xFF8E24AA), const Color(0xFF7B1FA2)],
      child: SizedBox(
        height: 320,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              horizontalInterval: 3,
              verticalInterval: _getXAxisInterval(data.length).toDouble(),
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey[200]!,
                  strokeWidth: 0.8,
                );
              },
              getDrawingVerticalLine: (value) {
                return FlLine(
                  color: Colors.grey[200]!,
                  strokeWidth: 0.8,
                );
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: _getXAxisInterval(data.length) * 3, // Show fewer labels
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < data.length) {
                      String formatString;
                      switch (_selectedDateRange) {
                        case 0: // Today
                          formatString = 'HH:mm';
                          break;
                        case 1: // Last 7 days
                          formatString = 'MM/dd';
                          break;
                        case 2: // Last 30 days
                          formatString = 'MM/dd';
                          break;
                        default:
                          formatString = 'HH:mm';
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          DateFormat(formatString).format(data[index].timestamp),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 10, // Smaller font
                          ),
                        ),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 5,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      '${value.toInt()}°C',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
            minX: 0,
            maxX: (data.length - 1).toDouble(),
            minY: (data.map((e) => e.value).reduce((a, b) => a < b ? a : b) - 3).clamp(0, double.infinity),
            maxY: data.map((e) => e.value).reduce((a, b) => a > b ? a : b) + 3,
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                tooltipBgColor: Colors.white,
                tooltipRoundedRadius: 12,
                tooltipPadding: const EdgeInsets.all(12),
                tooltipMargin: 8,
                getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                  return touchedBarSpots.map((barSpot) {
                    final index = barSpot.x.toInt();
                    if (index >= 0 && index < data.length) {
                      final dataPoint = data[index];
                      return LineTooltipItem(
                        '🌡️ Temperature\n',
                        const TextStyle(
                          color: Color(0xFF8E24AA),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: '${dataPoint.value.toStringAsFixed(1)}°C\n',
                            style: const TextStyle(
                              color: Color(0xFF8E24AA),
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          TextSpan(
                            text: DateFormat('MMM dd, yyyy\nHH:mm:ss').format(dataPoint.timestamp),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      );
                    }
                    return null;
                  }).toList();
                },
              ),
              touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                // Add haptic feedback on touch
                if (event is FlTapUpEvent && touchResponse != null) {
                  // You can add haptic feedback here if needed
                }
              },
            ),
            lineBarsData: [
              LineChartBarData(
                spots: data.asMap().entries.map((entry) {
                  return FlSpot(entry.key.toDouble(), entry.value.value);
                }).toList(),
                isCurved: true,
                curveSmoothness: 0.55, // Increased for smoother curves
                preventCurveOverShooting: true, // Prevents curves from overshooting data points
                preventCurveOvershootingThreshold: 5.0, // Controls overshoot prevention
                gradient: const LinearGradient(
                  colors: [Color(0xFF8E24AA), Color(0xFF7B1FA2)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                barWidth: 4.0, // Slightly thicker line for better visibility
                isStrokeCapRound: true,
                isStrokeJoinRound: true, // Smooth line joins
                dotData: FlDotData(
                  show: data.length <= 20, // Only show dots when data points are fewer for cleaner look
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 3.5, // Slightly smaller dots
                      color: Colors.white,
                      strokeWidth: 2.0,
                      strokeColor: const Color(0xFF8E24AA),
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF8E24AA).withOpacity(0.15),
                      const Color(0xFF8E24AA).withOpacity(0.05),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHumidityChart(SensorService sensorService) {
    final data = _getFilteredHumidityData(sensorService);
    
    if (data.isEmpty) {
      return _buildNoDataCard('No humidity data available for the selected period');
    }

    return _buildModernChartCard(
      title: 'Humidity Trends',
      icon: Icons.water_drop_rounded,
      color: const Color(0xFF1976D2),
      gradient: [const Color(0xFF1976D2), const Color(0xFF1565C0)],
      child: SizedBox(
        height: 320,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              horizontalInterval: 10,
              verticalInterval: _getXAxisInterval(data.length).toDouble(),
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey[200]!,
                  strokeWidth: 0.8,
                );
              },
              getDrawingVerticalLine: (value) {
                return FlLine(
                  color: Colors.grey[200]!,
                  strokeWidth: 0.8,
                );
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: _getXAxisInterval(data.length) * 3, // Show fewer labels
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < data.length) {
                      String formatString;
                      switch (_selectedDateRange) {
                        case 0: // Today
                          formatString = 'HH:mm';
                          break;
                        case 1: // Last 7 days
                          formatString = 'MM/dd';
                          break;
                        case 2: // Last 30 days
                          formatString = 'MM/dd';
                          break;
                        default:
                          formatString = 'HH:mm';
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          DateFormat(formatString).format(data[index].timestamp),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 10, // Smaller font
                          ),
                        ),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 10,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      '${value.toInt()}%',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
            minX: 0,
            maxX: (data.length - 1).toDouble(),
            minY: 0,
            maxY: 100,
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                tooltipBgColor: Colors.white,
                tooltipRoundedRadius: 12,
                tooltipPadding: const EdgeInsets.all(12),
                tooltipMargin: 8,
                getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                  return touchedBarSpots.map((barSpot) {
                    final index = barSpot.x.toInt();
                    if (index >= 0 && index < data.length) {
                      final dataPoint = data[index];
                      return LineTooltipItem(
                        '💧 Humidity\n',
                        const TextStyle(
                          color: Color(0xFF1976D2),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: '${dataPoint.value.toStringAsFixed(1)}%\n',
                            style: const TextStyle(
                              color: Color(0xFF1976D2),
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          TextSpan(
                            text: DateFormat('MMM dd, yyyy\nHH:mm:ss').format(dataPoint.timestamp),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      );
                    }
                    return null;
                  }).toList();
                },
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: data.asMap().entries.map((entry) {
                  return FlSpot(entry.key.toDouble(), entry.value.value);
                }).toList(),
                isCurved: true,
                curveSmoothness: 0.55, // Increased for smoother curves
                preventCurveOverShooting: true, // Prevents curves from overshooting data points
                preventCurveOvershootingThreshold: 10.0, // Controls overshoot prevention (higher for humidity)
                gradient: const LinearGradient(
                  colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                barWidth: 4.0, // Slightly thicker line for better visibility
                isStrokeCapRound: true,
                isStrokeJoinRound: true, // Smooth line joins
                dotData: FlDotData(
                  show: data.length <= 20, // Only show dots when data points are fewer for cleaner look
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 3.5, // Slightly smaller dots
                      color: Colors.white,
                      strokeWidth: 2.0,
                      strokeColor: const Color(0xFF1976D2),
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1976D2).withOpacity(0.15),
                      const Color(0xFF1976D2).withOpacity(0.05),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildMotionActivityLog(SensorService sensorService) {
    final activityData = _getFilteredActivityData(sensorService);
    
    // Separate motion and fall events
    final motionEvents = <Map<String, dynamic>>[];
    final fallEvents = <Map<String, dynamic>>[];
    
    // Process motion events - look for NO_MOTION events with duration > 0
    for (final activity in activityData) {
      if (activity.type == 'MOTION' && !activity.detected && activity.duration > 0) {
        // This is a motion end event with duration
        motionEvents.add({
          'type': 'MOTION',
          'timestamp': activity.timestamp,
          'duration': activity.duration,
        });
      }
      
      // Look for FALL events
      if (activity.type == 'FALL' && activity.detected) {
        fallEvents.add({
          'type': 'FALL',
          'timestamp': activity.timestamp,
          'severity': 'HIGH', // All falls are considered high severity
        });
      }
    }

    // Combine and sort all events by timestamp
    final allEvents = <Map<String, dynamic>>[];
    allEvents.addAll(motionEvents);
    allEvents.addAll(fallEvents);
    
    // Sort by timestamp (most recent first)
    allEvents.sort((a, b) {
      final timeA = a['timestamp'] as DateTime;
      final timeB = b['timestamp'] as DateTime;
      return timeB.compareTo(timeA);
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.withOpacity(0.1),
                          Colors.red.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      FontAwesomeIcons.heartPulse,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Activity & Safety Log',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (fallEvents.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            FontAwesomeIcons.triangleExclamation,
                            size: 10,
                            color: Colors.red[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${fallEvents.length} Fall${fallEvents.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              color: Colors.red[600],
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${allEvents.length} Total',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          if (allEvents.isEmpty)
            _buildNoActivityMessage()
          else
            _buildActivityEventsList(allEvents),
        ],
      ),
    );
  }

  Widget _buildNoActivityMessage() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            FontAwesomeIcons.heartPulse,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No activity detected',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Motion and fall events will appear here when detected',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityEventsList(List<Map<String, dynamic>> allEvents) {
    return Column(
      children: [
        // Legend
        Row(
          children: [
            _buildActivityLegendItem('Fall Event', Colors.red[500]!, FontAwesomeIcons.personFalling),
            const SizedBox(width: 4),
            _buildActivityLegendItem('Short Walk', Colors.green[300]!, FontAwesomeIcons.personWalking),
            const SizedBox(width: 4),
            _buildActivityLegendItem('Long Walk', Colors.orange[400]!, FontAwesomeIcons.personRunning),
          ],
        ),
        const SizedBox(height: 20),
        
        // Activity events list
        Container(
          constraints: const BoxConstraints(maxHeight: 350),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: allEvents.length,
            itemBuilder: (context, index) {
              final event = allEvents[index];
              final eventType = event['type'] as String;
              
              if (eventType == 'FALL') {
                return _buildFallEventItem(event, index);
              } else {
                final timestamp = event['timestamp'] as DateTime;
                final duration = event['duration'] as int;
                return _buildMotionEventItem(timestamp, duration, index);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActivityLegendItem(String label, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 14,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMotionEventItem(DateTime timestamp, int duration, int index) {
    Color eventColor;
    String durationText;
    String activityType;
    
    if (duration <= 30) {
      eventColor = Colors.green[300]!;
      activityType = 'Short Walk';
    } else if (duration <= 60) {
      eventColor = Colors.orange[400]!;
      activityType = 'Medium Walk';
    } else {
      eventColor = Colors.red[400]!;
      activityType = 'Long Walk';
    }
    
    if (duration < 60) {
      durationText = '${duration}s';
    } else {
      final minutes = duration ~/ 60;
      final seconds = duration % 60;
      durationText = '${minutes}m ${seconds}s';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: eventColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: eventColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: eventColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      FontAwesomeIcons.personWalking,
                      size: 14,
                      color: eventColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        activityType,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: eventColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        durationText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: eventColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, yyyy • HH:mm').format(timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallEventItem(Map<String, dynamic> event, int index) {
    final timestamp = event['timestamp'] as DateTime;
    final severity = event['severity'] as String;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red[50]!,
            Colors.red[100]!.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.red[500],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red[500],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        FontAwesomeIcons.personFalling,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '🚨 FALL DETECTED',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red[500],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        severity,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Emergency response may be required',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, yyyy • HH:mm:ss').format(timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorCodedActivityStrip(List<ActivityReading> activityData) {
    // Create 24-hour timeline with 15-minute intervals (96 segments)
    final segments = <ActivitySegment>[];
    final now = MyConfig.malaysiaTime;
    final startOfDay = DateTime(now.year, now.month, now.day);
    
    // Initialize all segments as no motion (gray)
    for (int i = 0; i < 96; i++) {
      final segmentTime = startOfDay.add(Duration(minutes: i * 15));
      segments.add(ActivitySegment(
        time: segmentTime,
        status: ActivityStatus.noMotion,
      ));
    }
    
    // Process activity data and mark segments
    for (final activity in activityData) {
      if (activity.detected) {
        final minutesSinceStart = activity.timestamp.difference(startOfDay).inMinutes;
        final segmentIndex = (minutesSinceStart / 15).floor();
        if (segmentIndex >= 0 && segmentIndex < segments.length) {
          // Check activity type - fall detection overrides normal motion
          if (activity.type == 'FALL') {
            segments[segmentIndex] = segments[segmentIndex].copyWith(status: ActivityStatus.fallDetected);
          } else if (activity.type == 'MOTION' && segments[segmentIndex].status != ActivityStatus.fallDetected) {
            segments[segmentIndex] = segments[segmentIndex].copyWith(status: ActivityStatus.normalMotion);
          }
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend
        _buildActivityLegend(),
        const SizedBox(height: 20),
        
        // Time labels
        _buildTimeLabels(),
        const SizedBox(height: 8),
        
        // Activity strip
        Container(
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: segments.map((segment) => Expanded(
              child: Container(
                height: double.infinity,
                decoration: BoxDecoration(
                  color: _getActivityColor(segment.status),
                  border: Border(
                    right: BorderSide(
                      color: Colors.white,
                      width: 0.5,
                    ),
                  ),
                ),
              ),
            )).toList(),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Summary stats
        _buildActivitySummary(segments),
      ],
    );
  }

  Widget _buildActivityLegend() {
    return Wrap(
      alignment: WrapAlignment.spaceEvenly,
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildLegendItem('Motion', Colors.green, FontAwesomeIcons.personWalking),
        _buildLegendItem('Fall Alert', Colors.red, FontAwesomeIcons.triangleExclamation),
        _buildLegendItem('Rest', Colors.grey[400]!, FontAwesomeIcons.moon),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeLabels() {
    return Row(
      children: List.generate(9, (index) {
        final hour = index * 3; // 0, 3, 6, 9, 12, 15, 18, 21
        return Expanded(
          child: Text(
            '${hour.toString().padLeft(2, '0')}:00',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: index == 0 ? TextAlign.start : 
                     index == 8 ? TextAlign.end : TextAlign.center,
          ),
        );
      }),
    );
  }

  Widget _buildActivitySummary(List<ActivitySegment> segments) {
    final motionCount = segments.where((s) => s.status == ActivityStatus.normalMotion).length;
    final fallCount = segments.where((s) => s.status == ActivityStatus.fallDetected).length;
    final noMotionCount = segments.where((s) => s.status == ActivityStatus.noMotion).length;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Active Periods', '$motionCount', Colors.green),
          _buildSummaryItem('Fall Alerts', '$fallCount', Colors.red),
          _buildSummaryItem('Rest Periods', '$noMotionCount', Colors.grey[600]!),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Color _getActivityColor(ActivityStatus status) {
    switch (status) {
      case ActivityStatus.normalMotion:
        return Colors.green;
      case ActivityStatus.fallDetected:
        return Colors.red;
      case ActivityStatus.noMotion:
        return Colors.grey[400]!;
    }
  }



  Widget _buildChartCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildModernChartCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Color> gradient,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradient[0].withOpacity(0.05),
            gradient[1].withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: gradient[0].withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(23),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: gradient[0].withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: gradient[1],
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap data points for details',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        gradient[0].withOpacity(0.1),
                        gradient[1].withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: gradient[0].withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _isBackgroundRefresh 
                              ? Colors.orange
                              : _isAutoRefreshEnabled && _selectedDateRange == 0 
                                  ? Colors.green 
                                  : gradient[0],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _isBackgroundRefresh 
                              ? Colors.orange
                              : _isAutoRefreshEnabled && _selectedDateRange == 0 
                                  ? Colors.green 
                                  : gradient[1],
                        ),
                        child: Text(
                          _isBackgroundRefresh 
                              ? 'Sync'
                              : _isAutoRefreshEnabled && _selectedDateRange == 0 
                                  ? 'Live' 
                                  : 'Chart',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  double _getXAxisInterval(int dataLength) {
    if (dataLength <= 10) return 1;
    if (dataLength <= 50) return 5;
    return (dataLength / 10).ceil().toDouble();
  }

  List<TemperatureReading> _getFilteredTemperatureData(SensorService sensorService) {
    final now = MyConfig.malaysiaTime;
    DateTime startDate;
    
    switch (_selectedDateRange) {
      case 0: // Today
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 1: // Last 7 days
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 2: // Last 30 days
        startDate = now.subtract(const Duration(days: 30));
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }
    
    // Filter data to show only the selected time range
    final filteredData = sensorService.temperatureHistory
        .where((reading) => reading.timestamp.isAfter(startDate) && reading.timestamp.isBefore(now.add(const Duration(days: 1))))
        .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    // Apply light smoothing for better visual appearance when there are many data points
    if (filteredData.length > 10 && _selectedDateRange > 0) {
      return _applySmoothingToTemperatureData(filteredData);
    }
    
    return filteredData;
  }

  List<HumidityReading> _getFilteredHumidityData(SensorService sensorService) {
    final now = MyConfig.malaysiaTime;
    DateTime startDate;
    
    switch (_selectedDateRange) {
      case 0: // Today
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 1: // Last 7 days
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 2: // Last 30 days
        startDate = now.subtract(const Duration(days: 30));
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }
    
    // Filter data to show only the selected time range
    final filteredData = sensorService.humidityHistory
        .where((reading) => reading.timestamp.isAfter(startDate) && reading.timestamp.isBefore(now.add(const Duration(days: 1))))
        .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    // Apply light smoothing for better visual appearance when there are many data points
    if (filteredData.length > 10 && _selectedDateRange > 0) {
      return _applySmoothingToHumidityData(filteredData);
    }
    
    return filteredData;
  }

  List<ActivityReading> _getFilteredActivityData(SensorService sensorService) {
    final now = MyConfig.malaysiaTime;
    DateTime startDate;
    
    switch (_selectedDateRange) {
      case 0: // Today
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 1: // Last 7 days
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 2: // Last 30 days
        startDate = now.subtract(const Duration(days: 30));
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }
    
    // Filter data to show only the selected time range
    return sensorService.activityHistory
        .where((reading) => reading.timestamp.isAfter(startDate) && reading.timestamp.isBefore(now.add(const Duration(days: 1))))
        .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Color _getTemperatureColor(double temperature) {
    if (temperature > 28) return Colors.red;
    if (temperature < 18) return Colors.blue;
    return Colors.green;
  }

  Color _getHumidityColor(double humidity) {
    if (humidity > 70 || humidity < 30) return Colors.orange;
    return Colors.green;
  }

  // Light data smoothing for temperature readings to improve line visual appearance
  List<TemperatureReading> _applySmoothingToTemperatureData(List<TemperatureReading> data) {
    if (data.length < 3) return data;
    
    final smoothedData = <TemperatureReading>[];
    
    // Keep first point
    smoothedData.add(data.first);
    
    // Apply simple moving average smoothing for middle points
    for (int i = 1; i < data.length - 1; i++) {
      final prevValue = data[i - 1].value;
      final currentValue = data[i].value;
      final nextValue = data[i + 1].value;
      
      // Simple 3-point moving average with light smoothing factor
      final smoothedValue = (prevValue * 0.25) + (currentValue * 0.5) + (nextValue * 0.25);
      
      smoothedData.add(TemperatureReading(
        timestamp: data[i].timestamp,
        value: smoothedValue,
      ));
    }
    
    // Keep last point
    smoothedData.add(data.last);
    
    return smoothedData;
  }

  // Light data smoothing for humidity readings to improve line visual appearance
  List<HumidityReading> _applySmoothingToHumidityData(List<HumidityReading> data) {
    if (data.length < 3) return data;
    
    final smoothedData = <HumidityReading>[];
    
    // Keep first point
    smoothedData.add(data.first);
    
    // Apply simple moving average smoothing for middle points
    for (int i = 1; i < data.length - 1; i++) {
      final prevValue = data[i - 1].value;
      final currentValue = data[i].value;
      final nextValue = data[i + 1].value;
      
      // Simple 3-point moving average with light smoothing factor
      final smoothedValue = (prevValue * 0.25) + (currentValue * 0.5) + (nextValue * 0.25);
      
      smoothedData.add(HumidityReading(
        timestamp: data[i].timestamp,
        value: smoothedValue,
      ));
    }
    
    // Keep last point
    smoothedData.add(data.last);
    
    return smoothedData;
  }
} 
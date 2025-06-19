import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/sensor_service.dart';
import '../widgets/image_background_widget.dart';
import '../config/app_config.dart';

class RelayControlPage extends StatefulWidget {
  const RelayControlPage({super.key});

  @override
  State<RelayControlPage> createState() => _RelayControlPageState();
}

class _RelayControlPageState extends State<RelayControlPage> with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _isThresholdLoading = false;
  late AnimationController _pulseController;
  late AnimationController _emergencyController;
  late AnimationController _thresholdController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _emergencyAnimation;
  late Animation<Color?> _emergencyColorAnimation;
  late Animation<double> _thresholdSlideAnimation;
  
  // Threshold control variables (High/Low for both temp and humidity)
  double _highTempThreshold = 28.0;
  double _lowTempThreshold = 18.0;
  double _highHumThreshold = 70.0;
  double _lowHumThreshold = 30.0;
  bool _showThresholdDetails = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _emergencyController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _thresholdController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _emergencyAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _emergencyController, curve: Curves.easeInOut),
    );
    
    _emergencyColorAnimation = ColorTween(
      begin: Colors.red[600],
      end: Colors.red[800],
    ).animate(CurvedAnimation(parent: _emergencyController, curve: Curves.easeInOut));
    
    _thresholdSlideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _thresholdController, curve: Curves.easeOutCubic),
    );
    
    // Initialize thresholds from sensor service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentThresholds();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _emergencyController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ImageBackgroundWidget(
        backgroundType: BackgroundType.control,
        opacity: 0.3,
        child: Consumer<SensorService>(
          builder: (context, sensorService, child) {
            final isEmergency = sensorService.relayStatus || sensorService.fallDetected;
            
            return CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, sensorService, isEmergency),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      _buildEnhancedProtectionCard(sensorService),
                      const SizedBox(height: 24),
                      _buildThresholdControlCard(sensorService),
                      const SizedBox(height: 24),
                      _buildBuzzerControlCenter(sensorService),
                      const SizedBox(height: 24),
                      _buildQuickActionsCard(sensorService),
                      const SizedBox(height: 24),
                      _buildSystemInfoCard(sensorService),
                      const SizedBox(height: 20),
                    ],
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

  Widget _buildSliverAppBar(BuildContext context, SensorService sensorService, bool isEmergency) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: isEmergency ? Colors.red[600] : const Color(0xFF8E24AA),
      flexibleSpace: FlexibleSpaceBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: isEmergency ? _pulseAnimation.value : 1.0,
                  child: Icon(
                    Icons.electrical_services_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            const Text(
              'Emergency Control',
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
              colors: isEmergency 
                ? [Colors.red[600]!, Colors.red[800]!]
                : [const Color(0xFF8E24AA), const Color(0xFF7B1FA2)],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () async {
            await sensorService.checkRelayStatus();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Status refreshed'),
                  backgroundColor: Colors.green[600],
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildFallEmergencyCard(SensorService sensorService) {
    final bool fallDetected = sensorService.fallDetected;
    final bool relayActive = sensorService.relayStatus;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: fallDetected 
            ? [Colors.red[600]!, Colors.red[800]!]
            : [const Color(0xFF8E24AA), const Color(0xFF7B1FA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (fallDetected ? Colors.red : const Color(0xFF8E24AA)).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        image: const DecorationImage(
          image: AssetImage('assets/background_card.png'),
          fit: BoxFit.cover,
          opacity: 0.4,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: fallDetected ? _emergencyAnimation : _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: fallDetected ? _emergencyAnimation.value : 1.0,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: Icon(
                        fallDetected ? FontAwesomeIcons.personFalling : FontAwesomeIcons.shieldHeart,
                        size: 40,
                        color: fallDetected ? Colors.red[600] : Colors.blue[600],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fallDetected ? '🚨 FALL EMERGENCY!' : '🛡️ FALL PROTECTION',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      fallDetected 
                        ? 'Immediate action required - check on elderly person'
                        : 'System actively monitoring for falls',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Status indicators
          Row(
            children: [
              Expanded(
                child: _buildStatusBadge(
                  'Fall Sensor',
                  fallDetected ? 'TRIGGERED' : 'MONITORING',
                  fallDetected ? Colors.red[300]! : Colors.green[300]!,
                  fallDetected ? FontAwesomeIcons.triangleExclamation : FontAwesomeIcons.eye,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatusBadge(
                  'Alert System',
                  relayActive ? 'BUZZER ON' : 'STANDBY',
                  relayActive ? Colors.orange[300]! : Colors.blue[300]!,
                  relayActive ? FontAwesomeIcons.volumeHigh : FontAwesomeIcons.volumeOff,
                ),
              ),
            ],
          ),
          
          if (fallDetected) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(FontAwesomeIcons.clock, color: Colors.white, size: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Fall detected at ${DateFormat('MMM dd, HH:mm:ss').format(DateTime.now())}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String title, String status, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuzzerControlCenter(SensorService sensorService) {
    final bool relayActive = sensorService.relayStatus;
    final bool fallDetected = sensorService.fallDetected;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: relayActive ? Colors.red.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: relayActive ? _pulseAnimation.value : 1.0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: relayActive ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        relayActive ? FontAwesomeIcons.volumeHigh : FontAwesomeIcons.volumeOff,
                        color: relayActive ? Colors.red : Colors.grey[600],
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency Buzzer Control',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      relayActive ? 'Buzzer is currently sounding alarm' : 'Buzzer is ready for activation',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Large control button
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: relayActive ? _pulseAnimation.value : 1.0,
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _toggleBuzzer(sensorService, relayActive),
                    icon: _isLoading 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(
                          relayActive ? FontAwesomeIcons.stop : FontAwesomeIcons.play,
                          size: 20,
                        ),
                    label: Text(
                      _isLoading 
                        ? 'Processing...'
                        : relayActive ? 'STOP BUZZER' : 'START BUZZER',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: relayActive ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: relayActive ? 8 : 4,
                    ),
                  ),
                ),
              );
            },
          ),
          
          if (fallDetected && relayActive) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(FontAwesomeIcons.lightbulb, color: Colors.orange[600], size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'After checking on the elderly person, tap "STOP BUZZER" to silence the alarm.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Status info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  relayActive ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.circle,
                  color: relayActive ? Colors.green : Colors.grey,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Last updated: ${DateFormat('HH:mm:ss').format(sensorService.lastUpdate)}',
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

  Future<void> _toggleBuzzer(SensorService sensorService, bool currentState) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await sensorService.toggleRelay(!currentState);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success 
                ? (currentState ? 'Buzzer turned OFF' : 'Buzzer turned ON')
                : 'Failed to control buzzer',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  Widget _buildStatusIndicator(String label, String status, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelayControlSection(SensorService sensorService) {
    final bool isRelayOn = sensorService.relayStatus;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Relay Control',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
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
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isRelayOn ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.electrical_services_rounded,
                      color: isRelayOn ? Colors.red : Colors.grey,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Emergency Buzzer',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manual relay control for emergency situations',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildControlButton(
                      label: 'Turn ON',
                      icon: Icons.power_settings_new_rounded,
                      color: Colors.red,
                      isActive: isRelayOn,
                      onPressed: isRelayOn ? null : () => _controlRelay(sensorService, true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildControlButton(
                      label: 'Turn OFF',
                      icon: Icons.power_off_rounded,
                      color: Colors.green,
                      isActive: !isRelayOn,
                      onPressed: !isRelayOn ? null : () => _controlRelay(sensorService, false),
                    ),
                  ),
                ],
              ),
              if (isRelayOn) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.red[600], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Emergency buzzer is active. Turn OFF when situation is resolved.',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isActive,
    required VoidCallback? onPressed,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : onPressed,
        icon: _isLoading && onPressed != null
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed == null ? Colors.grey[300] : color,
          foregroundColor: onPressed == null ? Colors.grey[600] : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: onPressed == null ? 0 : 2,
        ),
      ),
    );
  }

  Widget _buildFallDetectionCard(SensorService sensorService) {
    final bool fallDetected = sensorService.fallDetected;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: fallDetected 
            ? [Colors.orange[50]!, Colors.orange[100]!]
            : [Colors.blue[50]!, Colors.blue[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: fallDetected ? Border.all(color: Colors.orange, width: 2) : null,
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
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: fallDetected ? _pulseAnimation.value : 1.0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: fallDetected ? Colors.orange : Colors.blue,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: fallDetected ? [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ] : [],
                      ),
                      child: Icon(
                        FontAwesomeIcons.personFalling,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fall Detection System',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vibration sensor monitoring',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: fallDetected ? Colors.orange : Colors.blue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  fallDetected ? 'ALERT' : 'NORMAL',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Status',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  fallDetected 
                    ? 'FALL DETECTED! Emergency response required.'
                    : 'No fall detected. System monitoring normally.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: fallDetected ? Colors.orange[700] : Colors.blue[700],
                  ),
                ),
                if (fallDetected) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.orange[700], size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Detected at: ${DateFormat('HH:mm:ss').format(MyConfig.malaysiaTime)}',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(SensorService sensorService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                title: 'Emergency Stop',
                subtitle: 'Turn off all alerts',
                icon: Icons.emergency_rounded,
                color: Colors.red,
                onTap: sensorService.relayStatus 
                  ? () => _showEmergencyStopDialog(sensorService)
                  : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildQuickActionCard(
                title: 'Test Buzzer',
                subtitle: 'Test emergency sound',
                icon: Icons.volume_up_rounded,
                color: Colors.orange,
                onTap: !sensorService.relayStatus 
                  ? () => _testBuzzer(sensorService)
                  : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: onTap != null ? Colors.white : Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            boxShadow: onTap != null ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ] : [],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (onTap != null ? color : Colors.grey).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon, 
                  color: onTap != null ? color : Colors.grey, 
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: onTap != null ? Colors.black87 : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: onTap != null ? Colors.grey[600] : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemInfoCard(SensorService sensorService) {
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
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'System Information',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoItem('Last Status Check', 
            DateFormat('MMM dd, HH:mm:ss').format(sensorService.lastUpdate)),
          const SizedBox(height: 12),
          _buildInfoItem('Connection Status', 'Connected via WiFi'),
          const SizedBox(height: 12),
          _buildInfoItem('Relay Type', 'Emergency Buzzer Control'),
          const SizedBox(height: 12),
          _buildInfoItem('Control Mode', 'Manual App Control'),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Important Notes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Relay stays ON until manually turned OFF via app\n'
                  '• Fall detection automatically activates the relay\n'
                  '• Use Emergency Stop for immediate shutdown',
                  style: TextStyle(
                    color: Colors.blue[600],
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Text(': ', style: TextStyle(color: Colors.grey)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _controlRelay(SensorService sensorService, bool turnOn) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await sensorService.toggleRelay(turnOn);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(turnOn ? 'Emergency buzzer activated' : 'Emergency buzzer deactivated'),
            backgroundColor: turnOn ? Colors.red[600] : Colors.green[600],
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to control relay. Please try again.'),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showEmergencyStopDialog(SensorService sensorService) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.emergency, color: Colors.red[600]),
              const SizedBox(width: 12),
              const Text('Emergency Stop'),
            ],
          ),
          content: const Text(
            'Are you sure you want to turn off the emergency buzzer?\n\n'
            'Only do this if the emergency situation has been resolved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _controlRelay(sensorService, false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Turn OFF'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _testBuzzer(SensorService sensorService) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Turn on for 3 seconds, then turn off
      final turnOnSuccess = await sensorService.toggleRelay(true);
      if (turnOnSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Testing buzzer for 3 seconds...'),
            duration: Duration(seconds: 3),
          ),
        );
        
        await Future.delayed(const Duration(seconds: 3));
        final turnOffSuccess = await sensorService.toggleRelay(false);
        
        if (turnOffSuccess && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Buzzer test completed'),
              backgroundColor: Colors.green[600],
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else if (!turnOnSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to start buzzer test'),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test failed: ${e.toString()}'),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Load current thresholds from database
  Future<void> _loadCurrentThresholds() async {
    try {
      final response = await http.get(Uri.parse('${MyConfig.server}get_thresholds.php'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data != null && !data.containsKey('error')) {
          setState(() {
            _highTempThreshold = double.tryParse(data['high_temp_threshold']?.toString() ?? '28.0') ?? 28.0;
            _lowTempThreshold = double.tryParse(data['low_temp_threshold']?.toString() ?? '18.0') ?? 18.0;
            _highHumThreshold = double.tryParse(data['high_hum_threshold']?.toString() ?? '70.0') ?? 70.0;
            _lowHumThreshold = double.tryParse(data['low_hum_threshold']?.toString() ?? '30.0') ?? 30.0;
          });
          print('Thresholds loaded from database successfully');
        } else {
          // Use default values if database has error
          _setDefaultThresholds();
          print('Using default thresholds due to database error');
        }
      } else {
        _setDefaultThresholds();
        print('HTTP error loading thresholds: ${response.statusCode}');
      }
    } catch (e) {
      _setDefaultThresholds();
      print('Error loading thresholds: $e');
    }
  }
  
  void _setDefaultThresholds() {
    setState(() {
      _highTempThreshold = 28.0;
      _lowTempThreshold = 18.0;
      _highHumThreshold = 70.0;
      _lowHumThreshold = 30.0;
    });
  }

  // Build enhanced protection card with environmental monitoring
  Widget _buildEnhancedProtectionCard(SensorService sensorService) {
    final bool fallDetected = sensorService.fallDetected;
    final bool tempHighAlert = sensorService.temperature > _highTempThreshold;
    final bool tempLowAlert = sensorService.temperature < _lowTempThreshold;
    final bool humHighAlert = sensorService.humidity > _highHumThreshold;
    final bool humLowAlert = sensorService.humidity < _lowHumThreshold;
    final bool tempAlert = tempHighAlert || tempLowAlert;
    final bool humAlert = humHighAlert || humLowAlert;
    final bool anyAlert = fallDetected || tempAlert || humAlert;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: anyAlert 
            ? [Colors.red[600]!, Colors.red[800]!]
            : [const Color(0xFF8E24AA), const Color(0xFF7B1FA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (anyAlert ? Colors.red : const Color(0xFF8E24AA)).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        image: const DecorationImage(
          image: AssetImage('assets/background_card.png'),
          fit: BoxFit.cover,
          opacity: 0.4,
        ),
      ),
      child: Column(
        children: [
          // Header section
          Row(
            children: [
              AnimatedBuilder(
                animation: anyAlert ? _emergencyAnimation : _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: anyAlert ? _emergencyAnimation.value : 1.0,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: Icon(
                        anyAlert ? FontAwesomeIcons.triangleExclamation : FontAwesomeIcons.shieldHeart,
                        size: 40,
                        color: anyAlert ? Colors.red[600] : Colors.blue[600],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      anyAlert ? '🚨 ALERT DETECTED!' : '🛡️ PROTECTION ACTIVE',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      anyAlert 
                        ? 'Check system status and elderly safety'
                        : 'Monitoring falls and environmental conditions',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Status indicators in a grid
          Row(
            children: [
              Expanded(
                child: _buildStatusBadge(
                  'Fall Detection',
                  fallDetected ? 'ALERT' : 'NORMAL',
                  fallDetected ? Colors.red[300]! : Colors.green[300]!,
                  fallDetected ? FontAwesomeIcons.personFalling : FontAwesomeIcons.eye,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatusBadge(
                  'Temperature',
                  tempAlert ? 'HIGH' : 'OK',
                  tempAlert ? Colors.orange[300]! : Colors.green[300]!,
                  FontAwesomeIcons.temperatureHalf,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatusBadge(
                  'Humidity',
                  humAlert ? 'HIGH' : 'OK',
                  humAlert ? Colors.blue[300]! : Colors.green[300]!,
                  FontAwesomeIcons.droplet,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Current readings section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Icon(FontAwesomeIcons.temperatureHalf, color: Colors.white, size: 18),
                      const SizedBox(height: 8),
                      Text(
                        '${sensorService.temperature.toStringAsFixed(1)}°C',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Range: ${_lowTempThreshold.toStringAsFixed(1)}-${_highTempThreshold.toStringAsFixed(1)}°C',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: Colors.white.withOpacity(0.3),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Icon(FontAwesomeIcons.droplet, color: Colors.white, size: 18),
                      const SizedBox(height: 8),
                      Text(
                        '${sensorService.humidity.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Range: ${_lowHumThreshold.toStringAsFixed(0)}-${_highHumThreshold.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: Colors.white.withOpacity(0.3),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Icon(
                        sensorService.relayStatus ? FontAwesomeIcons.volumeHigh : FontAwesomeIcons.volumeOff,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        sensorService.relayStatus ? 'ON' : 'OFF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Buzzer',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build the animated threshold control card
  Widget _buildThresholdControlCard(SensorService sensorService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple[400]!, Colors.purple[600]!],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                FontAwesomeIcons.sliders,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚙️ Environmental Thresholds',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[700],
                    ),
                  ),
                  Text(
                    'Adjust comfort limits for alerts',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header with toggle
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _showThresholdDetails = !_showThresholdDetails;
                    });
                    if (_showThresholdDetails) {
                      _thresholdController.forward();
                    } else {
                      _thresholdController.reverse();
                    }
                  },
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue[400]!, Colors.blue[600]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            FontAwesomeIcons.temperatureHalf,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Comfort Thresholds',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Temp: ${_lowTempThreshold.toStringAsFixed(1)}-${_highTempThreshold.toStringAsFixed(1)}°C | Hum: ${_lowHumThreshold.toStringAsFixed(0)}-${_highHumThreshold.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedRotation(
                          turns: _showThresholdDetails ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.grey[600],
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Expandable content
              AnimatedBuilder(
                animation: _thresholdSlideAnimation,
                builder: (context, child) {
                  return ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: _thresholdSlideAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    children: [
                      Container(
                        height: 1,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.grey[300]!, Colors.transparent],
                          ),
                        ),
                      ),
                      
                      // High Temperature threshold control
                      _buildThresholdSlider(
                        title: 'High Temperature Threshold',
                        icon: FontAwesomeIcons.thermometerHalf,
                        value: _highTempThreshold,
                        min: 15.0,
                        max: 40.0,
                        unit: '°C',
                        color: Colors.red,
                        onChanged: (value) {
                          setState(() {
                            // Ensure high threshold is always above low threshold
                            if (value > _lowTempThreshold) {
                              _highTempThreshold = value;
                            }
                          });
                        },
                        onChangeEnd: (value) {
                          _updateHighTemperatureThreshold(value);
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Low Temperature threshold control
                      _buildThresholdSlider(
                        title: 'Low Temperature Threshold',
                        icon: FontAwesomeIcons.thermometerEmpty,
                        value: _lowTempThreshold,
                        min: 5.0,
                        max: 35.0,
                        unit: '°C',
                        color: Colors.blue,
                        onChanged: (value) {
                          setState(() {
                            // Ensure low threshold is always below high threshold
                            if (value < _highTempThreshold) {
                              _lowTempThreshold = value;
                            }
                          });
                        },
                        onChangeEnd: (value) {
                          _updateLowTemperatureThreshold(value);
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // High Humidity threshold control
                      _buildThresholdSlider(
                        title: 'High Humidity Threshold',
                        icon: FontAwesomeIcons.droplet,
                        value: _highHumThreshold,
                        min: 40.0,
                        max: 95.0,
                        unit: '%',
                        color: Colors.purple,
                        onChanged: (value) {
                          setState(() {
                            // Ensure high threshold is always above low threshold
                            if (value > _lowHumThreshold) {
                              _highHumThreshold = value;
                            }
                          });
                        },
                        onChangeEnd: (value) {
                          _updateHighHumidityThreshold(value);
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Low Humidity threshold control
                      _buildThresholdSlider(
                        title: 'Low Humidity Threshold',
                        icon: FontAwesomeIcons.dropletSlash,
                        value: _lowHumThreshold,
                        min: 10.0,
                        max: 80.0,
                        unit: '%',
                        color: Colors.green,
                        onChanged: (value) {
                          setState(() {
                            // Ensure low threshold is always below high threshold
                            if (value < _highHumThreshold) {
                              _lowHumThreshold = value;
                            }
                          });
                        },
                        onChangeEnd: (value) {
                          _updateLowHumidityThreshold(value);
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Update button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isThresholdLoading ? null : _updateAllThresholds,
                          icon: _isThresholdLoading 
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(FontAwesomeIcons.cloudArrowUp, size: 18),
                          label: Text(
                            _isThresholdLoading ? 'Updating...' : 'Update Thresholds',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8E24AA),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Info container
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(FontAwesomeIcons.lightbulb, color: Colors.blue[600], size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Threshold Information',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• High/Low alerts trigger when readings exceed ranges\n'
                              '• Changes are saved to database automatically\n'
                              '• Arduino system updates every 30 seconds\n'
                              '• Separate high and low alerts for each parameter',
                              style: TextStyle(
                                color: Colors.blue[600],
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Build threshold slider widget
  Widget _buildThresholdSlider({
    required String title,
    required IconData icon,
    required double value,
    required double min,
    required double max,
    required String unit,
    required Color color,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
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
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      'Current: ${value.toStringAsFixed(1)}$unit',
                      style: TextStyle(
                        fontSize: 14,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${value.toStringAsFixed(1)}$unit',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.3),
              thumbColor: color,
              overlayColor: color.withOpacity(0.2),
              valueIndicatorColor: color,
              trackHeight: 6.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: ((max - min) * 2).round(),
              label: '${value.toStringAsFixed(1)}$unit',
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${min.toStringAsFixed(0)}$unit',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '${max.toStringAsFixed(0)}$unit',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Update high temperature threshold
  Future<void> _updateHighTemperatureThreshold(double value) async {
    // Add debouncing to avoid too many API calls
    await Future.delayed(const Duration(milliseconds: 500));
    print('High temperature threshold updated to: ${value.toStringAsFixed(1)}°C');
  }

  // Update low temperature threshold
  Future<void> _updateLowTemperatureThreshold(double value) async {
    // Add debouncing to avoid too many API calls
    await Future.delayed(const Duration(milliseconds: 500));
    print('Low temperature threshold updated to: ${value.toStringAsFixed(1)}°C');
  }

  // Update high humidity threshold
  Future<void> _updateHighHumidityThreshold(double value) async {
    // Add debouncing to avoid too many API calls
    await Future.delayed(const Duration(milliseconds: 500));
    print('High humidity threshold updated to: ${value.toStringAsFixed(1)}%');
  }

  // Update low humidity threshold
  Future<void> _updateLowHumidityThreshold(double value) async {
    // Add debouncing to avoid too many API calls
    await Future.delayed(const Duration(milliseconds: 500));
    print('Low humidity threshold updated to: ${value.toStringAsFixed(1)}%');
  }

  // Update all thresholds to database (updates threshold_id = 1)
  Future<void> _updateAllThresholds() async {
    setState(() {
      _isThresholdLoading = true;
    });

    try {
      // Validate thresholds before sending
      if (_highTempThreshold <= _lowTempThreshold) {
        throw Exception('High temperature must be greater than low temperature');
      }
      
      if (_highHumThreshold <= _lowHumThreshold) {
        throw Exception('High humidity must be greater than low humidity');
      }

      // Call backend to update threshold_id = 1 with all 4 threshold values
      final response = await http.get(Uri.parse(
        '${MyConfig.server}threshold_update.php?'
        'high_temp_threshold=${_highTempThreshold.toStringAsFixed(1)}&'
        'low_temp_threshold=${_lowTempThreshold.toStringAsFixed(1)}&'
        'high_hum_threshold=${_highHumThreshold.toStringAsFixed(0)}&'
        'low_hum_threshold=${_lowHumThreshold.toStringAsFixed(0)}'
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '✅ Thresholds Updated Successfully!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('Temperature: ${_lowTempThreshold.toStringAsFixed(1)}°C - ${_highTempThreshold.toStringAsFixed(1)}°C'),
                    Text('Humidity: ${_lowHumThreshold.toStringAsFixed(0)}% - ${_highHumThreshold.toStringAsFixed(0)}%'),
                    const SizedBox(height: 4),
                    const Text(
                      'Arduino will fetch new thresholds within 30 seconds',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
                backgroundColor: Colors.green[600],
                duration: const Duration(seconds: 5),
              ),
            );
          }
        } else {
          throw Exception(data['message'] ?? 'Update failed');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: Failed to connect to server');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '❌ Update Failed',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(e.toString()),
              ],
            ),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isThresholdLoading = false;
        });
      }
    }
  }
} 
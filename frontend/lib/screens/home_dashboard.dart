import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sensor_service.dart';
import '../widgets/image_background_widget.dart';
import 'relay_control_page.dart';
import 'graphs_trends_page.dart';
import 'login_page.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _emergencyController;
  late AnimationController _rippleController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _emergencyPulse;
  late Animation<double> _rippleAnimation;
  
  String currentUsername = '';
  String loginTime = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
    _slideController.forward();
  }
  
  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _emergencyController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _emergencyPulse = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _emergencyController, curve: Curves.easeInOut),
    );
    
    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
  }

  Future<void> _loadUserData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        currentUsername = prefs.getString('username') ?? 'User';
        loginTime = prefs.getString('loginTime') ?? '';
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        currentUsername = 'User';
        loginTime = '';
        isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      try {
        // Clear user session data
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', false);
        await prefs.remove('username');
        await prefs.remove('loginTime');
        
        // Navigate to login page
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (Route<dynamic> route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error during logout. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatLoginTime(String loginTimeString) {
    try {
      final loginDateTime = DateTime.parse(loginTimeString);
      final now = DateTime.now();
      final difference = now.difference(loginDateTime);
      
      if (difference.inDays > 0) {
        return 'Logged in ${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return 'Logged in ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return 'Logged in ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just logged in';
      }
    } catch (e) {
      return 'Login time: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}';
    }
  }

  void _showUserProfile() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person, color: Colors.blue[600]),
              ),
              const SizedBox(width: 12),
              const Text('User Profile'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileRow('Username', currentUsername),
              const SizedBox(height: 12),
              _buildProfileRow('Login Time', loginTime.isNotEmpty 
                ? DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(loginTime))
                : 'Not available'),
              const SizedBox(height: 12),
              _buildProfileRow('Session Duration', _formatLoginTime(loginTime)),
              const SizedBox(height: 12),
              _buildProfileRow('Status', 'Active'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _emergencyController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Consumer<SensorService>(
        builder: (context, sensorService, child) {
          final bool relayActive = sensorService.relayStatus;
          final bool fallDetected = sensorService.fallDetected;
          
          if (!relayActive && !fallDetected) return const SizedBox.shrink();
          
          return AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: FloatingActionButton.extended(
                  onPressed: relayActive ? () async {
                    final success = await sensorService.toggleRelay(false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? 'Buzzer turned OFF' : 'Failed to turn OFF buzzer'),
                          backgroundColor: success ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  } : null,
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  icon: const Icon(FontAwesomeIcons.volumeHigh),
                  label: const Text(
                    'STOP BUZZER',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          );
        },
      ),
      body: ImageBackgroundWidget(
        backgroundType: BackgroundType.home,
        opacity: 0.3,
        child: Consumer<SensorService>(
          builder: (context, sensorService, child) {
            return CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, sensorService),
              SliverToBoxAdapter(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        _buildFallDetectionCenter(sensorService),
                        const SizedBox(height: 24),
                        _buildQuickRelayControl(sensorService),
                        const SizedBox(height: 24),
                        _buildFallRiskDetailsCard(sensorService),
                        const SizedBox(height: 24),
                        _buildQuickStatsRow(sensorService),
                        const SizedBox(height: 24),
                        _buildSensorGrid(context, sensorService),
                        const SizedBox(height: 24),
                        _buildActionCards(context, sensorService),
                        const SizedBox(height: 20),
                      ],
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
    final isEmergency = sensorService.fallDetected || sensorService.relayStatus;
    
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      backgroundColor: isEmergency ? Colors.red[600] : const Color(0xFF6A1B9A),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isEmergency 
                ? [Colors.red[600]!, Colors.red[800]!, Colors.red[900]!]
                : [
                    const Color(0xFF9C27B0), // Vibrant purple
                    const Color(0xFF7B1FA2), // Medium purple
                    const Color(0xFF4A148C), // Deep purple
                  ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
                      child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
              child: isLoading 
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // App Title Section
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.25),
                                  Colors.white.withOpacity(0.15),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.health_and_safety,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CareCompanion',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'Elderly Health Monitor',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Welcome Section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.person_outline,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Welcome back, $currentUsername!',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (loginTime.isNotEmpty)
                                    Text(
                                      _formatLoginTime(loginTime),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Colors.greenAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Online',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
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
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () async {
            await sensorService.fetchSensorData();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data refreshed'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (String value) {
            if (value == 'logout') {
              _logout();
            } else if (value == 'profile') {
              _showUserProfile();
            }
          },
          itemBuilder: (BuildContext context) => [
            PopupMenuItem<String>(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person_outline, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  const Text('User Profile'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.red[600]),
                  const SizedBox(width: 8),
                  Text('Logout', style: TextStyle(color: Colors.red[600])),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFallDetectionCenter(SensorService sensorService) {
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
            color: (fallDetected ? Colors.red : Colors.blue).withOpacity(0.4),
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
          // Animated Fall Detection Icon with Ripple Effect
          Stack(
            alignment: Alignment.center,
            children: [
              // Ripple effect for fall detection
              if (fallDetected) ...[
                AnimatedBuilder(
                  animation: _rippleAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 120 + (_rippleAnimation.value * 40),
                      height: 120 + (_rippleAnimation.value * 40),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(1 - _rippleAnimation.value),
                          width: 3,
                        ),
                      ),
                    );
                  },
                ),
                AnimatedBuilder(
                  animation: _rippleAnimation,
                  builder: (context, child) {
                    final delayedValue = (_rippleAnimation.value - 0.3).clamp(0.0, 1.0);
                    return Container(
                      width: 120 + (delayedValue * 60),
                      height: 120 + (delayedValue * 60),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(1 - delayedValue),
                          width: 2,
                        ),
                      ),
                    );
                  },
                ),
              ],
              // Main icon
              AnimatedBuilder(
                animation: fallDetected ? _emergencyPulse : _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: fallDetected ? _emergencyPulse.value : _pulseAnimation.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        fallDetected ? FontAwesomeIcons.personFalling : FontAwesomeIcons.shieldHeart,
                        size: 50,
                        color: fallDetected ? Colors.red[600] : const Color(0xFF8E24AA),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Status Text
          Text(
            fallDetected ? '🚨 FALL DETECTED!' : '🛡️ FALL PROTECTION ACTIVE',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          
          Text(
            fallDetected 
              ? 'Emergency alert activated! Check on elderly person immediately.'
              : 'Monitoring for falls 24/7. Your loved one is protected.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          
          // Status indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatusIndicator(
                'Vibration Sensor',
                fallDetected ? 'TRIGGERED' : 'MONITORING',
                fallDetected ? Colors.red[300]! : Colors.green[300]!,
                fallDetected ? FontAwesomeIcons.triangleExclamation : FontAwesomeIcons.eye,
              ),
              _buildStatusIndicator(
                'Alert System',
                relayActive ? 'BUZZER ON' : 'STANDBY',
                relayActive ? Colors.orange[300]! : Colors.blue[300]!,
                relayActive ? FontAwesomeIcons.volumeHigh : FontAwesomeIcons.volumeOff,
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Last update
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Last Update: ${DateFormat('MMM dd, HH:mm:ss').format(sensorService.lastUpdate)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String title, String status, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
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
    );
  }

  Widget _buildQuickRelayControl(SensorService sensorService) {
    final bool relayActive = sensorService.relayStatus;
    final bool fallDetected = sensorService.fallDetected;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: relayActive ? Colors.red.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
          width: 2,
        ),
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
                  color: relayActive ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  relayActive ? FontAwesomeIcons.volumeHigh : FontAwesomeIcons.volumeOff,
                  color: relayActive ? Colors.red : Colors.grey[600],
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency Buzzer',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      relayActive ? 'Currently sounding alarm' : 'Ready for activation',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: relayActive ? _pulseAnimation.value : 1.0,
                    child: ElevatedButton.icon(
                      onPressed: relayActive ? () async {
                        final success = await sensorService.toggleRelay(false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success ? 'Buzzer turned OFF' : 'Failed to turn OFF buzzer'),
                              backgroundColor: success ? Colors.green : Colors.red,
                            ),
                          );
                        }
                      } : null,
                      icon: Icon(
                        relayActive ? FontAwesomeIcons.stop : FontAwesomeIcons.play,
                        size: 16,
                      ),
                      label: Text(relayActive ? 'STOP BUZZER' : 'BUZZER OFF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: relayActive ? Colors.red : Colors.grey[300],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          if (fallDetected && relayActive) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(FontAwesomeIcons.lightbulb, color: Colors.orange[600], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap "STOP BUZZER" to silence the alarm after checking on the elderly person.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
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

  Widget _buildFallRiskDetailsCard(SensorService sensorService) {
    final riskLevel = sensorService.fallRiskLevel;
    final riskColor = sensorService.getFallRiskColor();
    final riskIcon = sensorService.getFallRiskIcon();
    final riskDescription = sensorService.getFallRiskDescription();
    final isHighRisk = riskLevel == 'HIGH_RISK' || riskLevel == 'CRITICAL';
    final isActive = sensorService.motionDetected;
    final duration = sensorService.motionDuration;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighRisk ? riskColor.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
          width: 2,
        ),
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
          // Header
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: isHighRisk ? _pulseAnimation.value : 1.0,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: riskColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        riskIcon,
                        color: riskColor,
                        size: 28,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fall Risk Assessment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      'Real-time mobility monitoring for elderly safety',
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
          const SizedBox(height: 20),
          
          // Risk Level Display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: riskColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Current Risk Level: ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      riskLevel.replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: riskColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  riskDescription,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Motion Information
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green[50] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isActive ? Colors.green[200]! : Colors.grey[200]!,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isActive ? FontAwesomeIcons.personWalking : FontAwesomeIcons.personWalkingWithCane,
                        color: isActive ? Colors.green[600] : Colors.grey[600],
                        size: 20,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Motion Status',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.green[600] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: duration > 0 ? Colors.blue[50] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: duration > 0 ? Colors.blue[200]! : Colors.grey[200]!,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        FontAwesomeIcons.clock,
                        color: duration > 0 ? Colors.blue[600] : Colors.grey[600],
                        size: 20,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Duration',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        duration > 0 ? '${duration}s' : 'N/A',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: duration > 0 ? Colors.blue[600] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // High Risk Warning
          if (isHighRisk) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    FontAwesomeIcons.triangleExclamation,
                    color: Colors.red[600],
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      riskLevel == 'CRITICAL' 
                        ? 'CRITICAL: Elderly person may need immediate assistance. Please check on them now!'
                        : 'HIGH RISK: Unusual movement patterns detected. Consider checking on the elderly person.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[700],
                        height: 1.3,
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

  Widget _buildQuickStatsRow(SensorService sensorService) {
    return Row(
      children: [
        Expanded(
          child: _buildTemperatureIndicator(sensorService),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildHumidityIndicator(sensorService),
        ),
      ],
    );
  }



  Widget _buildSensorGrid(BuildContext context, SensorService sensorService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sensor Status',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: [
            _buildModernSensorCard(
              title: 'Fall Detection',
              value: sensorService.fallDetected ? 'ALERT!' : 'Normal',
              icon: FontAwesomeIcons.personFalling,
              color: sensorService.fallDetected ? Colors.red : Colors.green,
              isAlert: sensorService.fallDetected,
              gradient: sensorService.fallDetected 
                ? [Colors.red[50]!, Colors.red[100]!]
                : [Colors.green[50]!, Colors.green[100]!],
            ),
            _buildFallRiskCard(sensorService),
            _buildModernSensorCard(
              title: 'Emergency Relay',
              value: sensorService.relayStatus ? 'ACTIVE' : 'Standby',
              icon: Icons.electrical_services_rounded,
              color: sensorService.relayStatus ? Colors.red : Colors.grey,
              isAlert: sensorService.relayStatus,
              gradient: sensorService.relayStatus 
                ? [Colors.red[50]!, Colors.red[100]!]
                : [Colors.grey[50]!, Colors.grey[100]!],
            ),
            _buildModernSensorCard(
              title: 'System Health',
              value: 'Online',
              icon: Icons.health_and_safety_rounded,
              color: Colors.blue,
              isAlert: false,
              gradient: [Colors.blue[50]!, Colors.blue[100]!],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFallRiskCard(SensorService sensorService) {
    final riskLevel = sensorService.fallRiskLevel;
    final riskColor = sensorService.getFallRiskColor();
    final riskIcon = sensorService.getFallRiskIcon();
    final riskDescription = sensorService.getFallRiskDescription();
    final isHighRisk = riskLevel == 'HIGH_RISK' || riskLevel == 'CRITICAL';
    final isActive = sensorService.motionDetected;
    final duration = sensorService.motionDuration;
    
    String motionInfo;
    if (isActive) {
      motionInfo = 'Active Motion';
    } else if (duration > 0) {
      motionInfo = 'Last: ${duration}s';
    } else {
      motionInfo = 'No Motion';
    }
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            riskColor.withOpacity(0.1),
            riskColor.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: isHighRisk ? Border.all(color: riskColor, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: isHighRisk ? _pulseAnimation.value : 1.0,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: riskColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: riskColor.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: isHighRisk ? 2 : 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      riskIcon,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Fall Risk',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              riskLevel.replaceAll('_', ' '),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: riskColor,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              motionInfo,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
                height: 1.1,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSensorCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isAlert,
    required List<Color> gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: isAlert ? Border.all(color: color, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: isAlert ? _pulseAnimation.value : 1.0,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: isAlert ? 2 : 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: isAlert && value.length > 8 ? 12 : 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCards(BuildContext context, SensorService sensorService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.flash_on_rounded,
              color: const Color(0xFF8E24AA),
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        _buildActionCard(
          title: 'Smart Control',
          subtitle: 'Manage emergency alerts & devices',
          icon: FontAwesomeIcons.microchip,
          color: const Color(0xFF8E24AA),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RelayControlPage()),
          ),
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          title: 'Health Analytics',
          subtitle: 'Comprehensive health insights & trends',
          icon: FontAwesomeIcons.chartLine,
          color: const Color(0xFF7B1FA2),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GraphsTrendsPage()),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 94,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
                          children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.1), color.withOpacity(0.2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                ),
                              ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: color,
                    size: 14,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemperatureIndicator(SensorService sensorService) {
    final temp = sensorService.temperature;
    final minTemp = 0.0;
    final maxTemp = 50.0;
    final normalizedTemp = ((temp - minTemp) / (maxTemp - minTemp)).clamp(0.0, 1.0);
    final color = _getTemperatureColor(temp);
    
    return Container(
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Temperature',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(Icons.thermostat_rounded, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: normalizedTemp,
                  strokeWidth: 8,
                  backgroundColor: color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${temp.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    '°C',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getTemperatureStatus(temp),
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHumidityIndicator(SensorService sensorService) {
    final humidity = sensorService.humidity;
    final normalizedHumidity = (humidity / 100.0).clamp(0.0, 1.0);
    final color = _getHumidityColor(humidity);
    
    return Container(
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Humidity',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(Icons.water_drop_rounded, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: normalizedHumidity,
                  strokeWidth: 8,
                  backgroundColor: color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${humidity.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    '%',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getHumidityStatus(humidity),
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTemperatureStatus(double temperature) {
    if (temperature > 28) return 'TOO HOT';
    if (temperature < 18) return 'TOO COLD';
    return 'OPTIMAL';
  }

  String _getHumidityStatus(double humidity) {
    if (humidity > 70) return 'TOO HIGH';
    if (humidity < 30) return 'TOO LOW';
    return 'OPTIMAL';
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
}

 
import 'package:flutter/material.dart';

enum BackgroundType {
  home,
  sensors,
  control,
  analytics,
  splash,
}

class ImageBackgroundWidget extends StatefulWidget {
  final Widget child;
  final BackgroundType backgroundType;
  final double opacity;

  const ImageBackgroundWidget({
    super.key,
    required this.child,
    required this.backgroundType,
    this.opacity = 0.1,
  });

  @override
  State<ImageBackgroundWidget> createState() => _ImageBackgroundWidgetState();
}

class _ImageBackgroundWidgetState extends State<ImageBackgroundWidget>
    with TickerProviderStateMixin {
  late AnimationController _gradientController;
  late AnimationController _floatController;
  late Animation<double> _gradientAnimation;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    
    _gradientController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );
    
    _floatController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    );
    
    _gradientAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _gradientController,
      curve: Curves.easeInOut,
    ));
    
    _floatAnimation = Tween<double>(
      begin: -0.02,
      end: 0.02,
    ).animate(CurvedAnimation(
      parent: _floatController,
      curve: Curves.easeInOut,
    ));
    
    _gradientController.repeat(reverse: true);
    _floatController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _gradientController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_gradientAnimation, _floatAnimation]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value * 10),
          child: Stack(
            children: [
              // Background image
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: _getGradientForType(widget.backgroundType),
                  ),
                  child: Opacity(
                    opacity: widget.opacity,
                    child: CustomPaint(
                      painter: _getBackgroundPainter(widget.backgroundType, context),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
              // Content
              widget.child,
            ],
          ),
        );
      },
    );
  }

  LinearGradient _getGradientForType(BackgroundType type) {
    switch (type) {
      case BackgroundType.home:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE1F5FE).withOpacity(0.8),
            const Color(0xFFE8F5E8).withOpacity(0.8),
            const Color(0xFFF3E5F5).withOpacity(0.6),
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case BackgroundType.sensors:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE8F5E8).withOpacity(0.8),
            const Color(0xFFE0F2F1).withOpacity(0.8),
            const Color(0xFFE1F5FE).withOpacity(0.6),
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case BackgroundType.control:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFF3E0).withOpacity(0.8),
            const Color(0xFFFFE0B2).withOpacity(0.7),
            const Color(0xFFFFCDD2).withOpacity(0.6),
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case BackgroundType.analytics:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF3E5F5).withOpacity(0.8),
            const Color(0xFFE8EAF6).withOpacity(0.8),
            const Color(0xFFE1F5FE).withOpacity(0.6),
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case BackgroundType.splash:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE1F5FE).withOpacity(0.9),
            const Color(0xFFF3E5F5).withOpacity(0.8),
            const Color(0xFFFFE0B2).withOpacity(0.7),
          ],
          stops: const [0.0, 0.5, 1.0],
        );
    }
  }

  CustomPainter _getBackgroundPainter(BackgroundType type, BuildContext context) {
    switch (type) {
      case BackgroundType.home:
        return HomeBackgroundPainter(color: const Color(0xFF4FC3F7));
      case BackgroundType.sensors:
        return SensorsBackgroundPainter(color: const Color(0xFF81C784));
      case BackgroundType.control:
        return ControlBackgroundPainter(color: const Color(0xFFFF7043));
      case BackgroundType.analytics:
        return AnalyticsBackgroundPainter(color: const Color(0xFFFFB74D));
      case BackgroundType.splash:
        return SplashBackgroundPainter(color: const Color(0xFF4FC3F7));
    }
  }
}

// Home Dashboard Background - Hearts and Home symbols
class HomeBackgroundPainter extends CustomPainter {
  final Color color;

  HomeBackgroundPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    const double spacing = 100.0;
    const double iconSize = 30.0;

    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing) {
        final center = Offset(x, y);
        final patternIndex = ((x / spacing).floor() + (y / spacing).floor()) % 3;
        
        switch (patternIndex) {
          case 0:
            _drawHeart(canvas, center, iconSize * 0.8, paint);
            break;
          case 1:
            _drawHome(canvas, center, iconSize * 0.7, paint);
            break;
          case 2:
            _drawFamily(canvas, center, iconSize * 0.6, paint);
            break;
        }
      }
    }
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    path.moveTo(center.dx, center.dy + size * 0.3);
    path.cubicTo(
      center.dx - size * 0.5, center.dy - size * 0.2,
      center.dx - size * 0.5, center.dy + size * 0.1,
      center.dx, center.dy + size * 0.5,
    );
    path.cubicTo(
      center.dx + size * 0.5, center.dy + size * 0.1,
      center.dx + size * 0.5, center.dy - size * 0.2,
      center.dx, center.dy + size * 0.3,
    );
    canvas.drawPath(path, paint);
  }

  void _drawHome(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    // House shape
    path.moveTo(center.dx, center.dy - size * 0.5);
    path.lineTo(center.dx - size * 0.6, center.dy);
    path.lineTo(center.dx - size * 0.6, center.dy + size * 0.5);
    path.lineTo(center.dx + size * 0.6, center.dy + size * 0.5);
    path.lineTo(center.dx + size * 0.6, center.dy);
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawFamily(Canvas canvas, Offset center, double size, Paint paint) {
    // Simple family representation with circles
    canvas.drawCircle(Offset(center.dx - size * 0.3, center.dy), size * 0.2, paint);
    canvas.drawCircle(Offset(center.dx + size * 0.3, center.dy), size * 0.2, paint);
    canvas.drawCircle(Offset(center.dx, center.dy + size * 0.4), size * 0.15, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Sensors Background - Monitoring and sensor symbols
class SensorsBackgroundPainter extends CustomPainter {
  final Color color;

  SensorsBackgroundPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color.withOpacity(0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const double spacing = 90.0;
    const double iconSize = 25.0;

    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing) {
        final center = Offset(x, y);
        final patternIndex = ((x / spacing).floor() + (y / spacing).floor()) % 4;
        
        switch (patternIndex) {
          case 0:
            _drawSensor(canvas, center, iconSize, strokePaint);
            break;
          case 1:
            _drawWaveform(canvas, center, iconSize, strokePaint);
            break;
          case 2:
            _drawThermometer(canvas, center, iconSize, paint);
            break;
          case 3:
            _drawSignal(canvas, center, iconSize, strokePaint);
            break;
        }
      }
    }
  }

  void _drawSensor(Canvas canvas, Offset center, double size, Paint paint) {
    canvas.drawCircle(center, size * 0.8, paint);
    canvas.drawCircle(center, size * 0.4, Paint()..color = paint.color..style = PaintingStyle.fill);
  }

  void _drawWaveform(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    path.moveTo(center.dx - size, center.dy);
    path.lineTo(center.dx - size * 0.5, center.dy - size * 0.5);
    path.lineTo(center.dx, center.dy + size * 0.5);
    path.lineTo(center.dx + size * 0.5, center.dy - size * 0.3);
    path.lineTo(center.dx + size, center.dy);
    canvas.drawPath(path, paint);
  }

  void _drawThermometer(Canvas canvas, Offset center, double size, Paint paint) {
    final rect = Rect.fromCenter(center: center, width: size * 0.3, height: size * 1.2);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(size * 0.15)), paint);
    canvas.drawCircle(Offset(center.dx, center.dy + size * 0.4), size * 0.2, paint);
  }

  void _drawSignal(Canvas canvas, Offset center, double size, Paint paint) {
    for (int i = 0; i < 3; i++) {
      final radius = size * (0.3 + i * 0.2);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Control Background - Emergency and control symbols
class ControlBackgroundPainter extends CustomPainter {
  final Color color;

  ControlBackgroundPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color.withOpacity(0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const double spacing = 95.0;
    const double iconSize = 28.0;

    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing) {
        final center = Offset(x, y);
        final patternIndex = ((x / spacing).floor() + (y / spacing).floor()) % 4;
        
        switch (patternIndex) {
          case 0:
            _drawWarning(canvas, center, iconSize, strokePaint);
            break;
          case 1:
            _drawBuzzer(canvas, center, iconSize, paint);
            break;
          case 2:
            _drawSwitch(canvas, center, iconSize, strokePaint);
            break;
          case 3:
            _drawEmergency(canvas, center, iconSize, paint);
            break;
        }
      }
    }
  }

  void _drawWarning(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    path.moveTo(center.dx, center.dy - size * 0.6);
    path.lineTo(center.dx - size * 0.5, center.dy + size * 0.4);
    path.lineTo(center.dx + size * 0.5, center.dy + size * 0.4);
    path.close();
    canvas.drawPath(path, paint);
    
    // Exclamation mark
    canvas.drawCircle(Offset(center.dx, center.dy + size * 0.2), size * 0.08, 
        Paint()..color = paint.color..style = PaintingStyle.fill);
    canvas.drawLine(
      Offset(center.dx, center.dy - size * 0.2),
      Offset(center.dx, center.dy + size * 0.05),
      Paint()..color = paint.color..strokeWidth = size * 0.1..strokeCap = StrokeCap.round,
    );
  }

  void _drawBuzzer(Canvas canvas, Offset center, double size, Paint paint) {
    canvas.drawCircle(center, size * 0.6, paint);
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, size * (0.6 + i * 0.15), 
          Paint()..color = paint.color..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
  }

  void _drawSwitch(Canvas canvas, Offset center, double size, Paint paint) {
    final rect = Rect.fromCenter(center: center, width: size * 0.8, height: size * 0.4);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(size * 0.2)), paint);
    canvas.drawCircle(Offset(center.dx + size * 0.2, center.dy), size * 0.15, 
        Paint()..color = Colors.white..style = PaintingStyle.fill);
  }

  void _drawEmergency(Canvas canvas, Offset center, double size, Paint paint) {
    // Plus sign for emergency
    canvas.drawLine(
      Offset(center.dx - size * 0.4, center.dy),
      Offset(center.dx + size * 0.4, center.dy),
      Paint()..color = paint.color..strokeWidth = size * 0.15..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - size * 0.4),
      Offset(center.dx, center.dy + size * 0.4),
      Paint()..color = paint.color..strokeWidth = size * 0.15..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Analytics Background - Charts and data symbols
class AnalyticsBackgroundPainter extends CustomPainter {
  final Color color;

  AnalyticsBackgroundPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const double spacing = 85.0;
    const double iconSize = 26.0;

    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing) {
        final center = Offset(x, y);
        final patternIndex = ((x / spacing).floor() + (y / spacing).floor()) % 4;
        
        switch (patternIndex) {
          case 0:
            _drawChart(canvas, center, iconSize, paint);
            break;
          case 1:
            _drawGraph(canvas, center, iconSize, paint);
            break;
          case 2:
            _drawPieChart(canvas, center, iconSize, paint);
            break;
          case 3:
            _drawTrend(canvas, center, iconSize, paint);
            break;
        }
      }
    }
  }

  void _drawChart(Canvas canvas, Offset center, double size, Paint paint) {
    // Bar chart
    final bars = [0.3, 0.7, 0.5, 0.9, 0.4];
    for (int i = 0; i < bars.length; i++) {
      final x = center.dx - size * 0.4 + i * size * 0.2;
      final height = size * bars[i];
      canvas.drawLine(
        Offset(x, center.dy + size * 0.4),
        Offset(x, center.dy + size * 0.4 - height),
        Paint()..color = paint.color..strokeWidth = size * 0.1..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawGraph(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    path.moveTo(center.dx - size * 0.5, center.dy + size * 0.2);
    path.lineTo(center.dx - size * 0.2, center.dy - size * 0.3);
    path.lineTo(center.dx + size * 0.1, center.dy + size * 0.1);
    path.lineTo(center.dx + size * 0.5, center.dy - size * 0.4);
    canvas.drawPath(path, paint);
  }

  void _drawPieChart(Canvas canvas, Offset center, double size, Paint paint) {
    canvas.drawCircle(center, size * 0.4, paint);
    canvas.drawLine(center, Offset(center.dx, center.dy - size * 0.4), paint);
    canvas.drawLine(center, Offset(center.dx + size * 0.3, center.dy + size * 0.2), paint);
  }

  void _drawTrend(Canvas canvas, Offset center, double size, Paint paint) {
    // Upward trend arrow
    final path = Path();
    path.moveTo(center.dx - size * 0.4, center.dy + size * 0.2);
    path.lineTo(center.dx + size * 0.4, center.dy - size * 0.2);
    path.lineTo(center.dx + size * 0.2, center.dy - size * 0.1);
    path.moveTo(center.dx + size * 0.4, center.dy - size * 0.2);
    path.lineTo(center.dx + size * 0.3, center.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Splash Background - Welcome and care symbols
class SplashBackgroundPainter extends CustomPainter {
  final Color color;

  SplashBackgroundPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.30)
      ..style = PaintingStyle.fill;

    const double spacing = 110.0;
    const double iconSize = 35.0;

    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing) {
        final center = Offset(x, y);
        final patternIndex = ((x / spacing).floor() + (y / spacing).floor()) % 3;
        
        switch (patternIndex) {
          case 0:
            _drawCareSymbol(canvas, center, iconSize, paint);
            break;
          case 1:
            _drawWelcome(canvas, center, iconSize, paint);
            break;
          case 2:
            _drawProtection(canvas, center, iconSize, paint);
            break;
        }
      }
    }
  }

  void _drawCareSymbol(Canvas canvas, Offset center, double size, Paint paint) {
    // Hands caring symbol
    final path = Path();
    path.moveTo(center.dx - size * 0.3, center.dy - size * 0.2);
    path.quadraticBezierTo(center.dx, center.dy - size * 0.5, center.dx + size * 0.3, center.dy - size * 0.2);
    path.quadraticBezierTo(center.dx, center.dy + size * 0.2, center.dx - size * 0.3, center.dy - size * 0.2);
    canvas.drawPath(path, paint);
  }

  void _drawWelcome(Canvas canvas, Offset center, double size, Paint paint) {
    // Star/sparkle symbol
    canvas.drawLine(
      Offset(center.dx, center.dy - size * 0.4),
      Offset(center.dx, center.dy + size * 0.4),
      Paint()..color = paint.color..strokeWidth = size * 0.08..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(center.dx - size * 0.4, center.dy),
      Offset(center.dx + size * 0.4, center.dy),
      Paint()..color = paint.color..strokeWidth = size * 0.08..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(center.dx - size * 0.3, center.dy - size * 0.3),
      Offset(center.dx + size * 0.3, center.dy + size * 0.3),
      Paint()..color = paint.color..strokeWidth = size * 0.06..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(center.dx + size * 0.3, center.dy - size * 0.3),
      Offset(center.dx - size * 0.3, center.dy + size * 0.3),
      Paint()..color = paint.color..strokeWidth = size * 0.06..strokeCap = StrokeCap.round,
    );
  }

  void _drawProtection(Canvas canvas, Offset center, double size, Paint paint) {
    // Shield symbol
    final path = Path();
    path.moveTo(center.dx, center.dy - size * 0.5);
    path.lineTo(center.dx - size * 0.3, center.dy - size * 0.2);
    path.lineTo(center.dx - size * 0.3, center.dy + size * 0.2);
    path.lineTo(center.dx, center.dy + size * 0.5);
    path.lineTo(center.dx + size * 0.3, center.dy + size * 0.2);
    path.lineTo(center.dx + size * 0.3, center.dy - size * 0.2);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 
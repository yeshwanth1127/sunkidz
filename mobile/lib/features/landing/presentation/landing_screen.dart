import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import 'dart:math' as math;

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> with TickerProviderStateMixin {
  late AnimationController _gradientController;
  late AnimationController _starsController;
  late Animation<double> _gradientAnimation;
  final List<Star> _stars = [];
  
  @override
  void initState() {
    super.initState();
    
    // Gradient animation
    _gradientController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat(reverse: true);
    
    _gradientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_gradientController);
    
    // Stars animation
    _starsController = AnimationController(
      duration: const Duration(milliseconds: 50),
      vsync: this,
    )..repeat();
    
    // Generate random stars
    for (int i = 0; i < 100; i++) {
      _stars.add(Star());
    }
  }
  
  @override
  void dispose() {
    _gradientController.dispose();
    _starsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_gradientAnimation, _starsController]),
        builder: (context, child) {
          return Stack(
            children: [
              // Animated gradient background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(
                        const Color(0xFFFFB6C1), // Soft pink
                        const Color(0xFFB4D4FF), // Soft blue
                        _gradientAnimation.value,
                      )!,
                      Color.lerp(
                        const Color(0xFFE0BBE4), // Soft lavender
                        const Color(0xFFFFDAB9), // Soft peach
                        _gradientAnimation.value,
                      )!,
                      Color.lerp(
                        const Color(0xFFFFC5D9), // Soft coral pink
                        const Color(0xFFB6E5D8), // Soft mint
                        _gradientAnimation.value,
                      )!,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              // Animated stars
              CustomPaint(
                painter: StarsPainter(_stars, _starsController.value),
                size: Size.infinite,
              ),
              // Content
              SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Logo without white background
                            Image.asset(
                              'images/new_logo.png',
                              width: 200,
                              height: 200,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.school,
                                  size: 120,
                                  color: Colors.white.withValues(alpha: 0.9),
                                );
                              },
                            ),
                            const SizedBox(height: 40),
                            // Subtitle
                            Text(
                              'Learning Management System',
                              style: TextStyle(
                                fontSize: 22,
                                color: Colors.white.withValues(alpha: 0.95),
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w300,
                                shadows: [
                                  Shadow(
                                    blurRadius: 10,
                                    color: Colors.black.withValues(alpha: 0.2),
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Empowering Young Minds',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withValues(alpha: 0.9),
                                fontStyle: FontStyle.italic,
                                letterSpacing: 1,
                                shadows: [
                                  Shadow(
                                    blurRadius: 8,
                                    color: Colors.black.withValues(alpha: 0.15),
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Get Started Button
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () => context.go('/login'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFFE0BBE4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                elevation: 8,
                                shadowColor: Colors.black.withValues(alpha: 0.2),
                              ),
                              child: const Text(
                                'Get Started',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '© 2026 Sunkidz Learning Management System',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class Star {
  late double x;
  late double y;
  late double size;
  late double speed;
  late double opacity;
  
  Star() {
    final random = math.Random();
    x = random.nextDouble();
    y = random.nextDouble();
    size = random.nextDouble() * 2 + 1;
    speed = random.nextDouble() * 0.0005 + 0.0001;
    opacity = random.nextDouble() * 0.3 + 0.2;
  }
  
  void update() {
    y += speed;
    if (y > 1) {
      y = 0;
      x = math.Random().nextDouble();
    }
  }
}

class StarsPainter extends CustomPainter {
  final List<Star> stars;
  final double animationValue;
  
  StarsPainter(this.stars, this.animationValue);
  
  @override
  void paint(Canvas canvas, Size size) {
    for (var star in stars) {
      star.update();
      
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: star.opacity)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.size,
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(StarsPainter oldDelegate) => true;
}

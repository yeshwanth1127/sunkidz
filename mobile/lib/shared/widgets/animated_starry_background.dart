import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedStarryBackground extends StatefulWidget {
  final Widget child;
  const AnimatedStarryBackground({required this.child, super.key});

  @override
  State<AnimatedStarryBackground> createState() =>
      _AnimatedStarryBackgroundState();
}

class _AnimatedStarryBackgroundState extends State<AnimatedStarryBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final int starCount = 60;
  late List<_Star> stars;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60), // very slow
    )..repeat();
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
    stars = List.generate(starCount, (i) => _Star.random());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          children: [
            // Gradient background
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0F2027),
                      Color(0xFF2C5364),
                      Color(0xFF1B2936),
                    ],
                  ),
                ),
              ),
            ),
            // Stars
            Positioned.fill(
              child: CustomPaint(
                painter: _StarPainter(stars, _animation.value),
              ),
            ),
            // Foreground child
            Positioned.fill(child: widget.child),
          ],
        );
      },
    );
  }
}

class _Star {
  double x;
  double y;
  double radius;
  double speed;
  double twinkle;

  _Star(this.x, this.y, this.radius, this.speed, this.twinkle);

  static _Star random() {
    final rand = Random();
    return _Star(
      rand.nextDouble(), // x
      rand.nextDouble(), // y
      rand.nextDouble() * 1.2 + 0.3, // radius
      rand.nextDouble() * 0.0005 + 0.0002, // speed
      rand.nextDouble(), // twinkle
    );
  }
}

class _StarPainter extends CustomPainter {
  final List<_Star> stars;
  final double progress;

  _StarPainter(this.stars, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (final star in stars) {
      // Move star horizontally, wrap around
      final dx = (star.x + star.speed * progress * 60) % 1.0;
      final dy = star.y;
      // Twinkle effect
      final opacity =
          0.7 + 0.3 * sin(progress * 2 * pi + star.twinkle * 2 * pi);
      paint.color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(
        Offset(dx * size.width, dy * size.height),
        star.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) => true;
}

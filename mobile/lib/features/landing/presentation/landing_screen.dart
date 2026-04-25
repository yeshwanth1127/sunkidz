import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> with TickerProviderStateMixin {
  late final AnimationController _sunCtrl;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _line1Fade;
  late final Animation<double> _line2Fade;
  late final Animation<double> _taglineFade;
  late final Animation<double> _btnFade;

  @override
  void initState() {
    super.initState();

    _sunCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat();

    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

    _logoFade  = CurvedAnimation(parent: _fadeCtrl, curve: const Interval(0.0, 0.35, curve: Curves.easeOut));
    _logoSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeCtrl, curve: const Interval(0.0, 0.35, curve: Curves.easeOut)));
    _line1Fade   = CurvedAnimation(parent: _fadeCtrl, curve: const Interval(0.30, 0.60, curve: Curves.easeIn));
    _line2Fade   = CurvedAnimation(parent: _fadeCtrl, curve: const Interval(0.50, 0.75, curve: Curves.easeIn));
    _taglineFade = CurvedAnimation(parent: _fadeCtrl, curve: const Interval(0.65, 0.85, curve: Curves.easeIn));
    _btnFade     = CurvedAnimation(parent: _fadeCtrl, curve: const Interval(0.80, 1.00, curve: Curves.easeIn));

    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _sunCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E0),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'www.sunkidz.in',
                style: TextStyle(fontSize: 13, color: Color(0xFF8B7355), letterSpacing: 0.5),
              ),
            ),

            const Spacer(),

            // Rotating cartoon sun
            RotationTransition(
              turns: _sunCtrl,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFFFFE066), Color(0xFFFFB300)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.5),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Rays
                    ...List.generate(8, (i) {
                      final angle = i * 3.14159 * 2 / 8;
                      return Transform.translate(
                        offset: Offset(28 * (angle > 0 ? 1 : 0) * 0, 0),
                        child: Transform.rotate(
                          angle: angle,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Container(
                              width: 5,
                              height: 14,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD600),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    // Face
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFFD600),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _SunEye(), SizedBox(width: 10), _SunEye(),
                            ],
                          ),
                          SizedBox(height: 6),
                          _SunSmile(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Logo with fade + slide
            SlideTransition(
              position: _logoSlide,
              child: FadeTransition(
                opacity: _logoFade,
                child: Image.asset(
                  'assets/images/sunkidz_logo_hd.png',
                  width: 260,
                  height: 90,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Animated tagline
            FadeTransition(
              opacity: _line1Fade,
              child: const Text(
                'Making children\'s life',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5D4037),
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FadeTransition(
              opacity: _line2Fade,
              child: const Text(
                'a Celebration',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFE65100),
                  letterSpacing: 0.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 8),
            FadeTransition(
              opacity: _taglineFade,
              child: const Text(
                '— a Sun Kid',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8B7355),
                  fontStyle: FontStyle.italic,
                  letterSpacing: 1,
                ),
              ),
            ),

            const SizedBox(height: 36),

            // GET STARTED button
            FadeTransition(
              opacity: _btnFade,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: () => context.go('/login'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFF9B85), width: 2.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: Colors.transparent,
                    ),
                    child: const Text(
                      'GET STARTED',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF9B85),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Lottie at bottom
            Lottie.asset(
              'assets/images/homescreen.json',
              width: 300,
              height: 300,
              fit: BoxFit.contain,
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _SunEye extends StatelessWidget {
  const _SunEye();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF5D4037)),
    );
  }
}

class _SunSmile extends StatelessWidget {
  const _SunSmile();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(20, 10), painter: _SmilePainter());
  }
}

class _SmilePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(size.width / 2, size.height, size.width, 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> with TickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _line1Fade;
  late final Animation<double> _line2Fade;
  late final Animation<double> _btnFade;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

    _logoFade  = CurvedAnimation(parent: _fadeCtrl, curve: const Interval(0.0, 0.35, curve: Curves.easeOut));
    _logoSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeCtrl, curve: const Interval(0.0, 0.35, curve: Curves.easeOut)));
    _line1Fade   = CurvedAnimation(parent: _fadeCtrl, curve: const Interval(0.30, 0.60, curve: Curves.easeIn));
    _line2Fade   = CurvedAnimation(parent: _fadeCtrl, curve: const Interval(0.50, 0.75, curve: Curves.easeIn));
    _btnFade     = CurvedAnimation(parent: _fadeCtrl, curve: const Interval(0.80, 1.00, curve: Curves.easeIn));

    _fadeCtrl.forward();
  }

  @override
  void dispose() {
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
                'Making child\'s life',
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

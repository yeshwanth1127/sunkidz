import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E0), // Cream/beige background
      body: SafeArea(
        child: Column(
          children: [
            // Website URL at top
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text(
                'www.sunkidz.in',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8B7355),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            
            const Spacer(),
            
            // Sun icon above logo
            const Icon(
              Icons.wb_sunny,
              size: 60,
              color: Color(0xFFFFB74D), // Orange/yellow sun color
            ),
            
            const SizedBox(height: 20),
            
            // Sunkidz Logo Image
            Image.asset(
              'assets/images/new_logo.png',
              width: 280,
              height: 100,
              fit: BoxFit.contain,
            ),
            
            const SizedBox(height: 40),
            
            // GET STARTED button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: () => context.go('/login'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xFFFF9B85),
                      width: 2.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
            
            const SizedBox(height: 30),
            
            // Lottie Animation at bottom
            Lottie.asset(
              'assets/images/homescreen.json',
              width: 350,
              height: 350,
              fit: BoxFit.contain,
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

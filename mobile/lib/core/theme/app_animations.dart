import 'package:flutter/material.dart';

class AppAnimations {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 400);
  static const Duration slow = Duration(milliseconds: 700);

  static const Curve curve = Curves.easeInOutCirc;
  static const Curve slideCurve = Curves.easeOutCubic;

  static Route fadeRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: medium,
    );
  }

  static Route slideUpRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(begin: const Offset(0, 0.05), end: Offset.zero).chain(CurveTween(curve: slideCurve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: medium,
    );
  }
}

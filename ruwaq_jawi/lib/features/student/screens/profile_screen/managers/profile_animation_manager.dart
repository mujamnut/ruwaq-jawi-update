import 'package:flutter/material.dart';

class ProfileAnimationManager {
  late AnimationController fadeAnimationController;
  late AnimationController slideAnimationController;
  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;

  void initialize(TickerProvider vsync) {
    // Initialize animation controllers
    fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: vsync,
      value: 0.0,
    );
    slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: vsync,
      value: 0.0,
    );

    // Create animations
    fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: fadeAnimationController,
      curve: Curves.easeOutCubic,
    ));

    slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: slideAnimationController,
      curve: Curves.easeOutCubic,
    ));
  }

  void startAnimations() {
    fadeAnimationController.forward();
    slideAnimationController.forward();
  }

  void dispose() {
    fadeAnimationController.dispose();
    slideAnimationController.dispose();
  }
}
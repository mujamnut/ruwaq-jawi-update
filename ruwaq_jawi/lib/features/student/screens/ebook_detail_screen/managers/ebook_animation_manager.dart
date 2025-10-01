import 'package:flutter/material.dart';

class EbookAnimationManager {
  late AnimationController fadeAnimationController;
  late AnimationController slideAnimationController;
  late AnimationController scaleAnimationController;
  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;
  late Animation<double> scaleAnimation;

  void initialize(TickerProvider vsync) {
    // Initialize animation controllers
    fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: vsync,
    );
    slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: vsync,
    );
    scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: vsync,
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

    scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: scaleAnimationController,
      curve: Curves.easeOutBack,
    ));
  }

  void startAnimations() {
    fadeAnimationController.forward();
    slideAnimationController.forward();
    scaleAnimationController.forward();
  }

  void dispose() {
    fadeAnimationController.dispose();
    slideAnimationController.dispose();
    scaleAnimationController.dispose();
  }
}
import 'package:flutter/material.dart';

class EbookAnimationManager {
  late AnimationController fadeAnimationController;
  late AnimationController slideAnimationController;
  late AnimationController scaleAnimationController;
  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;
  late Animation<double> scaleAnimation;

  void initialize(TickerProvider vsync) {
    // Initialize animation controllers with optimized durations
    fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500), // Reduced from 800ms
      vsync: vsync,
    );
    slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400), // Reduced from 600ms
      vsync: vsync,
    );
    scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300), // Reduced from 400ms
      vsync: vsync,
    );

    // Create animations with smoother curves
    fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: fadeAnimationController,
        curve: Curves.easeOutQuart, // Smoother curve
      ),
    );

    slideAnimation =
        Tween<Offset>(
          begin: const Offset(0, 0.2), // Reduced from 0.3 for subtlety
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: slideAnimationController,
            curve: Curves.easeOutQuart, // Smoother curve
          ),
        );

    scaleAnimation =
        Tween<double>(
          begin: 0.95, // Reduced from 0.8 for subtlety
          end: 1.0,
        ).animate(
          CurvedAnimation(
            parent: scaleAnimationController,
            curve: Curves.easeOutBack,
          ),
        );
  }

  void startAnimations() {
    // Start animations with staggered timing for smoother effect
    fadeAnimationController.forward();

    // Start slide animation slightly delayed
    Future.delayed(const Duration(milliseconds: 50), () {
      slideAnimationController.forward();
    });

    // Start scale animation with more delay for layered effect
    Future.delayed(const Duration(milliseconds: 100), () {
      scaleAnimationController.forward();
    });
  }

  void dispose() {
    fadeAnimationController.dispose();
    slideAnimationController.dispose();
    scaleAnimationController.dispose();
  }
}

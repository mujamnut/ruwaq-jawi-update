import 'package:flutter/material.dart';

class AnimationManager {
  late AnimationController fadeController;
  late AnimationController slideController;
  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;

  final VoidCallback? onStateChanged;

  AnimationManager({this.onStateChanged});

  void initialize(TickerProvider vsync) {
    // Initialize animation controllers
    fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: vsync,
      value: 0.0,
    );

    slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: vsync,
      value: 0.0,
    );

    // Create animations
    fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: fadeController,
      curve: Curves.easeOutCubic,
    ));

    slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  void startAnimations() {
    fadeController.forward();
    slideController.forward();
  }

  void dispose() {
    fadeController.dispose();
    slideController.dispose();
  }
}
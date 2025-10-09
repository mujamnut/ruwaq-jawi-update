import 'package:flutter/material.dart';

/// Manager for handling all animations in the home screen
class HomeAnimationManager {
  late AnimationController fadeAnimationController;
  late AnimationController slideAnimationController;
  late AnimationController progressAnimationController;

  void initialize(TickerProvider vsync) {
    fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: vsync,
    );
    slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: vsync,
    );
    progressAnimationController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: vsync,
    );
  }

  void dispose() {
    fadeAnimationController.dispose();
    slideAnimationController.dispose();
    progressAnimationController.dispose();
  }
}

import 'dart:async';
import 'package:flutter/material.dart';

class ContentPlayerAnimations {
  // Animation controllers
  late AnimationController fadeAnimationController;
  late AnimationController slideAnimationController;
  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;

  // Skip animation state
  bool showSkipAnimation = false;
  bool isSkipForward = false;
  bool isSkipOnLeftSide = false;
  int skipSeconds = 10;
  Timer? skipAnimationTimer;

  // Callback for UI updates
  late VoidCallback _updateUI;

  ContentPlayerAnimations({
    required TickerProvider vsync,
    required VoidCallback updateUI,
  }) {
    _updateUI = updateUI;
    _initializeAnimations(vsync);
  }

  void _initializeAnimations(TickerProvider vsync) {
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
    fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: fadeAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: slideAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  // Start entry animations
  void startEntryAnimations() {
    Future.delayed(const Duration(milliseconds: 100), () {
      fadeAnimationController.forward();
      slideAnimationController.forward();
    });
  }

  // Skip feedback animation
  void showSkipFeedback(bool isBackward, int seconds, bool isLeftSide) {
    isSkipForward = !isBackward;
    skipSeconds = seconds;
    isSkipOnLeftSide = isLeftSide;
    showSkipAnimation = true;
    _updateUI();

    // Auto-hide after animation duration
    skipAnimationTimer?.cancel();
    skipAnimationTimer = Timer(const Duration(milliseconds: 800), () {
      showSkipAnimation = false;
      _updateUI();
    });
  }

  // Build skip animation overlay
  Widget buildSkipAnimationOverlay(BuildContext context) {
    if (!showSkipAnimation) return const SizedBox.shrink();

    return Positioned(
      left: isSkipOnLeftSide ? 40 : null,
      right: !isSkipOnLeftSide ? 40 : null,
      top: 0,
      bottom: 0,
      child: AnimatedOpacity(
        opacity: showSkipAnimation ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 600),
                  tween: Tween(begin: 0.8, end: 1.2),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Icon(
                        isSkipForward
                          ? Icons.fast_forward_rounded
                          : Icons.fast_rewind_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  '${skipSeconds}s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build loading animation for data
  Widget buildLoadingAnimation() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 1000),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeInOut,
                    builder: (context, rotation, child) {
                      return Transform.rotate(
                        angle: rotation * 2 * 3.14159,
                        child: const CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF2E7D32),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Memuat kandungan...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Build fade and slide animation wrapper
  Widget buildAnimatedContent({
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: fadeAnimation,
      builder: (context, _) {
        return Opacity(
          opacity: fadeAnimation.value.clamp(0.0, 1.0),
          child: SlideTransition(
            position: slideAnimation,
            child: child,
          ),
        );
      },
    );
  }

  // Dispose all animation resources
  void dispose() {
    skipAnimationTimer?.cancel();
    fadeAnimationController.dispose();
    slideAnimationController.dispose();
  }
}
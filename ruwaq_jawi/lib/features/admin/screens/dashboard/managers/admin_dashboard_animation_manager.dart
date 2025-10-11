import 'package:flutter/material.dart';

class AdminDashboardAnimationManager {
  late AnimationController appBarAnimationController;
  late AnimationController titleAnimationController;
  late Animation<double> appBarAnimation;
  late Animation<Offset> titleSlideAnimation;

  void initialize(TickerProvider tickerProvider) {
    appBarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: tickerProvider,
      value: 0.0,
    );

    titleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: tickerProvider,
      value: 0.0,
    );

    appBarAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: appBarAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    titleSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.3, 0),
    ).animate(
      CurvedAnimation(
        parent: titleAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  void hideAppBar() {
    appBarAnimationController.forward();
    titleAnimationController.forward();
  }

  void showAppBar() {
    appBarAnimationController.reverse();
    titleAnimationController.reverse();
  }

  void dispose() {
    appBarAnimationController.dispose();
    titleAnimationController.dispose();
  }
}

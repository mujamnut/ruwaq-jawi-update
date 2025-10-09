import 'dart:async';
import 'package:flutter/material.dart';

/// Manager for handling featured content auto-scroll
class HomeScrollManager {
  final PageController featuredScrollController;
  final AnimationController progressAnimationController;
  final VoidCallback onStateChanged;

  Timer? _autoScrollTimer;
  int _currentCardIndex = 0;
  int _totalCards = 0;
  bool _userIsScrolling = false;

  HomeScrollManager({
    required this.featuredScrollController,
    required this.progressAnimationController,
    required this.onStateChanged,
  });

  int get currentCardIndex => _currentCardIndex;
  int get totalCards => _totalCards;
  bool get userIsScrolling => _userIsScrolling;

  set currentCardIndex(int value) {
    _currentCardIndex = value;
    onStateChanged();
  }

  set totalCards(int value) {
    _totalCards = value;
  }

  set userIsScrolling(bool value) {
    _userIsScrolling = value;
  }

  void startAutoScroll() {
    _resetAutoScrollTimer();
  }

  void _resetAutoScrollTimer() {
    _autoScrollTimer?.cancel();
    progressAnimationController.stop();
    progressAnimationController.reset();
    _startProgressAnimation();
  }

  void _startProgressAnimation() {
    if (!_userIsScrolling) {
      progressAnimationController.forward().then((_) {
        if (featuredScrollController.hasClients && !_userIsScrolling) {
          _scrollToNextCard();
          progressAnimationController.reset();
          _startProgressAnimation();
        }
      });
    } else {
      Timer(const Duration(milliseconds: 100), () {
        _userIsScrolling = false;
        _startProgressAnimation();
      });
    }
  }

  void _scrollToNextCard() {
    if (_totalCards == 0) return;

    _currentCardIndex = (_currentCardIndex + 1) % _totalCards;
    onStateChanged();

    final currentPage = featuredScrollController.page?.round() ?? 0;
    final nextPage = currentPage + 1;

    featuredScrollController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
  }

  void onPageChanged(int index) {
    _currentCardIndex = index % _totalCards;
    _userIsScrolling = true;
    _resetAutoScrollTimer();
    onStateChanged();
  }

  void dispose() {
    _autoScrollTimer?.cancel();
  }
}

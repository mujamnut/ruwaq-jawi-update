import 'admin_dashboard_animation_manager.dart';

class AdminDashboardScrollManager {
  AdminDashboardScrollManager({
    required this.animationManager,
    this.scrollThreshold = 100,
    this.sensitivity = 5,
  });

  final AdminDashboardAnimationManager animationManager;
  final double scrollThreshold;
  final double sensitivity;

  double _lastScrollOffset = 0;
  bool _isScrollingDown = false;

  void handleScroll(double currentOffset) {
    final delta = (currentOffset - _lastScrollOffset).abs();
    if (delta < sensitivity) {
      _lastScrollOffset = currentOffset;
      return;
    }

    final isScrollingDown = currentOffset > _lastScrollOffset;

    if (isScrollingDown && currentOffset > scrollThreshold && !_isScrollingDown) {
      _isScrollingDown = true;
      animationManager.hideAppBar();
    } else if (!isScrollingDown && _isScrollingDown) {
      _isScrollingDown = false;
      animationManager.showAppBar();
    }

    _lastScrollOffset = currentOffset;
  }

  void reset() {
    _lastScrollOffset = 0;
    _isScrollingDown = false;
  }
}

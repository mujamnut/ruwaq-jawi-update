import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';

class AdminBottomNav extends StatelessWidget {
  final int currentIndex;

  const AdminBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, -8),
            spreadRadius: 0,
          ),
        ],
        border: Border(
          top: BorderSide(
            color: AppTheme.borderColor.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppTheme.primaryColor,
          unselectedItemColor: Colors.grey[600],
          selectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: AppTheme.primaryColor,
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 11,
            color: Colors.grey[600],
          ),
          currentIndex: currentIndex,
          onTap: (index) => _onNavTap(context, index),
          items: [
            _buildNavItem(
              HugeIcons.strokeRoundedDashboardSquare01,
              'Dashboard',
              0,
            ),
            _buildNavItem(HugeIcons.strokeRoundedLibrary, 'Kandungan', 1),
            _buildNavItem(HugeIcons.strokeRoundedBook02, 'E-book', 2),
            _buildNavItem(HugeIcons.strokeRoundedUserMultiple, 'Pengguna', 3),
            _buildNavItem(HugeIcons.strokeRoundedAnalytics01, 'Analitik', 4),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(
    IconData icon,
    String label,
    int index,
  ) {
    final isSelected = currentIndex == index;
    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00BF6D).withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(
                  color: const Color(0xFF00BF6D).withOpacity(0.3),
                  width: 1,
                )
              : null,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: HugeIcon(
            key: ValueKey(isSelected),
            icon: icon,
            size: 22.0,
            color: isSelected ? const Color(0xFF00BF6D) : Colors.grey.shade600,
          ),
        ),
      ),
      label: label,
    );
  }

  void _onNavTap(BuildContext context, int index) {
    if (index == currentIndex) return;

    switch (index) {
      case 0:
        context.go('/admin/dashboard');
        break;
      case 1:
        context.go('/admin/content');
        break;
      case 2:
        context.go('/admin/ebooks');
        break;
      case 3:
        context.go('/admin/users');
        break;
      case 4:
        context.go('/admin/analytics-real');
        break;
    }
  }
}

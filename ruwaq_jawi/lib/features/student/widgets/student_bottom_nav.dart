import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_theme.dart';

class StudentBottomNav extends StatelessWidget {
  final int currentIndex;

  const StudentBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppTheme.surfaceColor,
      selectedItemColor: AppTheme.primaryColor,
      unselectedItemColor: AppTheme.textSecondaryColor,
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
      elevation: 8,
      onTap: (index) => _onNavTap(context, index),
      items: [
        BottomNavigationBarItem(
          icon: PhosphorIcon(
            PhosphorIcons.house(),
            color: currentIndex == 0
                ? AppTheme.primaryColor
                : AppTheme.textSecondaryColor,
            size: 24,
          ),
          activeIcon: PhosphorIcon(
            PhosphorIcons.house(PhosphorIconsStyle.fill),
            color: AppTheme.primaryColor,
            size: 24,
          ),
          label: 'Utama',
        ),
        BottomNavigationBarItem(
          icon: PhosphorIcon(
            PhosphorIcons.chalkboardTeacher(),
            color: currentIndex == 1
                ? AppTheme.primaryColor
                : AppTheme.textSecondaryColor,
            size: 24,
          ),
          activeIcon: PhosphorIcon(
            PhosphorIcons.chalkboardTeacher(PhosphorIconsStyle.fill),
            color: AppTheme.primaryColor,
            size: 24,
          ),
          label: 'Pengajian',
        ),
        BottomNavigationBarItem(
          icon: PhosphorIcon(
            PhosphorIcons.books(),
            color: currentIndex == 2
                ? AppTheme.primaryColor
                : AppTheme.textSecondaryColor,
            size: 24,
          ),
          activeIcon: PhosphorIcon(
            PhosphorIcons.books(PhosphorIconsStyle.fill),
            color: AppTheme.primaryColor,
            size: 24,
          ),
          label: 'E-Book',
        ),
        BottomNavigationBarItem(
          icon: PhosphorIcon(
            PhosphorIcons.crown(),
            color: currentIndex == 3
                ? AppTheme.primaryColor
                : AppTheme.textSecondaryColor,
            size: 24,
          ),
          activeIcon: PhosphorIcon(
            PhosphorIcons.crown(PhosphorIconsStyle.fill),
            color: AppTheme.primaryColor,
            size: 24,
          ),
          label: 'Langganan',
        ),
      ],
    );
  }

  void _onNavTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/kitab');
        break;
      case 2:
        context.go('/ebook');
        break;
      case 3:
        context.go('/subscription');
        break;
    }
  }
}

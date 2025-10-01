import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../../core/theme/app_theme.dart';

class EnhancedTabBarWidget extends StatelessWidget {
  final TabController tabController;

  const EnhancedTabBarWidget({
    super.key,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderColor.withValues(alpha: 0.5),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: tabController,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: AppTheme.textSecondaryColor,
        indicatorColor: AppTheme.primaryColor,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: tabController,
                  builder: (context, child) {
                    return HugeIcon(
                      icon: HugeIcons.strokeRoundedVideo01,
                      size: 18,
                      color: tabController.index == 0
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondaryColor,
                    );
                  },
                ),
                const SizedBox(width: 8),
                const Text('Video'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: tabController,
                  builder: (context, child) {
                    return HugeIcon(
                      icon: HugeIcons.strokeRoundedPdf01,
                      size: 18,
                      color: tabController.index == 1
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondaryColor,
                    );
                  },
                ),
                const SizedBox(width: 8),
                const Text('E-Book'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
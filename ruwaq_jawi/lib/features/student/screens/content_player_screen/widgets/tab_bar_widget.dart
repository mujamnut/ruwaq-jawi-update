import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

class TabBarWidget extends StatelessWidget {
  final TabController controller;
  final int currentTabIndex;
  final int episodesCount;

  const TabBarWidget({
    super.key,
    required this.controller,
    required this.currentTabIndex,
    required this.episodesCount,
  });

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      indicator: UnderlineTabIndicator(
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 3),
        insets: const EdgeInsets.symmetric(horizontal: 0),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: AppTheme.borderColor.withValues(alpha: 0.3),
      labelColor: AppTheme.textPrimaryColor,
      unselectedLabelColor: AppTheme.textSecondaryColor,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      tabs: const [
        Tab(text: 'Episodes'),
        Tab(text: 'PDF View'),
      ],
    );
  }
}

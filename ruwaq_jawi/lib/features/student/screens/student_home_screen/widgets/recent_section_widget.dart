import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../../core/providers/kitab_provider.dart';
import '../../../../../core/theme/app_theme.dart';
import 'recent_list_item_widget.dart';

class RecentSectionWidget extends StatelessWidget {
  const RecentSectionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<KitabProvider>(
      builder: (context, kitabProvider, child) {
        final recentContent = <dynamic>[
          ...kitabProvider.videoKitabList,
          ...kitabProvider.ebookList,
        ]..sort(
            (a, b) => (b as dynamic).createdAt.compareTo((a as dynamic).createdAt),
          );
        // Prepare list items only (no hero card)
        final listItems = recentContent.take(5).toList();

        if (listItems.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.clockCounterClockwise(),
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Terbaru',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => context.go('/kitab?sort=newest'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Lihat Semua',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: listItems.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return RecentListItemWidget(content: listItems[index]);
              },
            ),
          ],
        );
      },
    );
  }
}

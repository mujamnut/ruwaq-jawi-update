import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../../core/providers/kitab_provider.dart';
import '../../../../../core/theme/app_theme.dart';
import 'category_icon_card_widget.dart';

class CategoriesSectionWidget extends StatelessWidget {
  const CategoriesSectionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<KitabProvider>(
      builder: (context, kitabProvider, child) {
        final categories = kitabProvider.categories.take(6).toList();

        if (categories.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.folders(),
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Kategori',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.push('/categories'),
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
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.86,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final videoKitabCount = kitabProvider.videoKitabList
                    .where((k) => k.categoryId == category.id)
                    .length;
                final ebookCount = kitabProvider.ebookList
                    .where((e) => e.categoryId == category.id)
                    .length;
                final totalCount = videoKitabCount + ebookCount;

                return CategoryIconCardWidget(
                  category: category,
                  totalCount: totalCount,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

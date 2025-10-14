import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/models/category.dart';

class EbookCategoryChipsWidget extends StatelessWidget {
  final List<Category> categories;
  final String? selectedCategoryId;
  final Function(String?) onCategorySelected;

  const EbookCategoryChipsWidget({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final allCategories = ['Semua', ...categories.map((c) => c.name)];
    final selectedCategory = selectedCategoryId == null
        ? 'Semua'
        : categories.firstWhere((c) => c.id == selectedCategoryId).name;

    if (allCategories.length <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 35,
      // Margin handled by parent container for consistency with video list
      margin: EdgeInsets.zero,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: allCategories.length,
        itemBuilder: (context, index) {
          final category = allCategories[index];
          final isSelected = selectedCategory == category;

          return Container(
            margin: const EdgeInsets.only(right: 5),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (category == 'Semua') {
                    onCategorySelected(null);
                  } else {
                    final categoryId = categories
                        .firstWhere((c) => c.name == category)
                        .id;
                    onCategorySelected(categoryId);
                  }
                },
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 300),
                  tween: Tween(begin: 0.0, end: isSelected ? 1.0 : 0.0),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.95 + (0.05 * value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, // match video chips width
                          vertical: 2, // thinner top-bottom
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.borderColor,
                            width: 1,
                          ),
                          // boxShadow: isSelected
                          //     ? [
                          //         BoxShadow(
                          //           color: AppTheme.primaryColor.withValues(
                          //             alpha: 0.25,
                          //           ),
                          //           blurRadius: 12,
                          //           offset: const Offset(0, 4),
                          //         ),
                          //         BoxShadow(
                          //           color: Colors.black.withValues(alpha: 0.06),
                          //           blurRadius: 6,
                          //           offset: const Offset(0, 2),
                          //         ),
                          //       ]
                          //     : [
                          //         BoxShadow(
                          //           color: Colors.black.withValues(alpha: 0.04),
                          //           blurRadius: 8,
                          //           offset: const Offset(0, 2),
                          //         ),
                          //       ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: PhosphorIcon(
                                  PhosphorIcons.check(),
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            Text(
                              category,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.textSecondaryColor,
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

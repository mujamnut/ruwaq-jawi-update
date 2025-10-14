import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../utils/home_helpers.dart';

class CategoryCardWidget extends StatelessWidget {
  final dynamic category;
  final int totalCount;

  const CategoryCardWidget({
    super.key,
    required this.category,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/category/${category.id}'),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.borderColor,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            children: [
              // Top section with Arabic text
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: Column(
                    children: [
                      // Minimal accent bar
                      Container(
                        height: 6,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                        ),
                      ),
                      // White area with centered Arabic glyph/text
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6.0,
                              vertical: 8.0,
                            ),
                            child: FractionallySizedBox(
                              widthFactor: 0.98,
                              heightFactor: 0.95,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: _buildCategoryArabicDisplay(category.name),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom section with category name and count
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          category.name,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryColor,
                            fontSize: 12,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppTheme.borderColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$totalCount item',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryArabicDisplay(String categoryName) {
    final imagePath = HomeHelpers.getCategoryImagePath(categoryName);

    if (imagePath != null) {
      return Padding(
        padding: const EdgeInsets.all(5.0),
        child: ColorFiltered(
          colorFilter: const ColorFilter.mode(
            AppTheme.textPrimaryColor,
            BlendMode.srcIn,
          ),
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
            // Let the parent size control final dimensions, avoid infinity
            errorBuilder: (context, error, stackTrace) {
              // Fallback to solid dark text if image fails
              return Text(
                HomeHelpers.getArabicTextForCategory(categoryName),
                style: const TextStyle(
                  fontFamily: 'ArefRuqaa',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
                textAlign: TextAlign.center,
              );
            },
          ),
        ),
      );
    } else {
      // No image available; render solid dark Arabic text
      return Text(
        HomeHelpers.getArabicTextForCategory(categoryName),
        style: const TextStyle(
          fontFamily: 'ArefRuqaa',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimaryColor,
        ),
        textAlign: TextAlign.center,
      );
    }
  }
}

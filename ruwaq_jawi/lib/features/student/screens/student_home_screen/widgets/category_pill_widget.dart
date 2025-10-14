import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../../core/theme/app_theme.dart';

class CategoryPillWidget extends StatelessWidget {
  final dynamic category;
  final int totalCount;

  const CategoryPillWidget({
    super.key,
    required this.category,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.push('/category/${category.id}'),
        child: Container(
          width: 180,
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              _buildIconBadge(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textPrimaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
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
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconBadge() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.gradientStart.withValues(alpha: 0.12),
            AppTheme.gradientEnd.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(
          color: AppTheme.gradientStart.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Center(
        child: PhosphorIcon(
          _iconForCategoryName(category.name),
          color: AppTheme.textPrimaryColor,
          size: 22,
        ),
      ),
    );
  }

  IconData _iconForCategoryName(String name) {
    final n = name.toLowerCase();
    if (n.contains('quran') || n.contains('alquran') || n.contains('al-quran')) {
      return PhosphorIcons.bookOpen();
    }
    // Fallback generic icon for other categories
    return PhosphorIcons.books();
  }
}


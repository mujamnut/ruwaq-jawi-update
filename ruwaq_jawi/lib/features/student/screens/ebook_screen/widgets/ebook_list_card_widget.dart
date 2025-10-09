import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/models/ebook.dart';

class EbookListCardWidget extends StatelessWidget {
  final Ebook ebook;
  static int _globalIndex = 0;
  final int index;

  EbookListCardWidget({
    super.key,
    required this.ebook,
  }) : index = _globalIndex++ {
    // Reset counter periodically to prevent overflow
    if (_globalIndex > 1000) _globalIndex = 0;
  }

  // Get category color based on category name
  Color _getCategoryColor(String? category) {
    if (category == null) return AppTheme.primaryColor;

    final cat = category.toLowerCase();
    if (cat.contains('fiqh')) return const Color(0xFF00BF6D); // Green
    if (cat.contains('akidah')) return const Color(0xFF2196F3); // Blue
    if (cat.contains('tafsir')) return const Color(0xFF009688); // Teal
    if (cat.contains('sirah')) return const Color(0xFFE91E63); // Pink
    if (cat.contains('hadis')) return const Color(0xFFFF9800); // Orange
    if (cat.contains('tarikh')) return const Color(0xFF9C27B0); // Purple
    return AppTheme.primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = ebook.totalPages ?? 0;
    final categoryColor = _getCategoryColor(ebook.categoryName);
    // Generate rating between 4.7-5.0 based on index for variety
    final rating = (4.7 + (index % 4) * 0.1).toStringAsFixed(1);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/ebook/${ebook.id}');
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Square thumbnail/icon on left
              Hero(
                tag: 'ebook-cover-${ebook.id}',
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        categoryColor.withValues(alpha: 0.15),
                        categoryColor.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      // PDF icon
                      Center(
                        child: PhosphorIcon(
                          PhosphorIcons.filePdf(PhosphorIconsStyle.fill),
                          color: categoryColor,
                          size: 32,
                        ),
                      ),

                      // Premium badge overlay
                      if (ebook.isPremium == true)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: PhosphorIcon(
                              PhosphorIcons.crown(PhosphorIconsStyle.fill),
                              color: Colors.white,
                              size: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Content info on right
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title
                    Text(
                      ebook.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimaryColor,
                            fontSize: 14,
                            height: 1.3,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6),

                    // Author
                    Text(
                      ebook.author ?? 'Pengarang Tidak Diketahui',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondaryColor,
                            fontWeight: FontWeight.w400,
                            fontSize: 11,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    // Bottom row: Category badge & page count
                    Row(
                      children: [
                        // Category badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: categoryColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ebook.categoryName ?? 'E-Book',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                          ),
                        ),

                        const Spacer(),

                        // Page count
                        if (totalPages > 0)
                          Text(
                            '$totalPages halaman',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppTheme.textSecondaryColor,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 11,
                                ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Rating
                    Row(
                      children: [
                        PhosphorIcon(
                          PhosphorIcons.star(PhosphorIconsStyle.fill),
                          color: const Color(0xFFFFB800),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.textPrimaryColor,
                                fontWeight: FontWeight.w600,
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
}

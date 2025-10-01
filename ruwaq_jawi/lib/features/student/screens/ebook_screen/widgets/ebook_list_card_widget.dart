import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/models/ebook.dart';

class EbookListCardWidget extends StatelessWidget {
  final Ebook ebook;

  const EbookListCardWidget({
    super.key,
    required this.ebook,
  });

  @override
  Widget build(BuildContext context) {
    final totalPages = ebook.totalPages ?? 0;
    final categoryName = ebook.categoryName ?? 'Umum';

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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.borderColor.withValues(alpha: 0.3),
              width: 1,
            ),
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
              // PDF Icon with background
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: PhosphorIcon(
                    PhosphorIcons.filePdf(PhosphorIconsStyle.fill),
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with premium crown
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            ebook.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimaryColor,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (ebook.isPremium == true) ...[
                          const SizedBox(width: 8),
                          PhosphorIcon(
                            PhosphorIcons.crown(PhosphorIconsStyle.fill),
                            color: const Color(0xFFFFD700),
                            size: 16,
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Author
                    Text(
                      ebook.author ?? 'Pengarang Tidak Diketahui',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Category and pages
                    Row(
                      children: [
                        Text(
                          categoryName,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        if (totalPages > 0) ...[
                          Text(
                            ' • ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor.withValues(alpha: 0.6),
                            ),
                          ),
                          Text(
                            '$totalPages hal',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow indicator
              const SizedBox(width: 8),
              PhosphorIcon(
                PhosphorIcons.caretRight(),
                color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

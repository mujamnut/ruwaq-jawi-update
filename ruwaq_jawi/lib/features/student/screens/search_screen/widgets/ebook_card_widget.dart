import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../../core/theme/app_theme.dart';

class EbookCardWidget extends StatelessWidget {
  final Map<String, dynamic> ebook;

  const EbookCardWidget({
    super.key,
    required this.ebook,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPremium = ebook['isPremium'] == true;
    final int? totalPages = ebook['totalPages'];
    final String categoryName = ebook['categoryName'] ?? 'Kategori Umum';

    return GestureDetector(
      onTap: () => context.push('/ebook/${ebook['id']}'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20), // xl rounded
          border: Border.all(
            color: AppTheme.borderColor.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Book icon with circular background
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: PhosphorIcon(
                    PhosphorIcons.book(PhosphorIconsStyle.fill),
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Title with crown
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              ebook['title'] ?? 'Tidak Berjudul',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimaryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isPremium) ...[
                            const SizedBox(width: 6),
                            PhosphorIcon(
                              PhosphorIcons.crown(PhosphorIconsStyle.fill),
                              color: const Color(0xFFFFD700),
                              size: 16,
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Category
                      Text(
                        categoryName,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 2),

                      // Page info
                      Text(
                        totalPages != null && totalPages > 0
                            ? '$totalPages muka surat'
                            : 'E-Book tersedia',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

              // Arrow icon
              PhosphorIcon(
                PhosphorIcons.caretRight(),
                color: AppTheme.textSecondaryColor,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

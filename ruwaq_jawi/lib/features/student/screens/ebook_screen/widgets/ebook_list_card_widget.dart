import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/models/ebook.dart';
import '../../../../../core/providers/saved_items_provider.dart';

class EbookListCardWidget extends StatelessWidget {
  final Ebook ebook;
  static int _globalIndex = 0;
  final int index;

  EbookListCardWidget({super.key, required this.ebook})
    : index = _globalIndex++ {
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Square thumbnail/icon on left
              Hero(
                tag: 'ebook-cover-${ebook.id}',
                child: Container(
                  width: 90,
                  height: 100,
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
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Title only; action menu moved to trailing of main row
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

                    const SizedBox(height: 2),

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

                    // Bottom row: Category badge & page count (side by side)
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

                        // Gap between category and pages
                        const SizedBox(width: 8),

                        // Page count next to category
                        if (totalPages > 0)
                          Text(
                            '$totalPages Pages',
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

                    // Rating - show only if has ratings
                    if (ebook.hasRating)
                      Row(
                        children: [
                          PhosphorIcon(
                            PhosphorIcons.star(PhosphorIconsStyle.fill),
                            color: const Color(0xFFFFB800),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            ebook.averageRating.toStringAsFixed(1),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppTheme.textPrimaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${ebook.totalRatings})',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppTheme.textSecondaryColor,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 10,
                                ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'No ratings yet',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w400,
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Trailing action menu button flushed to card right
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor, width: 1),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showEbookOptionsBottomSheet(context, ebook);
                    },
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedMoreVertical,
                        color: AppTheme.textSecondaryColor,
                        size: 25,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEbookOptionsBottomSheet(BuildContext rootContext, Ebook ebook) {
    final savedProvider = rootContext.read<SavedItemsProvider>();
    final bool isSaved = savedProvider.isEbookSaved(ebook.id);

    showModalBottomSheet(
      context: rootContext,
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.books(),
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        ebook.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textPrimaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                height: 1,
                color: AppTheme.borderColor.withValues(alpha: 0.5),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    _buildBottomSheetOption(
                      context: context,
                      icon: isSaved
                          ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                          : PhosphorIcons.heart(),
                      title: isSaved
                          ? 'Buang dari Simpanan'
                          : 'Simpan ke Koleksi',
                      subtitle: isSaved
                          ? 'Alih keluar dari senarai simpanan'
                          : 'Simpan untuk bacaan kemudian',
                      iconColor: isSaved
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondaryColor,
                      onTap: () async {
                        Navigator.of(context).pop();
                        await savedProvider.toggleEbookSaved(ebook);
                        final nowSaved = savedProvider.isEbookSaved(ebook.id);
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                PhosphorIcon(
                                  nowSaved
                                      ? PhosphorIcons.heart(
                                          PhosphorIconsStyle.fill,
                                        )
                                      : PhosphorIcons.heartBreak(
                                          PhosphorIconsStyle.fill,
                                        ),
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  nowSaved
                                      ? 'Disimpan ke koleksi anda'
                                      : 'Dibuang dari simpanan',
                                ),
                              ],
                            ),
                            backgroundColor: AppTheme.primaryColor,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    _buildBottomSheetOption(
                      context: context,
                      icon: PhosphorIcons.shareFat(),
                      title: 'Kongsi',
                      subtitle: 'Kongsi dengan rakan dan keluarga',
                      iconColor: AppTheme.textSecondaryColor,
                      onTap: () {
                        Navigator.of(context).pop();
                        _showShareDialog(rootContext, ebook);
                      },
                    ),
                    _buildBottomSheetOption(
                      context: context,
                      icon: PhosphorIcons.eye(),
                      title: 'Lihat Detail',
                      subtitle: 'Buka halaman detail e-book',
                      iconColor: AppTheme.textSecondaryColor,
                      onTap: () {
                        Navigator.of(context).pop();
                        rootContext.push('/ebook/${ebook.id}');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomSheetOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Center(
                  child: PhosphorIcon(icon, color: iconColor, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textPrimaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
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

  void _showShareDialog(BuildContext context, Ebook ebook) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppTheme.surfaceColor,
        title: Row(
          children: [
            PhosphorIcon(
              PhosphorIcons.shareFat(),
              color: AppTheme.primaryColor,
              size: 22,
            ),
            const SizedBox(width: 12),
            const Text('Kongsi E-book'),
          ],
        ),
        content: Text(
          'Kongsi pautan e-book ini melalui aplikasi kongsi kegemaran anda.',
          style: TextStyle(color: AppTheme.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../../core/theme/app_theme.dart';

class EbookEmptyStateWidget extends StatelessWidget {
  final String searchQuery;
  final bool hasCategory;
  final VoidCallback onClearSearch;
  final VoidCallback onResetCategory;

  const EbookEmptyStateWidget({
    super.key,
    required this.searchQuery,
    required this.hasCategory,
    required this.onClearSearch,
    required this.onResetCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Enhanced empty state illustration
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.1),
                  AppTheme.secondaryColor.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: AppTheme.borderColor, width: 1),
            ),
            child: PhosphorIcon(
              PhosphorIcons.filePdf(),
              size: 80,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 32),

          // Title and description
          Text(
            'Tiada E-Book Ditemui',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.textPrimaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              searchQuery.isNotEmpty
                  ? 'Tiada e-book yang sepadan dengan pencarian "$searchQuery". Cuba gunakan kata kunci yang berbeza.'
                  : 'Cuba ubah kategori atau periksa semula untuk melihat e-book yang tersedia.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondaryColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (searchQuery.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onClearSearch();
                  },
                  icon: PhosphorIcon(
                    PhosphorIcons.x(),
                    color: AppTheme.textSecondaryColor,
                    size: 18,
                  ),
                  label: const Text('Hapus Pencarian'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondaryColor,
                    side: const BorderSide(color: AppTheme.borderColor),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),

              if (searchQuery.isNotEmpty && hasCategory)
                const SizedBox(width: 12),

              if (hasCategory)
                ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onResetCategory();
                  },
                  icon: PhosphorIcon(
                    PhosphorIcons.arrowClockwise(),
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text('Set Semula'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

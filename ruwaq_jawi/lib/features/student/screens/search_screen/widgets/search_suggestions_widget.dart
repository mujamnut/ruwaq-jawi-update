import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/providers/kitab_provider.dart';
import '../../../../../core/models/video_kitab.dart';
import '../../../../../core/models/ebook.dart';
import '../managers/search_manager.dart';
import 'video_kitab_card_widget.dart';
import 'ebook_card_widget.dart';

class SearchSuggestionsWidget extends StatelessWidget {
  final SearchManager searchManager;
  final ScrollController scrollController;
  final Function(String) onSuggestionSelected;
  final Function(String) onRecentRemoved;

  const SearchSuggestionsWidget({
    super.key,
    required this.searchManager,
    required this.scrollController,
    required this.onSuggestionSelected,
    required this.onRecentRemoved,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<KitabProvider>(
      builder: (context, kitabProvider, child) {
        // Filter items based on selected filter
        final allItems = <dynamic>[];

        if (searchManager.selectedFilter == 'Semua') {
          allItems.addAll(kitabProvider.activeVideoKitab);
          allItems.addAll(kitabProvider.activeEbooks);
        } else if (searchManager.selectedFilter == 'Pengajian') {
          allItems.addAll(kitabProvider.activeVideoKitab);
        } else if (searchManager.selectedFilter == 'E-Book') {
          allItems.addAll(kitabProvider.activeEbooks);
        }

        if (allItems.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return CustomScrollView(
          controller: scrollController,
          slivers: [
            // Recent searches (if any)
            if (searchManager.recentSearches.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  color: AppTheme.backgroundColor,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        context,
                        'Carian Terkini',
                        PhosphorIcons.clockCounterClockwise(),
                      ),
                      const SizedBox(height: 12),
                      _buildSearchChips(searchManager.recentSearches, true),
                    ],
                  ),
                ),
              ),

            // Filtered items list
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = allItems[index];
                    if (item is VideoKitab) {
                      return VideoKitabCardWidget(
                        kitab: {
                          'id': item.id,
                          'title': item.title,
                          'isPremium': item.isPremium,
                          'totalVideos': item.totalVideos,
                          'categoryName': item.categoryName ?? 'Kategori Umum',
                          'thumbnailUrl': item.thumbnailUrl,
                        },
                      );
                    } else {
                      final ebook = item as Ebook;
                      return EbookCardWidget(
                        ebook: {
                          'id': ebook.id,
                          'title': ebook.title,
                          'isPremium': ebook.isPremium,
                          'totalPages': ebook.totalPages,
                          'categoryName': ebook.categoryName ?? 'Kategori Umum',
                        },
                      );
                    }
                  },
                  childCount: allItems.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, dynamic icon) {
    return Row(
      children: [
        PhosphorIcon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchChips(List<String> searches, bool isRecent) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: searches.map((search) {
        return InputChip(
          label: Text(search),
          onPressed: () => onSuggestionSelected(search),
          backgroundColor: AppTheme.surfaceColor,
          side: BorderSide(color: AppTheme.borderColor),
          labelStyle: const TextStyle(color: AppTheme.textPrimaryColor),
          avatar: isRecent
              ? PhosphorIcon(
                  PhosphorIcons.clockCounterClockwise(),
                  size: 16,
                  color: AppTheme.textSecondaryColor,
                )
              : PhosphorIcon(
                  PhosphorIcons.trendUp(),
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
          deleteIcon: isRecent
              ? PhosphorIcon(PhosphorIcons.x(), size: 16)
              : null,
          onDeleted: isRecent ? () => onRecentRemoved(search) : null,
        );
      }).toList(),
    );
  }
}

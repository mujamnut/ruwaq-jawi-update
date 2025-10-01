import 'package:flutter/material.dart';
import '../managers/search_manager.dart';
import 'video_kitab_card_widget.dart';
import 'ebook_card_widget.dart';

class SearchResultsWidget extends StatelessWidget {
  final SearchManager searchManager;
  final ScrollController scrollController;

  const SearchResultsWidget({
    super.key,
    required this.searchManager,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (searchManager.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (searchManager.searchResults.isEmpty) {
      return const SizedBox.shrink(); // Empty state handled separately
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: searchManager.searchResults.length,
      itemBuilder: (context, index) {
        final result = searchManager.searchResults[index];
        return _buildResultCard(result);
      },
    );
  }

  Widget _buildResultCard(Map<String, dynamic> result) {
    final type = result['type'];

    if (type == 'kitab' || type == 'video') {
      return VideoKitabCardWidget(kitab: result);
    } else if (type == 'ebook') {
      return EbookCardWidget(ebook: result);
    }

    // Fallback - should not happen
    return const SizedBox.shrink();
  }
}

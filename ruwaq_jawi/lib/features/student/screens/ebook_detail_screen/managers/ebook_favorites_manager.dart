import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/models/ebook.dart';
import '../../../../../core/providers/saved_items_provider.dart';

class EbookFavoritesManager {
  final VoidCallback onStateChanged;
  bool isSaved = false;

  EbookFavoritesManager({required this.onStateChanged});

  Future<void> checkSavedStatus(BuildContext context, Ebook? ebook) async {
    if (ebook != null) {
      final savedItemsProvider = context.read<SavedItemsProvider>();
      final saved = savedItemsProvider.isEbookSaved(ebook.id);
      // Only rebuild if status changed
      if (isSaved != saved) {
        isSaved = saved;
        onStateChanged();
      }
    }
  }

  Future<bool> toggleSaved(BuildContext context, Ebook? ebook) async {
    if (ebook == null) return false;

    try {
      final savedItemsProvider = context.read<SavedItemsProvider>();
      final success = await savedItemsProvider.toggleEbookSaved(ebook);

      if (success) {
        isSaved = !isSaved;
        onStateChanged();
      }

      return success;
    } catch (e) {
      debugPrint('Error toggling save status: $e');
      return false;
    }
  }
}
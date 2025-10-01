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
      final saved = await savedItemsProvider.isEbookSaved(ebook.id);
      isSaved = saved;
      onStateChanged();
    }
  }

  Future<bool> toggleSaved(BuildContext context, Ebook? ebook) async {
    if (ebook == null) return false;

    try {
      final savedItemsProvider = context.read<SavedItemsProvider>();
      bool success;

      if (isSaved) {
        success = await savedItemsProvider.removeEbookFromLocal(ebook.id);
      } else {
        success = await savedItemsProvider.addEbookToLocal(ebook);
      }

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
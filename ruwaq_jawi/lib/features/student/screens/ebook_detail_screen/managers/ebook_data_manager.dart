import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/models/ebook.dart';
import '../../../../../core/providers/kitab_provider.dart';
import '../../../../../core/services/supabase_service.dart';

class EbookDataManager {
  final VoidCallback onStateChanged;
  Ebook? ebook;
  bool isLoading = true;
  String? error;

  EbookDataManager({required this.onStateChanged});

  Future<void> loadEbookData(BuildContext context, String ebookId) async {
    try {
      // Only call setState once at start if state actually changed
      if (!isLoading) {
        isLoading = true;
        error = null;
        onStateChanged();
      }

      final kitabProvider = context.read<KitabProvider>();

      // Find ebook from provider first
      Ebook? loadedEbook = kitabProvider.activeEbooks
          .where((e) => e.id == ebookId)
          .firstOrNull;

      // If not found in provider, fetch from database
      if (loadedEbook == null) {
        final response = await SupabaseService.from('ebooks')
            .select('''
              *,
              categories (
                id, name, description
              )
            ''')
            .eq('id', ebookId)
            .single();

        loadedEbook = Ebook.fromJson(response);
      }

      ebook = loadedEbook;
      isLoading = false;
      // Only rebuild once at end with final state
      onStateChanged();
    } catch (e) {
      error = 'Ralat memuatkan e-book: ${e.toString()}';
      isLoading = false;
      // Only rebuild once on error
      onStateChanged();
      debugPrint('Error loading ebook data: $e');
    }
  }
}
import 'package:flutter/material.dart';
import '../../../../../core/models/ebook.dart';

class EbookFilterManager {
  // State
  String? selectedCategoryId;
  String searchQuery = '';

  // Callbacks
  final VoidCallback? onStateChanged;

  EbookFilterManager({this.onStateChanged});

  // Update category filter
  void updateCategory(String? categoryId) {
    selectedCategoryId = categoryId;
    onStateChanged?.call();
  }

  // Update search query
  void updateSearch(String query) {
    searchQuery = query;
    onStateChanged?.call();
  }

  // Clear search
  void clearSearch() {
    searchQuery = '';
    onStateChanged?.call();
  }

  // Filter ebooks based on category and search
  List<Ebook> filterEbooks(List<Ebook> ebooks) {
    return ebooks.where((ebook) {
      // Category filter
      bool categoryMatch =
          selectedCategoryId == null || ebook.categoryId == selectedCategoryId;

      // Search filter
      bool searchMatch =
          searchQuery.isEmpty ||
          ebook.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          (ebook.author?.toLowerCase().contains(searchQuery.toLowerCase()) ??
              false);

      return categoryMatch && searchMatch;
    }).toList();
  }

  // Sort ebooks by newest
  List<Ebook> sortByNewest(List<Ebook> ebooks) {
    final sorted = List<Ebook>.from(ebooks);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }
}

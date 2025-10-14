/// Helper functions for home screen
class HomeHelpers {
  /// Extract YouTube thumbnail URL from various YouTube URL formats
  static String getYouTubeThumbnailUrl(String? youtubeUrl) {
    if (youtubeUrl == null || youtubeUrl.isEmpty) return '';

    String? videoId;

    if (youtubeUrl.contains('youtube.com/watch?v=')) {
      videoId = youtubeUrl.split('v=')[1].split('&')[0];
    } else if (youtubeUrl.contains('youtu.be/')) {
      videoId = youtubeUrl.split('youtu.be/')[1].split('?')[0];
    } else if (youtubeUrl.contains('youtube.com/embed/')) {
      videoId = youtubeUrl.split('embed/')[1].split('?')[0];
    }

    if (videoId != null && videoId.isNotEmpty) {
      return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
    }

    return '';
  }

  /// Get Arabic text for category name
  static String getArabicTextForCategory(String categoryName) {
    final category = categoryName.toLowerCase().trim();

    if (category.contains('fiqh')) {
      return 'الفقه';
    } else if (category.contains('akidah')) {
      return 'العقيدة';
    } else if (category.contains('quran & tafsir')) {
      return 'القران و التفسير';
    } else if (category.contains('hadith')) {
      return 'الحديث';
    } else if (category.contains('sirah')) {
      return 'السيرة';
    } else if (category.contains('akhlak & tasawuf')) {
      return 'التصوف';
    } else if (category.contains('usul fiqh')) {
      return 'أصول الفقه';
    } else if (category.contains('bahasa arab')) {
      return 'لغة العربية';
    } else {
      return 'كتاب';
    }
  }

  /// Get category image path (PNG with transparent background)
  static String? getCategoryImagePath(String categoryName) {
    final category = categoryName.toLowerCase().trim();

    if (category.contains('fiqh')) {
      return 'assets/images/categories/fiqh.png';
    } else if (category.contains('akidah')) {
      return 'assets/images/categories/akidah.png';
    } else if (category.contains('quran & tafsir')) {
      return 'assets/images/categories/quran.png';
    } else if (category.contains('hadith')) {
      return 'assets/images/categories/hadith.png';
    } else if (category.contains('sirah')) {
      return 'assets/images/categories/sirah.png';
    } else if (category.contains('akhlak & tasawuf')) {
      return 'assets/images/categories/akhlak.png';
    } else if (category.contains('usul fiqh')) {
      return 'assets/images/categories/usul_fiqh.png';
    } else if (category.contains('bahasa arab')) {
      return 'assets/images/categories/bahasa_arab.png';
    }
    return null;
  }

  /// Format notification time to human-readable format
  static String formatNotificationTime(DateTime dateTime) {
    final now = DateTime.now().toUtc();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Baru saja';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minit lalu';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari lalu';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

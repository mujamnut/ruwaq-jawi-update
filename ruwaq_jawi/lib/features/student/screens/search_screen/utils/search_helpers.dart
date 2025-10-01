import 'package:phosphor_flutter/phosphor_flutter.dart';

class SearchHelpers {
  // Get icon based on result type
  static PhosphorIconData getResultIcon(String type) {
    switch (type) {
      case 'kitab':
        return PhosphorIcons.book();
      case 'video':
        return PhosphorIcons.videoCamera();
      case 'ebook':
        return PhosphorIcons.book();
      case 'author':
        return PhosphorIcons.user();
      default:
        return PhosphorIcons.magnifyingGlass();
    }
  }

  // Get route based on result type
  static String getResultRoute(Map<String, dynamic> result) {
    switch (result['type']) {
      case 'kitab':
      case 'video':
        return '/kitab/${result['id']}';
      case 'ebook':
        return '/ebook/${result['id']}';
      case 'author':
        return '/kitab?author=${result['title']}';
      default:
        return '/';
    }
  }
}

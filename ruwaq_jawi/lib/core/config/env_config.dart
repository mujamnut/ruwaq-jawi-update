import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  // 🔧 Load from .env file using flutter_dotenv
  static String get supabaseUrl {
    final url = dotenv.env['SUPABASE_URL'];
    if (url == null || url.isEmpty) {
      throw Exception('❌ SUPABASE_URL not found in .env file');
    }
    return url;
  }

  static String get supabaseAnonKey {
    final key = dotenv.env['SUPABASE_ANON_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('❌ SUPABASE_ANON_KEY not found in .env file');
    }
    return key;
  }

  static String get youtubeApiKey {
    final key = dotenv.env['YOUTUBE_API_KEY'];
    if (key == null || key.isEmpty) {
      if (kDebugMode) {
        // Debug logging removed
      }
      return 'your_youtube_api_key_here';
    }
    return key;
  }

  // Debug info (only in debug mode)
  static void printConfig() {
    if (kDebugMode) {
      // Debug logging removed
      // Debug logging removed
      // Debug logging removed
      // Debug logging removed
    }
  }
}
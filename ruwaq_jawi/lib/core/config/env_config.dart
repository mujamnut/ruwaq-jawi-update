import 'package:flutter/foundation.dart';

class EnvConfig {
  static const String _supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ckgxglvozrsognqqkpkk.supabase.co',
  );

  static const String _supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNrZ3hnbHZvenJzb2ducXFrcGtrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYyOTIwMDYsImV4cCI6MjA3MTg2ODAwNn0.AnTcS1uSC83m7pYT9UxAb_enhcEGCIor49AhuyCTkiQ',
  );

  static const String _youtubeApiKey = String.fromEnvironment(
    'YOUTUBE_API_KEY',
    defaultValue: 'your_youtube_api_key_here',
  );

  // Getters
  static String get supabaseUrl => _supabaseUrl;
  static String get supabaseAnonKey => _supabaseAnonKey;
  static String get youtubeApiKey => _youtubeApiKey;

  // Debug info (only in debug mode)
  static void printConfig() {
    if (kDebugMode) {
      print('🔧 Environment Configuration:');
      print('   Supabase URL: ${_supabaseUrl.substring(0, 30)}...');
      print('   Supabase Key: ${_supabaseAnonKey.substring(0, 20)}...');
      print('   YouTube Key: ${_youtubeApiKey.substring(0, 10)}...');
    }
  }
}
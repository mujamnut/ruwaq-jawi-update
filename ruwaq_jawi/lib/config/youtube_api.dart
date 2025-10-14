/// YouTube Data API Configuration
///
/// To enable auto-detection of video duration from YouTube URLs:
///
/// 1. Go to Google Cloud Console (https://console.cloud.google.com/)
/// 2. Create a new project or select existing project
/// 3. Enable the YouTube Data API v3
/// 4. Create credentials (API Key)
/// 5. Add your API key to .env file as YOUTUBE_API_KEY
///
/// Note: API key is loaded from environment configuration for security.
library;

import '../core/config/env_config.dart';

class YouTubeApiConfig {
  // YouTube API key loaded from environment configuration
  static String get apiKey => EnvConfig.youtubeApiKey;

  // Enable when valid API key is configured
  static bool get isEnabled => apiKey.isNotEmpty && apiKey != 'your_youtube_api_key_here';

  // YouTube Data API endpoints
  static const String baseUrl = 'https://www.googleapis.com/youtube/v3';
  static String getVideoDetailsUrl(String videoId) {
    return '$baseUrl/videos?id=$videoId&part=contentDetails,snippet&key=$apiKey';
  }
}

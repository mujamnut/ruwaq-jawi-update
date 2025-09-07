/// YouTube Data API Configuration
/// 
/// To enable auto-detection of video duration from YouTube URLs:
/// 
/// 1. Go to Google Cloud Console (https://console.cloud.google.com/)
/// 2. Create a new project or select existing project
/// 3. Enable the YouTube Data API v3
/// 4. Create credentials (API Key)
/// 5. Replace the placeholder below with your actual API key
/// 
/// Note: Keep your API key secure and don't commit it to version control.
/// Consider using environment variables or a config file for production.

class YouTubeApiConfig {
  // TODO: Replace with your actual YouTube Data API key
  static const String apiKey = 'YOUR_YOUTUBE_API_KEY_HERE';
  
  // If you have the API key, set this to true to enable auto-detection
  static const bool isEnabled = false;
  
  // YouTube Data API endpoints
  static const String baseUrl = 'https://www.googleapis.com/youtube/v3';
  static String getVideoDetailsUrl(String videoId) {
    return '$baseUrl/videos?id=$videoId&part=contentDetails,snippet&key=$apiKey';
  }
}

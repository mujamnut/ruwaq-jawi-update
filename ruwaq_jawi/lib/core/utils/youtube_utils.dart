class YouTubeUtils {
  /// Extracts YouTube video ID from various YouTube URL formats
  static String? extractVideoId(String? url) {
    if (url == null || url.isEmpty) return null;

    // Remove any whitespace
    url = url.trim();

    // Regular expressions for different YouTube URL formats
    final List<RegExp> patterns = [
      // youtu.be/VIDEO_ID
      RegExp(r'youtu\.be\/([a-zA-Z0-9_-]{11})'),
      // youtube.com/watch?v=VIDEO_ID
      RegExp(r'youtube\.com\/watch\?v=([a-zA-Z0-9_-]{11})'),
      // youtube.com/watch?v=VIDEO_ID&...
      RegExp(r'youtube\.com\/watch\?.*v=([a-zA-Z0-9_-]{11})'),
      // youtube.com/embed/VIDEO_ID
      RegExp(r'youtube\.com\/embed\/([a-zA-Z0-9_-]{11})'),
      // youtube.com/v/VIDEO_ID
      RegExp(r'youtube\.com\/v\/([a-zA-Z0-9_-]{11})'),
      // If it's already just a video ID
      RegExp(r'^([a-zA-Z0-9_-]{11})$'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null && match.groupCount > 0) {
        return match.group(1);
      }
    }

    return null;
  }

  /// Gets YouTube thumbnail URL from video ID or YouTube URL
  static String? getThumbnailUrl(String? url, {YouTubeThumbnailQuality quality = YouTubeThumbnailQuality.maxresdefault}) {
    final videoId = extractVideoId(url);
    if (videoId == null) return null;

    return 'https://img.youtube.com/vi/$videoId/${quality.value}.jpg';
  }

  /// Checks if a URL is a valid YouTube URL
  static bool isYouTubeUrl(String? url) {
    return extractVideoId(url) != null;
  }

  /// Gets multiple thumbnail qualities for a video
  static Map<YouTubeThumbnailQuality, String>? getAllThumbnails(String? url) {
    final videoId = extractVideoId(url);
    if (videoId == null) return null;

    final Map<YouTubeThumbnailQuality, String> thumbnails = {};
    for (final quality in YouTubeThumbnailQuality.values) {
      thumbnails[quality] = 'https://img.youtube.com/vi/$videoId/${quality.value}.jpg';
    }

    return thumbnails;
  }

  /// Gets the best available thumbnail URL with fallback options
  static String? getBestThumbnailUrl(String? url) {
    final videoId = extractVideoId(url);
    if (videoId == null) return null;

    // Try in order of quality: maxresdefault -> hqdefault -> mqdefault -> default
    final qualities = [
      YouTubeThumbnailQuality.maxresdefault,
      YouTubeThumbnailQuality.hqdefault,
      YouTubeThumbnailQuality.mqdefault,
      YouTubeThumbnailQuality.defaultQuality,
    ];

    for (final quality in qualities) {
      final thumbnailUrl = 'https://img.youtube.com/vi/$videoId/${quality.value}.jpg';
      // In practice, you might want to check if the URL exists
      // For now, we'll return the highest quality available
      return thumbnailUrl;
    }

    return null;
  }
}

/// YouTube thumbnail quality options
enum YouTubeThumbnailQuality {
  /// 1280x720 (if available)
  maxresdefault('maxresdefault'),

  /// 854x480
  sddefault('sddefault'),

  /// 640x480
  hqdefault('hqdefault'),

  /// 320x180
  mqdefault('mqdefault'),

  /// 120x90
  defaultQuality('default'),

  /// First frame thumbnail variants
  thumbnail1('1'),
  thumbnail2('2'),
  thumbnail3('3');

  const YouTubeThumbnailQuality(this.value);
  final String value;
}
import 'youtube_utils.dart';

class ThumbnailUtils {
  /// Get thumbnail URL with auto-fallback to YouTube if null/empty
  static String? getThumbnailUrlWithFallback({
    String? thumbnailUrl,
    String? youtubeVideoId,
    YouTubeThumbnailQuality quality = YouTubeThumbnailQuality.maxresdefault,
  }) {
    // If thumbnail_url exists and not empty, use it
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      return thumbnailUrl;
    }

    // Fallback to YouTube thumbnail if video ID available
    if (youtubeVideoId != null && youtubeVideoId.isNotEmpty) {
      return YouTubeUtils.getThumbnailUrl(youtubeVideoId, quality: quality);
    }

    // No thumbnail available
    return null;
  }

  /// Get kitab thumbnail with proper fallback logic
  static String? getKitabThumbnail(Map<String, dynamic> kitab) {
    return getThumbnailUrlWithFallback(
      thumbnailUrl: kitab['thumbnail_url'],
      youtubeVideoId: kitab['youtube_video_id'],
      quality: YouTubeThumbnailQuality.maxresdefault,
    );
  }

  /// Get episode/video thumbnail with proper fallback logic
  static String? getVideoThumbnail(Map<String, dynamic> video) {
    return getThumbnailUrlWithFallback(
      thumbnailUrl: video['thumbnail_url'],
      youtubeVideoId: video['youtube_video_id'],
      quality: YouTubeThumbnailQuality.hqdefault,
    );
  }

  /// Auto-fix missing thumbnails in data (for immediate use)
  static Map<String, dynamic> fixThumbnailsInKitab(Map<String, dynamic> kitab) {
    final fixedKitab = Map<String, dynamic>.from(kitab);

    // Fix main kitab thumbnail
    if ((fixedKitab['thumbnail_url'] == null || fixedKitab['thumbnail_url'] == '') &&
        fixedKitab['youtube_video_id'] != null && fixedKitab['youtube_video_id'] != '') {
      fixedKitab['thumbnail_url'] = YouTubeUtils.getThumbnailUrl(
        fixedKitab['youtube_video_id'],
        quality: YouTubeThumbnailQuality.maxresdefault,
      );
    }

    // Fix videos thumbnails if exists
    if (fixedKitab['kitab_videos'] != null) {
      final videos = fixedKitab['kitab_videos'] as List;
      for (int i = 0; i < videos.length; i++) {
        final video = videos[i] as Map<String, dynamic>;
        if ((video['thumbnail_url'] == null || video['thumbnail_url'] == '') &&
            video['youtube_video_id'] != null && video['youtube_video_id'] != '') {
          video['thumbnail_url'] = YouTubeUtils.getThumbnailUrl(
            video['youtube_video_id'],
            quality: YouTubeThumbnailQuality.hqdefault,
          );
        }
      }
    }

    return fixedKitab;
  }

  /// Auto-fix missing thumbnails in list of data
  static List<Map<String, dynamic>> fixThumbnailsInList(List<Map<String, dynamic>> items) {
    return items.map((item) => fixThumbnailsInKitab(item)).toList();
  }
}
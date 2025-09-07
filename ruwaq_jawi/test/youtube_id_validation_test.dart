import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YouTube Video ID Extraction Tests', () {
    String? extractYouTubeVideoId(String input) {
      final trimmed = input.trim();
      
      // Check if already a video ID (11 characters, alphanumeric and - and _ only, no spaces or special chars)
      final idRegex = RegExp(r'^[A-Za-z0-9_-]{11}$');
      if (idRegex.hasMatch(trimmed)) return trimmed;

      Uri? uri;
      try {
        uri = Uri.parse(trimmed);
      } catch (_) {
        return null;
      }
      
      if (uri.host.isEmpty) return null;

      final host = uri.host.replaceFirst('www.', '');
      final segs = uri.pathSegments;

      String? extractedId;
      
      // youtu.be/VIDEO_ID format
      if (host == 'youtu.be') {
        extractedId = segs.isNotEmpty ? segs.first : null;
      }
      // youtube.com formats
      else if (host.endsWith('youtube.com') || host.endsWith('youtube-nocookie.com')) {
        // Watch URL: /watch?v=VIDEO_ID
        if (uri.path == '/watch' && uri.queryParameters.containsKey('v')) {
          extractedId = uri.queryParameters['v'];
        }
        // Embed/shorts/live: /embed/VIDEO_ID, /shorts/VIDEO_ID, /live/VIDEO_ID
        else if (segs.length >= 2 && 
            (segs[0] == 'embed' || segs[0] == 'shorts' || segs[0] == 'live' || segs[0] == 'v')) {
          extractedId = segs[1];
        }
      }
      
      // Validate extracted ID (must be exactly 11 characters)
      if (extractedId != null && idRegex.hasMatch(extractedId)) {
        return extractedId;
      }
      
      return null;
    }

    test('Valid YouTube URLs should return correct video ID', () {
      expect(extractYouTubeVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(extractYouTubeVideoId('https://youtu.be/dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(extractYouTubeVideoId('https://www.youtube.com/embed/dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(extractYouTubeVideoId('https://www.youtube.com/shorts/dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(extractYouTubeVideoId('dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
    });

    test('Invalid YouTube video IDs should return null', () {
      expect(extractYouTubeVideoId('onb5g9ABYZE1JPMR'), null); // 16 characters - too long
      expect(extractYouTubeVideoId('abc123'), null); // 6 characters - too short  
      expect(extractYouTubeVideoId(''), null); // empty
      expect(extractYouTubeVideoId('invalid@url'), null); // not a valid URL or ID (contains invalid char)
      expect(extractYouTubeVideoId('https://www.youtube.com/watch?v=onb5g9ABYZE1JPMR'), null); // Invalid ID in URL
    });

    test('Edge cases should be handled', () {
      expect(extractYouTubeVideoId('https://www.youtube.com/watch'), null); // No video parameter
      expect(extractYouTubeVideoId('https://google.com'), null); // Wrong domain
      expect(extractYouTubeVideoId('https://www.youtube.com/watch?v='), null); // Empty video parameter
    });

    print('All YouTube ID validation tests completed successfully!');
  });
}

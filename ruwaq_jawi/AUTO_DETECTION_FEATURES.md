# Auto-Detection Features for Video Kitab Admin

This document describes the auto-detection features implemented in the Video Kitab admin system.

## Features

### 1. PDF Page Count Auto-Detection

**Location**: Video Kitab Form → Media Tab → PDF Section

**How it works**:
- When an admin selects a PDF file, the system automatically tries to detect the number of pages
- Uses the `pdfx` package to read PDF metadata
- Automatically fills the "Total Pages" field if successful
- Shows a success message with the detected page count
- Falls back gracefully if detection fails (user can enter manually)

**Implementation**: 
- File: `lib/features/admin/screens/admin_video_kitab_form_screen.dart`
- Method: `_detectPdfPageCount()` and `_pickPdfFile()`

### 2. YouTube Video Duration Auto-Detection

**Location**: Episode Form → Basic Information → Duration Field

**How it works**:
- When an admin enters a YouTube URL, the system extracts the video ID
- Calls YouTube Data API v3 to get video metadata including duration
- Automatically converts duration from ISO 8601 format (PT15M30S) to minutes
- Fills the "Duration" field automatically
- Shows a success message with the detected duration

**Requirements**:
- YouTube Data API v3 key required
- Configure in `lib/config/youtube_api.dart`

**Implementation**:
- Files: 
  - `lib/features/admin/screens/admin_episode_form_screen.dart`
  - `lib/features/admin/screens/admin_video_kitab_form_screen.dart` (helper methods)
- Methods: `_detectVideoDurationFromYouTube()`, `_parseDurationToMinutes()`

## Configuration

### YouTube API Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create or select a project
3. Enable YouTube Data API v3
4. Create credentials (API Key)
5. Update `lib/config/youtube_api.dart`:
   ```dart
   static const String apiKey = 'YOUR_ACTUAL_API_KEY_HERE';
   static const bool isEnabled = true;
   ```

### Dependencies

Add these packages to `pubspec.yaml`:
```yaml
dependencies:
  pdfx: ^2.7.0        # For PDF reading
  googleapis: ^13.2.0 # For YouTube API
  http: ^1.1.0       # For API calls
```

## User Experience

### PDF Page Detection
1. Admin clicks "Pilih PDF" button
2. Selects PDF file from device
3. System automatically detects page count
4. Shows message: "Jumlah halaman PDF: X"
5. Field is populated automatically
6. If detection fails, shows: "Tidak dapat mengira halaman PDF secara automatik. Sila masukkan secara manual."

### YouTube Duration Detection
1. Admin enters YouTube URL in episode form
2. System extracts video ID and shows thumbnail preview
3. Automatically calls YouTube API for duration
4. Shows message: "Durasi video dikesan: X minit"
5. Duration field is populated automatically
6. If API is not configured, feature is silently skipped

## Error Handling

- All auto-detection features fail gracefully
- Users can always enter values manually
- No blocking errors if detection fails
- Clear user feedback about what happened

## Technical Notes

- PDF detection uses `pdfx` package for reliable PDF reading
- YouTube API integration follows best practices
- Auto-detection triggers are user-friendly (on file selection, URL change)
- UI provides helpful hints about auto-detection availability
- Configuration is centralized and easy to manage

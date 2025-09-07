# Episode Management Functionality

## Overview
The episode management functionality has been implemented to allow adding, editing, and managing video episodes for video kitab content.

## New Files Created

### 1. VideoEpisode Model (`lib/core/models/video_episode.dart`)
- Represents a video episode from the `video_episodes` table
- Includes properties: id, videoKitabId, title, description, youtubeVideoId, partNumber, duration, etc.
- Helper methods for YouTube URLs, thumbnails, and display formatting

### 2. VideoEpisodeService (`lib/core/services/video_episode_service.dart`)
- Service for managing video episodes
- Functions include:
  - `getEpisodesForVideoKitab()` - Get all episodes for a video kitab
  - `createEpisode()` - Add new episode
  - `updateEpisode()` - Edit existing episode
  - `deleteEpisode()` - Delete episode
  - `toggleEpisodeStatus()` - Activate/deactivate episode
  - YouTube URL extraction and validation helpers
  - Auto-update video kitab statistics (total videos, duration)

### 3. AdminEpisodeFormScreen (`lib/features/admin/screens/admin_episode_form_screen.dart`)
- Form screen for adding/editing video episodes
- Features:
  - YouTube URL validation and preview
  - Auto-extract video ID from various YouTube URL formats
  - Episode settings (active/inactive, preview/premium)
  - Duration and part number management
  - Real-time thumbnail preview from YouTube

## Updated Files

### AdminVideoKitabFormScreen
- Updated to use the new VideoEpisodeService
- Episode list now shows VideoEpisode objects instead of raw Map data
- Added "Tambah Episode" functionality
- Added episode preview, edit, delete actions
- Enhanced episode cards with preview badges and YouTube video preview

## How to Use

### Adding New Episode
1. Open a Video Kitab in the admin form
2. Go to "Episode" tab
3. Click "Tambah Episode" button
4. Fill in episode details:
   - Title (required)
   - Part number (auto-suggested)
   - YouTube URL or Video ID (required)
   - Duration in minutes
   - Description (optional)
   - Active/Inactive status
   - Preview/Premium status
5. Save the episode

### Episode Features
- **YouTube URL Support**: Accepts various YouTube URL formats:
  - `https://www.youtube.com/watch?v=VIDEO_ID`
  - `https://youtu.be/VIDEO_ID`
  - `https://www.youtube.com/embed/VIDEO_ID`
  - Raw video ID: `VIDEO_ID`
  
- **Auto-Preview**: Automatically generates thumbnail and validates YouTube video

- **Statistics**: Automatically updates video kitab total video count and duration

- **Part Number Management**: Auto-suggests next available part number

### Episode Management
- **Edit**: Click edit button to modify episode details
- **Preview**: Click play button to open YouTube video in browser
- **Activate/Deactivate**: Toggle episode visibility to users
- **Delete**: Remove episode with confirmation dialog

## Database Integration
- Uses `video_episodes` table
- Foreign key relationship with `video_kitab` table
- Automatically updates video kitab statistics when episodes are added/edited/deleted
- Supports episode ordering and status management

## Error Handling
- Validates YouTube URLs before saving
- Prevents duplicate part numbers within same video kitab
- Graceful error messages for user feedback
- Network-safe thumbnail loading with fallback

## Benefits
✅ **Complete Episode Management**: Add, edit, delete, and preview episodes
✅ **YouTube Integration**: Automatic video validation and thumbnail generation  
✅ **User-Friendly**: Intuitive form with real-time preview
✅ **Statistics**: Auto-update video counts and durations
✅ **Flexible URLs**: Supports all common YouTube URL formats
✅ **Status Management**: Control episode visibility and preview access

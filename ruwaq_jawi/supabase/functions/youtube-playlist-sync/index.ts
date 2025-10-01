import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};

Deno.serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    console.log('🎬 YouTube Playlist Sync called');
    const YOUTUBE_API_KEY = 'AIzaSyDD83zBGMED3tRk46Zqm5Kr8_mvr-n2b9U';

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Parse request body
    const { playlist_url, category_id, is_premium, is_active } = await req.json();
    console.log('📋 Request data:', { playlist_url, category_id, is_premium, is_active });

    // Extract playlist ID from URL
    const playlistIdMatch = playlist_url.match(/[?&]list=([^&]+)/);
    if (!playlistIdMatch) {
      throw new Error('Invalid YouTube playlist URL');
    }
    const playlistId = playlistIdMatch[1];
    console.log('🆔 Playlist ID:', playlistId);

    // Fetch playlist details from YouTube API
    const playlistResponse = await fetch(
      `https://www.googleapis.com/youtube/v3/playlists?part=snippet,status&id=${playlistId}&key=${YOUTUBE_API_KEY}`
    );
    if (!playlistResponse.ok) {
      throw new Error('Failed to fetch playlist from YouTube API');
    }

    const playlistData = await playlistResponse.json();
    if (!playlistData.items || playlistData.items.length === 0) {
      throw new Error('Playlist not found');
    }

    const playlist = playlistData.items[0];
    console.log('📝 Playlist details fetched:', playlist.snippet.title);

    // Fetch all videos in the playlist
    let allVideos = [];
    let nextPageToken = null;
    let totalDuration = 0;
    let firstVideoId = null;

    do {
      const videosUrl = `https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=${playlistId}&maxResults=50&key=${YOUTUBE_API_KEY}${nextPageToken ? `&pageToken=${nextPageToken}` : ''}`;
      const videosResponse = await fetch(videosUrl);
      if (!videosResponse.ok) {
        throw new Error('Failed to fetch videos from playlist');
      }
      const videosData = await videosResponse.json();
      allVideos.push(...videosData.items);
      nextPageToken = videosData.nextPageToken;
    } while (nextPageToken);

    console.log(`🎬 Found ${allVideos.length} videos in playlist`);

    // Get first video ID for main kitab thumbnail
    if (allVideos.length > 0) {
      firstVideoId = allVideos[0].snippet.resourceId.videoId;
    }

    // Get video durations
    const videoIds = allVideos.map(item => item.snippet.resourceId.videoId).join(',');
    const durationsResponse = await fetch(
      `https://www.googleapis.com/youtube/v3/videos?part=contentDetails&id=${videoIds}&key=${YOUTUBE_API_KEY}`
    );
    const durationsData = await durationsResponse.json();

    const videoDurations = {};
    durationsData.items?.forEach(video => {
      const duration = parseDuration(video.contentDetails.duration);
      videoDurations[video.id] = duration;
      totalDuration += duration;
    });

    // Generate thumbnail URL for main kitab
    const kitabThumbnailUrl = firstVideoId ?
      `https://img.youtube.com/vi/${firstVideoId}/maxresdefault.jpg` : null;

    console.log('🖼️ Generated kitab thumbnail:', kitabThumbnailUrl);

    // Create video kitab entry - SET TO ACTIVE IMMEDIATELY
    const { data: kitab, error: kitabError } = await supabase
      .from('video_kitab')
      .insert({
        title: playlist.snippet.title,
        author: playlist.snippet.channelTitle,
        description: playlist.snippet.description,
        youtube_playlist_id: playlistId,
        youtube_playlist_url: playlist_url,
        category_id,
        is_premium: is_premium || false,
        is_active: is_active !== false, // Default to true unless explicitly false
        auto_sync_enabled: true,
        total_videos: allVideos.length,
        total_duration_minutes: Math.round(totalDuration / 60),
        last_synced_at: new Date().toISOString(),
        thumbnail_url: kitabThumbnailUrl
      })
      .select()
      .single();

    if (kitabError) {
      throw new Error(`Failed to create kitab: ${kitabError.message}`);
    }
    console.log('📚 Kitab created with ID:', kitab.id);

    // Prepare episodes data - SET TO ACTIVE IMMEDIATELY
    const episodes = allVideos.map((video, index) => {
      const videoId = video.snippet.resourceId.videoId;
      const duration = videoDurations[videoId] || 0;
      const episodeThumbnailUrl = `https://img.youtube.com/vi/${videoId}/hqdefault.jpg`;

      return {
        title: video.snippet.title,
        description: video.snippet.description,
        youtube_video_id: videoId,
        youtube_video_url: `https://www.youtube.com/watch?v=${videoId}`,
        thumbnail_url: episodeThumbnailUrl,
        part_number: index + 1,
        duration_seconds: duration,
        duration_minutes: Math.round(duration / 60),
        is_active: is_active !== false, // Default to true unless explicitly false
        is_premium: is_premium || false,
        video_kitab_id: kitab.id
      };
    });

    console.log('📹 Prepared', episodes.length, 'episodes for insertion');

    // Insert episodes in batches
    const batchSize = 100;
    let insertedEpisodes = [];

    for (let i = 0; i < episodes.length; i += batchSize) {
      const batch = episodes.slice(i, i + batchSize);
      const { data: batchData, error: episodeError } = await supabase
        .from('video_episodes')
        .insert(batch)
        .select();

      if (episodeError) {
        console.error('Episode insert error:', episodeError);
        throw new Error(`Failed to create episodes: ${episodeError.message}`);
      }

      insertedEpisodes.push(...batchData);
    }

    console.log(`✅ Created ${insertedEpisodes.length} episodes`);

    // Prepare response data
    const episodesPreviews = insertedEpisodes.map(episode => ({
      title: episode.title,
      duration: episode.duration_seconds,
      is_active: episode.is_active,
      thumbnail_url: episode.thumbnail_url
    }));

    const response = {
      success: true,
      playlist_id: kitab.id,
      playlist_title: kitab.title,
      playlist_description: kitab.description,
      channel_title: kitab.author,
      total_videos: kitab.total_videos,
      total_duration_minutes: kitab.total_duration_minutes,
      thumbnail_url: kitab.thumbnail_url,
      is_active: kitab.is_active,
      episodes: episodesPreviews
    };

    console.log('🎉 Sync completed successfully');
    return new Response(JSON.stringify(response), {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });

  } catch (error) {
    console.error('❌ YouTube sync error:', error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
});

// Helper function to parse YouTube duration format (PT4M13S -> seconds)
function parseDuration(duration: string): number {
  const match = duration.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/);
  if (!match) return 0;

  const hours = parseInt(match[1] || '0');
  const minutes = parseInt(match[2] || '0');
  const seconds = parseInt(match[3] || '0');

  return hours * 3600 + minutes * 60 + seconds;
}
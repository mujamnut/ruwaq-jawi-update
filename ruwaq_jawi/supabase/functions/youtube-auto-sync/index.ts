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
    console.log('🔄 YouTube Auto Sync checking for new videos...');
    const YOUTUBE_API_KEY = 'AIzaSyDD83zBGMED3tRk46Zqm5Kr8_mvr-n2b9U';

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get all video kitabs with auto sync enabled
    // Note: All playlists with youtube_playlist_id should have auto_sync_enabled = true
    // This is enforced by database trigger (see migration 035_auto_enable_youtube_sync.sql)
    const { data: kitabs, error: kitabsError } = await supabase
      .from('video_kitab')
      .select('*')
      .eq('auto_sync_enabled', true)
      .not('youtube_playlist_id', 'is', null)
      .eq('is_active', true);

    if (kitabsError) {
      throw new Error(`Failed to fetch kitabs: ${kitabsError.message}`);
    }

    console.log(`📚 Found ${kitabs?.length || 0} kitabs with auto sync enabled`);

    let totalNewVideos = 0;
    const syncResults = [];

    for (const kitab of kitabs || []) {
      try {
        console.log(`🔍 Checking kitab: ${kitab.title} (${kitab.youtube_playlist_id})`);

        // Get existing video episodes for this kitab
        // IMPORTANT: Select part_number to get max and continue sequence
        const { data: existingEpisodes, error: episodesError } = await supabase
          .from('video_episodes')
          .select('youtube_video_id, part_number')
          .eq('video_kitab_id', kitab.id)
          .order('part_number', { ascending: false });

        if (episodesError) {
          console.error(`❌ Failed to fetch episodes for kitab ${kitab.id}:`, episodesError);
          continue;
        }

        const existingVideoIds = new Set(existingEpisodes?.map(ep => ep.youtube_video_id) || []);

        // Get the highest part_number to continue sequence
        const currentMaxPart = existingEpisodes && existingEpisodes.length > 0
          ? (existingEpisodes[0].part_number || 0) // First item has highest due to DESC order
          : 0;

        console.log(`📊 Existing episodes: ${existingEpisodes?.length || 0}, Max part_number: ${currentMaxPart}`);

        // Fetch current videos from YouTube playlist
        let allVideos = [];
        let nextPageToken = null;

        do {
          const videosUrl = `https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=${kitab.youtube_playlist_id}&maxResults=50&key=${YOUTUBE_API_KEY}${nextPageToken ? `&pageToken=${nextPageToken}` : ''}`;
          const videosResponse = await fetch(videosUrl);

          if (!videosResponse.ok) {
            console.error(`❌ Failed to fetch videos for playlist ${kitab.youtube_playlist_id}`);
            break;
          }

          const videosData = await videosResponse.json();
          allVideos.push(...videosData.items);
          nextPageToken = videosData.nextPageToken;
        } while (nextPageToken);

        // Find new videos not in database
        const newVideos = allVideos.filter(video =>
          !existingVideoIds.has(video.snippet.resourceId.videoId)
        );

        console.log(`🆕 Found ${newVideos.length} new videos for kitab: ${kitab.title}`);

        if (newVideos.length > 0) {
          // Get video durations for new videos
          const newVideoIds = newVideos.map(item => item.snippet.resourceId.videoId).join(',');
          const durationsResponse = await fetch(
            `https://www.googleapis.com/youtube/v3/videos?part=contentDetails&id=${newVideoIds}&key=${YOUTUBE_API_KEY}`
          );

          const videoDurations = {};
          if (durationsResponse.ok) {
            const durationsData = await durationsResponse.json();
            durationsData.items?.forEach(video => {
              const duration = parseDuration(video.contentDetails.duration);
              videoDurations[video.id] = duration;
            });
          }

          // Prepare new episodes data
          // Note: currentMaxPart already calculated above after fetching episodes
          console.log(`🔢 Starting part_number from: ${currentMaxPart + 1}`);

          const newEpisodes = newVideos.map((video, index) => {
            const videoId = video.snippet.resourceId.videoId;
            const duration = videoDurations[videoId] || 0;
            const episodeThumbnailUrl = `https://img.youtube.com/vi/${videoId}/hqdefault.jpg`;
            const partNumber = currentMaxPart + index + 1;

            console.log(`  📝 Episode ${partNumber}: ${video.snippet.title}`);

            return {
              title: video.snippet.title,
              description: video.snippet.description,
              youtube_video_id: videoId,
              youtube_video_url: `https://www.youtube.com/watch?v=${videoId}`,
              thumbnail_url: episodeThumbnailUrl,
              part_number: partNumber,
              duration_seconds: duration,
              duration_minutes: Math.round(duration / 60),
              is_active: true, // New videos are active by default
              is_premium: kitab.is_premium,
              video_kitab_id: kitab.id
            };
          });

          // Insert new episodes
          const { data: insertedEpisodes, error: insertError } = await supabase
            .from('video_episodes')
            .insert(newEpisodes)
            .select();

          if (insertError) {
            console.error(`❌ Failed to insert episodes for kitab ${kitab.id}:`, insertError);
            continue;
          }

          // Update kitab stats
          const totalDuration = (kitab.total_duration_minutes || 0) +
            newEpisodes.reduce((sum, ep) => sum + (ep.duration_minutes || 0), 0);

          await supabase
            .from('video_kitab')
            .update({
              total_videos: (kitab.total_videos || 0) + newVideos.length,
              total_duration_minutes: totalDuration,
              last_synced_at: new Date().toISOString()
            })
            .eq('id', kitab.id);

          totalNewVideos += newVideos.length;
          syncResults.push({
            kitab_id: kitab.id,
            kitab_title: kitab.title,
            new_videos_count: newVideos.length,
            status: 'success'
          });

          console.log(`✅ Added ${newVideos.length} new episodes to kitab: ${kitab.title}`);
        } else {
          // Update last synced time even if no new videos
          await supabase
            .from('video_kitab')
            .update({
              last_synced_at: new Date().toISOString()
            })
            .eq('id', kitab.id);

          syncResults.push({
            kitab_id: kitab.id,
            kitab_title: kitab.title,
            new_videos_count: 0,
            status: 'up_to_date'
          });
        }

      } catch (error) {
        console.error(`❌ Error syncing kitab ${kitab.id}:`, error);
        syncResults.push({
          kitab_id: kitab.id,
          kitab_title: kitab.title,
          new_videos_count: 0,
          status: 'error',
          error: error.message
        });
      }
    }

    const response = {
      success: true,
      message: `Auto sync completed. Found ${totalNewVideos} new videos across ${kitabs?.length || 0} playlists.`,
      total_new_videos: totalNewVideos,
      checked_playlists: kitabs?.length || 0,
      sync_results: syncResults,
      timestamp: new Date().toISOString()
    };

    console.log(`🎉 Auto sync completed: ${totalNewVideos} new videos found`);
    return new Response(JSON.stringify(response), {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });

  } catch (error) {
    console.error('❌ YouTube auto sync error:', error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString()
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
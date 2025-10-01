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
    console.log('⏰ YouTube Sync Cron Job started at:', new Date().toISOString());

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Check if auto sync is globally enabled
    const { data: syncSettings } = await supabase
      .from('youtube_sync_settings')
      .select('setting_value')
      .eq('setting_key', 'auto_sync_enabled')
      .single();

    if (syncSettings?.setting_value !== 'true') {
      console.log('❌ Auto sync is disabled globally');
      return new Response(JSON.stringify({
        success: false,
        message: 'Auto sync is disabled globally',
        timestamp: new Date().toISOString()
      }), {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }

    // Call the auto sync function
    const autoSyncResponse = await fetch(`${supabaseUrl}/functions/v1/youtube-auto-sync`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${supabaseServiceKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        triggered_by: 'cron',
        timestamp: new Date().toISOString()
      })
    });

    if (!autoSyncResponse.ok) {
      throw new Error(`Auto sync failed with status: ${autoSyncResponse.status}`);
    }

    const autoSyncResult = await autoSyncResponse.json();

    console.log('✅ Cron job completed successfully:', autoSyncResult);

    return new Response(JSON.stringify({
      success: true,
      message: 'Cron job completed successfully',
      auto_sync_result: autoSyncResult,
      timestamp: new Date().toISOString()
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });

  } catch (error) {
    console.error('❌ YouTube sync cron job error:', error);
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
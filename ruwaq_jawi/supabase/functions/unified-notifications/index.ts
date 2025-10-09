import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    console.log('🎆 Unified notifications system called - FIXED VERSION');

    const clientInfo = req.headers.get('x-client-info');
    if (clientInfo !== 'github-cron-daily') {
      return new Response(JSON.stringify({
        error: 'Unauthorized - invalid client info'
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 401
      });
    }

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const requestBody = await req.json().catch(() => ({}));
    const {
      check_hours = 24,
      check_payments = true,
      check_subscriptions = true
    } = requestBody;

    console.log(`🔍 Checking for NEW content created in last ${check_hours} hours`);

    const hoursAgo = new Date();
    hoursAgo.setHours(hoursAgo.getHours() - check_hours);

    const contentFound = [];
    const paymentNotifications = [];
    const subscriptionNotifications = [];
    let notificationsCreated = 0;

    // Get student count for reporting
    const { data: students } = await supabaseClient
      .from('profiles')
      .select('id')
      .eq('role', 'student');

    const studentCount = students?.length || 0;
    console.log(`👥 Found ${studentCount} students`);

    if (studentCount === 0) {
      return new Response(JSON.stringify({
        success: true,
        message: 'No students found',
        approach: 'unified_notifications_table'
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      });
    }

    // 1. Check new content (FIXED: check created_at, not updated_at)
    const contentResult = await checkNewContent(supabaseClient, hoursAgo, studentCount, contentFound);
    notificationsCreated += contentResult.created;

    // 2. Check payment notifications
    if (check_payments) {
      const paymentResult = await checkPaymentNotifications(supabaseClient, hoursAgo, studentCount, paymentNotifications);
      notificationsCreated += paymentResult.created;
    }

    // 3. Check subscription notifications
    if (check_subscriptions) {
      const subscriptionResult = await checkSubscriptionNotifications(supabaseClient, studentCount, subscriptionNotifications);
      notificationsCreated += subscriptionResult.created;
    }

    const totalNotifications = contentFound.length + paymentNotifications.length + subscriptionNotifications.length;

    const result = {
      success: true,
      message: totalNotifications > 0
        ? `Created ${totalNotifications} notifications`
        : 'No new events found in the specified time period',
      notifications_created: notificationsCreated,
      content_notifications: contentFound.length,
      payment_notifications: paymentNotifications.length,
      subscription_notifications: subscriptionNotifications.length,
      student_count: studentCount,
      events_found: {
        content: contentFound,
        payments: paymentNotifications,
        subscriptions: subscriptionNotifications
      },
      checked_hours: check_hours,
      approach: 'NOTIFICATIONS_TABLE',
      timestamp: new Date().toISOString()
    };

    console.log('🎆 Unified notifications completed:', result);

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200
    });

  } catch (error) {
    console.error('❌ Unified notifications error:', error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString()
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500
    });
  }
});

// Helper function for content notifications
async function checkNewContent(supabaseClient, hoursAgo, studentCount, contentFound) {
  let notificationsCreated = 0;

  console.log(`🔍 Checking NEW content created after: ${hoursAgo.toISOString()}`);

  // Check video_kitab - FIXED: use created_at instead of updated_at
  const { data: videoKitabs, error: videoKitabError } = await supabaseClient
    .from('video_kitab')
    .select(`id, title, author, created_at, categories (name)`)
    .eq('is_active', true)
    .gte('created_at', hoursAgo.toISOString())  // ✅ FIXED: Check creation date
    .order('created_at', { ascending: false });

  if (videoKitabError) {
    console.error('❌ Error fetching video_kitab:', videoKitabError);
  }

  console.log(`📊 Query returned ${videoKitabs?.length || 0} NEW video kitabs`);

  if (videoKitabs && videoKitabs.length > 0) {
    for (const video of videoKitabs) {
      console.log(`🔍 Processing NEW video: ${video.title} (created: ${video.created_at})`);

      // Check if already notified - use notifications table
      const { data: existing } = await supabaseClient
        .from('notifications')
        .select('id')
        .eq('type', 'broadcast')
        .eq('target_type', 'all')
        .contains('metadata', { content_id: video.id, content_type: 'video_kitab' })
        .limit(1);

      if (existing && existing.length > 0) {
        console.log(`⏭️ Skipping ${video.title} - already notified`);
        continue;
      }

      console.log(`✨ Creating notification for NEW video: ${video.title}`);

      // Create notification in CORRECT table (notifications)
      const notification = {
        type: 'broadcast',
        title: '📹 Kitab Video Baharu!',
        message: `"${video.title}" oleh ${video.author || 'Penulis'} telah ditambah dalam kategori ${video.categories?.name || 'Kategori Umum'}.`,
        target_type: 'all',
        target_criteria: { target_roles: ['student'] },
        metadata: {
          content_type: 'video_kitab',
          content_id: video.id,
          title: video.title,
          author: video.author,
          category: video.categories?.name,
          icon: '📹',
          action_url: '/kitab',
          source: 'unified_notifications_cron'
        }
      };

      const { error } = await supabaseClient
        .from('notifications')
        .insert(notification);

      if (error) {
        console.error(`❌ Error creating notification for ${video.title}:`, error);
      } else {
        notificationsCreated++;
        contentFound.push(`Video Kitab: ${video.title}`);
        console.log(`✅ Created notification for: ${video.title}`);
      }
    }
  } else {
    console.log('📹 No NEW video kitabs found');
  }

  // Check video_episodes - FIXED: use created_at
  console.log('🎬 Checking for NEW video episodes...');

  const { data: videoEpisodes, error: episodeError } = await supabaseClient
    .from('video_episodes')
    .select(`
      id, title, part_number, created_at,
      video_kitab (id, title, categories (name))
    `)
    .eq('is_active', true)
    .gte('created_at', hoursAgo.toISOString())  // ✅ FIXED: Check creation date
    .order('created_at', { ascending: false });

  if (episodeError) {
    console.error('❌ Error fetching video episodes:', episodeError);
  }

  console.log(`📊 Episode query returned ${videoEpisodes?.length || 0} NEW episodes`);

  if (videoEpisodes && videoEpisodes.length > 0) {
    for (const episode of videoEpisodes) {
      // Check if already notified
      const { data: existing } = await supabaseClient
        .from('notifications')
        .select('id')
        .eq('type', 'broadcast')
        .eq('target_type', 'all')
        .contains('metadata', { content_id: episode.id, content_type: 'video_episode' })
        .limit(1);

      if (existing && existing.length > 0) {
        console.log(`⏭️ Skipping episode ${episode.title} - already notified`);
        continue;
      }

      const notification = {
        type: 'broadcast',
        title: '🎬 Episode Baharu!',
        message: `Episode ${episode.part_number}: "${episode.title}" telah ditambah dalam kitab "${episode.video_kitab?.title || 'Kitab'}".`,
        target_type: 'all',
        target_criteria: { target_roles: ['student'] },
        metadata: {
          content_type: 'video_episode',
          content_id: episode.id,
          title: episode.title,
          episode_number: episode.part_number,
          parent_kitab: episode.video_kitab?.title,
          icon: '🎬',
          action_url: '/kitab',
          source: 'unified_notifications_cron'
        }
      };

      const { error } = await supabaseClient
        .from('notifications')
        .insert(notification);

      if (error) {
        console.error('❌ Error creating episode notification:', error);
      } else {
        notificationsCreated++;
        contentFound.push(`Video Episode: ${episode.title} (${episode.video_kitab?.title})`);
        console.log(`✅ Created notification for episode: ${episode.title}`);
      }
    }
  } else {
    console.log('🎬 No NEW video episodes found');
  }

  // Check ebooks - FIXED: use created_at
  console.log('📚 Checking for NEW ebooks...');

  const { data: ebooks, error: ebookError } = await supabaseClient
    .from('ebooks')
    .select(`id, title, author, created_at, categories (name)`)
    .eq('is_active', true)
    .gte('created_at', hoursAgo.toISOString())  // ✅ FIXED: Check creation date
    .order('created_at', { ascending: false });

  if (ebookError) {
    console.error('❌ Error fetching ebooks:', ebookError);
  }

  console.log(`📊 Ebook query returned ${ebooks?.length || 0} NEW ebooks`);

  if (ebooks && ebooks.length > 0) {
    for (const ebook of ebooks) {
      // Check if already notified
      const { data: existing } = await supabaseClient
        .from('notifications')
        .select('id')
        .eq('type', 'broadcast')
        .eq('target_type', 'all')
        .contains('metadata', { content_id: ebook.id, content_type: 'ebook' })
        .limit(1);

      if (existing && existing.length > 0) {
        console.log(`⏭️ Skipping ebook ${ebook.title} - already notified`);
        continue;
      }

      const notification = {
        type: 'broadcast',
        title: '📚 E-Book Baharu!',
        message: `"${ebook.title}" oleh ${ebook.author || 'Penulis'} telah ditambah dalam kategori ${ebook.categories?.name || 'Kategori Umum'}.`,
        target_type: 'all',
        target_criteria: { target_roles: ['student'] },
        metadata: {
          content_type: 'ebook',
          content_id: ebook.id,
          title: ebook.title,
          author: ebook.author,
          category: ebook.categories?.name,
          icon: '📚',
          action_url: '/ebook',
          source: 'unified_notifications_cron'
        }
      };

      const { error } = await supabaseClient
        .from('notifications')
        .insert(notification);

      if (error) {
        console.error('❌ Error creating ebook notification:', error);
      } else {
        notificationsCreated++;
        contentFound.push(`E-Book: ${ebook.title}`);
        console.log(`✅ Created notification for ebook: ${ebook.title}`);
      }
    }
  } else {
    console.log('📚 No NEW ebooks found');
  }

  console.log(`🎯 Content check completed: ${notificationsCreated} notifications created`);

  return { created: notificationsCreated };
}

// Helper function for payment notifications
async function checkPaymentNotifications(supabaseClient, hoursAgo, studentCount, paymentNotifications) {
  let notificationsCreated = 0;

  console.log('💳 Checking for recent successful payments...');

  const { data: recentPayments } = await supabaseClient
    .from('payments')
    .select(`
      id,
      user_id,
      amount,
      status,
      plan_type,
      created_at,
      profiles (email, full_name)
    `)
    .eq('status', 'completed')
    .gte('created_at', hoursAgo.toISOString())
    .order('created_at', { ascending: false });

  if (recentPayments && recentPayments.length > 0) {
    console.log(`💰 Found ${recentPayments.length} successful payments`);

    for (const payment of recentPayments) {
      // Check if already notified
      const { data: existing } = await supabaseClient
        .from('notifications')
        .select('id')
        .eq('type', 'personal')
        .eq('target_type', 'user')
        .contains('metadata', { payment_id: payment.id })
        .limit(1);

      if (existing && existing.length > 0) {
        console.log(`⏭️ Skipping payment ${payment.id} - already notified`);
        continue;
      }

      const notification = {
        type: 'personal',
        title: '🎉 Pembayaran Berjaya!',
        message: `Terima kasih! Pembayaran RM${payment.amount} untuk langganan ${payment.plan_type} telah berjaya diproses.`,
        target_type: 'user',
        target_criteria: { user_id: payment.user_id },
        metadata: {
          payment_id: payment.id,
          amount: payment.amount,
          plan_type: payment.plan_type,
          icon: '🎉',
          action_url: '/profile/subscription',
          source: 'unified_notifications_cron'
        }
      };

      const { error } = await supabaseClient
        .from('notifications')
        .insert(notification);

      if (error) {
        console.error('Error creating payment notification:', error);
      } else {
        notificationsCreated++;
        paymentNotifications.push(`Payment: RM${payment.amount} - ${payment.profiles?.full_name || payment.profiles?.email}`);
        console.log(`✅ Created payment notification for: ${payment.id}`);
      }
    }
  }

  return { created: notificationsCreated };
}

// Helper function for subscription notifications
async function checkSubscriptionNotifications(supabaseClient, studentCount, subscriptionNotifications) {
  let notificationsCreated = 0;

  console.log('📅 Checking for subscription expiry warnings...');

  // Check for subscriptions expiring in next 7 days
  const sevenDaysFromNow = new Date();
  sevenDaysFromNow.setDate(sevenDaysFromNow.getDate() + 7);

  const { data: expiringSubs } = await supabaseClient
    .from('user_subscriptions')
    .select(`
      id,
      user_id,
      plan_type,
      expires_at,
      status,
      profiles (email, full_name)
    `)
    .eq('status', 'active')
    .lte('expires_at', sevenDaysFromNow.toISOString())
    .gte('expires_at', new Date().toISOString())
    .order('expires_at', { ascending: true });

  if (expiringSubs && expiringSubs.length > 0) {
    console.log(`⏰ Found ${expiringSubs.length} expiring subscriptions`);

    for (const subscription of expiringSubs) {
      // Check if already notified in last 24 hours
      const oneDayAgo = new Date();
      oneDayAgo.setDate(oneDayAgo.getDate() - 1);

      const { data: existing } = await supabaseClient
        .from('notifications')
        .select('id, created_at')
        .eq('type', 'personal')
        .eq('target_type', 'user')
        .contains('metadata', { subscription_id: subscription.id, notification_type: 'expiring' })
        .gte('created_at', oneDayAgo.toISOString())
        .limit(1);

      if (existing && existing.length > 0) {
        console.log(`⏭️ Skipping subscription ${subscription.id} - already notified recently`);
        continue;
      }

      const expiryDate = new Date(subscription.expires_at);
      const today = new Date();
      const daysUntilExpiry = Math.ceil((expiryDate.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));

      const notification = {
        type: 'personal',
        title: '⏰ Pelan Akan Tamat!',
        message: `Pelan ${subscription.plan_type} anda akan tamat dalam ${daysUntilExpiry} hari. Sila buat pembaharuan untuk terus menikmati perkhidmatan.`,
        target_type: 'user',
        target_criteria: { user_id: subscription.user_id },
        metadata: {
          subscription_id: subscription.id,
          notification_type: 'expiring',
          plan_type: subscription.plan_type,
          expires_at: subscription.expires_at,
          days_until_expiry: daysUntilExpiry,
          icon: '⏰',
          action_url: '/profile/subscription',
          source: 'unified_notifications_cron'
        }
      };

      const { error } = await supabaseClient
        .from('notifications')
        .insert(notification);

      if (error) {
        console.error('Error creating subscription notification:', error);
      } else {
        notificationsCreated++;
        subscriptionNotifications.push(`Expiring: ${subscription.plan_type} - ${daysUntilExpiry} days - ${subscription.profiles?.full_name || subscription.profiles?.email}`);
        console.log(`✅ Created expiry notification for: ${subscription.id} (${daysUntilExpiry} days)`);
      }
    }
  }

  return { created: notificationsCreated };
}

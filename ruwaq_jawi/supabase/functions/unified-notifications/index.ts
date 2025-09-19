import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};

// Special UUID for global notifications (all students)
// NULL user_id = global notification visible to all students
const GLOBAL_USER_ID = null;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    console.log('🎆 Unified notifications system called');

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

    console.log(`🔍 Checking for content and events in last ${check_hours} hours (UNIFIED TABLE APPROACH)`);

    const hoursAgo = new Date();
    hoursAgo.setHours(hoursAgo.getHours() - check_hours);

    const contentFound = [];
    const paymentNotifications = [];
    const subscriptionNotifications = [];
    let unifiedNotificationsCreated = 0;

    // Get student count for reporting
    const { data: students } = await supabaseClient
      .from('profiles')
      .select('id')
      .eq('role', 'student');

    const studentCount = students?.length || 0;
    console.log(`👥 Found ${studentCount} students for unified notifications`);

    if (studentCount === 0) {
      return new Response(JSON.stringify({
        success: true,
        message: 'No students found',
        approach: 'unified_table_approach'
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      });
    }

    // 1. Check new content (existing logic)
    const contentResult = await checkNewContent(supabaseClient, hoursAgo, studentCount, contentFound);
    unifiedNotificationsCreated += contentResult.created;

    // 2. Check payment notifications
    if (check_payments) {
      const paymentResult = await checkPaymentNotifications(supabaseClient, hoursAgo, studentCount, paymentNotifications);
      unifiedNotificationsCreated += paymentResult.created;
    }

    // 3. Check subscription notifications
    if (check_subscriptions) {
      const subscriptionResult = await checkSubscriptionNotifications(supabaseClient, studentCount, subscriptionNotifications);
      unifiedNotificationsCreated += subscriptionResult.created;
    }

    const totalNotifications = contentFound.length + paymentNotifications.length + subscriptionNotifications.length;

    const result = {
      success: true,
      message: totalNotifications > 0
        ? `Created ${totalNotifications} UNIFIED notifications (1 record visible to ${studentCount} students each)`
        : 'No new events found in the specified time period',
      unified_notifications_created: totalNotifications,
      content_notifications: contentFound.length,
      payment_notifications: paymentNotifications.length,
      subscription_notifications: subscriptionNotifications.length,
      student_count: studentCount,
      total_potential_reach: totalNotifications * studentCount,
      database_efficiency: totalNotifications > 0
        ? `${totalNotifications} records instead of ${totalNotifications * studentCount} individual records (${((1 - totalNotifications / (totalNotifications * studentCount)) * 100).toFixed(1)}% reduction)`
        : 'N/A',
      events_found: {
        content: contentFound,
        payments: paymentNotifications,
        subscriptions: subscriptionNotifications
      },
      checked_hours: check_hours,
      approach: 'UNIFIED_TABLE_APPROACH',
      global_user_id: 'null_for_global',
      explanation: 'Uses NULL user_id for notifications visible to all students',
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
async function checkNewContent(supabaseClient: any, hoursAgo: Date, studentCount: number, contentFound: string[]) {
  let notificationsCreated = 0;

  console.log(`🔍 Checking video_kitab created/updated after: ${hoursAgo.toISOString()}`);

  // Check video_kitab - FIX: Split OR conditions into separate queries
  const { data: videoKitabs, error: videoKitabError } = await supabaseClient
    .from('video_kitab')
    .select(`id, title, author, created_at, updated_at, categories (name)`)
    .eq('is_active', true)
    .gte('updated_at', hoursAgo.toISOString())
    .order('created_at', { ascending: false });

  if (videoKitabError) {
    console.error('❌ Error fetching video_kitab:', videoKitabError);
  }

  console.log(`📊 Query returned ${videoKitabs?.length || 0} video kitabs`);

  if (videoKitabs && videoKitabs.length > 0) {
    console.log(`📹 Found ${videoKitabs.length} new video kitabs`);

    for (const video of videoKitabs) {
      console.log(`🔍 Processing video: ${video.title} (ID: ${video.id})`);

      // Check if already notified - Simplified duplicate detection
      const { data: existingUnified } = await supabaseClient
        .from('user_notifications')
        .select('id')
        .is('user_id', null) // Global notifications only
        .eq('metadata->>content_id', video.id.toString())
        .eq('metadata->>content_type', 'video_kitab')
        .limit(1);

      if (existingUnified && existingUnified.length > 0) {
        console.log(`⏭️ Skipping ${video.title} - already notified`);
        continue;
      }

      console.log(`✨ Creating new notification for: ${video.title}`);

      // Create unified notification
      const unifiedNotification = {
        id: crypto.randomUUID(),
        user_id: GLOBAL_USER_ID,
        message: `📹 Kitab Video Baharu!\n"${video.title}" oleh ${video.author || 'Penulis'} telah ditambah dalam kategori ${video.categories?.name || 'Kategori Umum'}.`,
        metadata: {
          title: '📹 Kitab Video Baharu!',
          body: `"${video.title}" oleh ${video.author || 'Penulis'} telah ditambah dalam kategori ${video.categories?.name || 'Kategori Umum'}.`,
          type: 'content_published',
          content_type: 'video_kitab',
          content_id: video.id,
          icon: '📹',
          action_url: '/kitab',
          source: 'unified_notifications',
          created_at: new Date().toISOString(),
          target_roles: ['student'],
          student_count: studentCount,
          is_global: true
        },
        status: 'unread',
        delivered_at: new Date().toISOString(),
        target_criteria: {
          unified_notification: true,
          target_all_students: true,
          content_type: 'video_kitab',
          approach: 'unified_table_system',
          global_user_id: 'null_for_global'
        }
      };

      const { error } = await supabaseClient.from('user_notifications').insert(unifiedNotification);

      if (error) {
        console.error(`❌ Error creating unified notification for ${video.title}:`, error);
        // Log the full error details
        console.error('Full error details:', JSON.stringify(error, null, 2));
      } else {
        notificationsCreated++;
        contentFound.push(`Video Kitab: ${video.title}`);
        console.log(`✅ Created unified notification for: ${video.title}`);
        console.log(`📊 Total notifications created so far: ${notificationsCreated}`);
      }
    }
  } else {
    console.log('📹 No new video kitabs found in time range');
  }

  // Check video_episodes
  console.log('🎬 Checking for new video episodes...');
  const { data: videoEpisodes, error: episodeError } = await supabaseClient
    .from('video_episodes')
    .select(`
      id, title, part_number, created_at, updated_at,
      video_kitab (id, title, categories (name))
    `)
    .eq('is_active', true)
    .gte('updated_at', hoursAgo.toISOString())
    .order('created_at', { ascending: false });

  if (episodeError) {
    console.error('❌ Error fetching video episodes:', episodeError);
  }

  console.log(`📊 Episode query returned ${videoEpisodes?.length || 0} episodes`);

  if (videoEpisodes && videoEpisodes.length > 0) {
    console.log(`🎬 Found ${videoEpisodes.length} new video episodes`);

    for (const episode of videoEpisodes) {
      // Check if already notified - Simplified duplicate detection
      const { data: existingUnified } = await supabaseClient
        .from('user_notifications')
        .select('id')
        .is('user_id', null) // Global notifications only
        .eq('metadata->>content_id', episode.id.toString())
        .eq('metadata->>content_type', 'video_episode')
        .limit(1);

      if (existingUnified && existingUnified.length > 0) {
        console.log(`⏭️ Skipping episode ${episode.title} - already notified`);
        continue;
      }

      const unifiedNotification = {
        id: crypto.randomUUID(),
        user_id: GLOBAL_USER_ID,
        message: `🎬 Episode Baharu!\nEpisode ${episode.part_number}: "${episode.title}" telah ditambah dalam kitab "${episode.video_kitab?.title || 'Kitab'}".`,
        metadata: {
          title: '🎬 Episode Baharu!',
          body: `Episode ${episode.part_number}: "${episode.title}" telah ditambah dalam kitab "${episode.video_kitab?.title || 'Kitab'}".`,
          type: 'content_published',
          content_type: 'video_episode',
          content_id: episode.id,
          parent_kitab: episode.video_kitab?.title,
          episode_number: episode.part_number,
          icon: '🎬',
          action_url: '/kitab',
          source: 'unified_notifications',
          created_at: new Date().toISOString(),
          target_roles: ['student'],
          student_count: studentCount,
          is_global: true
        },
        status: 'unread',
        delivered_at: new Date().toISOString(),
        target_criteria: {
          unified_notification: true,
          target_all_students: true,
          content_type: 'video_episode',
          approach: 'unified_table_system',
          global_user_id: 'null_for_global'
        }
      };

      const { error } = await supabaseClient.from('user_notifications').insert(unifiedNotification);

      if (error) {
        console.error('❌ Error creating episode notification:', error);
      } else {
        notificationsCreated++;
        contentFound.push(`Video Episode: ${episode.title} (${episode.video_kitab?.title})`);
        console.log(`✅ Created unified notification for episode: ${episode.title}`);
      }
    }
  } else {
    console.log('🎬 No new video episodes found in time range');
  }

  // Check ebooks
  console.log('📚 Checking for new ebooks...');
  const { data: ebooks, error: ebookError } = await supabaseClient
    .from('ebooks')
    .select(`id, title, author, created_at, updated_at, categories (name)`)
    .eq('is_active', true)
    .gte('updated_at', hoursAgo.toISOString())
    .order('created_at', { ascending: false });

  if (ebookError) {
    console.error('❌ Error fetching ebooks:', ebookError);
  }

  console.log(`📊 Ebook query returned ${ebooks?.length || 0} ebooks`);

  if (ebooks && ebooks.length > 0) {
    console.log(`📚 Found ${ebooks.length} new ebooks`);

    for (const ebook of ebooks) {
      // Check if already notified
      const { data: existingUnified } = await supabaseClient
        .from('user_notifications')
        .select('id')
        .is('user_id', null) // Check for global notifications (NULL user_id)
        .contains('metadata', { content_id: ebook.id, content_type: 'ebook' })
        .limit(1);

      if (existingUnified && existingUnified.length > 0) {
        console.log(`⏭️ Skipping ebook ${ebook.title} - already notified`);
        continue;
      }

      const unifiedNotification = {
        id: crypto.randomUUID(),
        user_id: GLOBAL_USER_ID,
        message: `📚 E-Book Baharu!\n"${ebook.title}" oleh ${ebook.author || 'Penulis'} telah ditambah dalam kategori ${ebook.categories?.name || 'Kategori Umum'}.`,
        metadata: {
          title: '📚 E-Book Baharu!',
          body: `"${ebook.title}" oleh ${ebook.author || 'Penulis'} telah ditambah dalam kategori ${ebook.categories?.name || 'Kategori Umum'}.`,
          type: 'content_published',
          content_type: 'ebook',
          content_id: ebook.id,
          icon: '📚',
          action_url: '/ebook',
          source: 'unified_notifications',
          created_at: new Date().toISOString(),
          target_roles: ['student'],
          student_count: studentCount,
          is_global: true
        },
        status: 'unread',
        delivered_at: new Date().toISOString(),
        target_criteria: {
          unified_notification: true,
          target_all_students: true,
          content_type: 'ebook',
          approach: 'unified_table_system',
          global_user_id: 'null_for_global'
        }
      };

      const { error } = await supabaseClient.from('user_notifications').insert(unifiedNotification);

      if (error) {
        console.error('❌ Error creating ebook notification:', error);
      } else {
        notificationsCreated++;
        contentFound.push(`E-Book: ${ebook.title}`);
        console.log(`✅ Created unified notification for ebook: ${ebook.title}`);
      }
    }
  } else {
    console.log('📚 No new ebooks found in time range');
  }

  console.log(`🎯 Content check completed: ${notificationsCreated} notifications created`);
  return { created: notificationsCreated };
}

// Helper function for payment notifications
async function checkPaymentNotifications(supabaseClient: any, hoursAgo: Date, studentCount: number, paymentNotifications: string[]) {
  let notificationsCreated = 0;
  console.log('💳 Checking for recent successful payments...');

  // Check for successful payments in last N hours
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

    // Create individual notifications for each payment
    for (const payment of recentPayments) {
      // Check if already notified
      const { data: existingPaymentNotif } = await supabaseClient
        .from('user_notifications')
        .select('id')
        .eq('user_id', payment.user_id)
        .eq('metadata->>payment_id', payment.id)
        .eq('metadata->>type', 'payment_success')
        .limit(1);

      if (existingPaymentNotif && existingPaymentNotif.length > 0) {
        console.log(`⏭️ Skipping payment ${payment.id} - already notified`);
        continue;
      }

      // Create individual payment notification
      const paymentNotification = {
        id: crypto.randomUUID(),
        user_id: payment.user_id, // Individual notification
        message: `🎉 Pembayaran Berjaya!\nPembayaran sebanyak RM${payment.amount} untuk ${payment.plan_type} telah berjaya diproses.`,
        metadata: {
          title: '🎉 Pembayaran Berjaya!',
          body: `Pembayaran sebanyak RM${payment.amount} untuk ${payment.plan_type} telah berjaya diproses.`,
          type: 'payment_success',
          payment_id: payment.id,
          amount: payment.amount,
          plan_type: payment.plan_type,
          icon: '🎉',
          action_url: '/profile/subscription',
          source: 'unified_notifications',
          created_at: new Date().toISOString(),
          target_roles: ['student'],
          is_global: false
        },
        status: 'unread',
        delivered_at: new Date().toISOString(),
        target_criteria: {
          individual_notification: true,
          payment_notification: true,
          approach: 'unified_table_system'
        }
      };

      const { error } = await supabaseClient.from('user_notifications').insert(paymentNotification);

      if (error) {
        console.error('Error creating payment notification:', error);
      } else {
        notificationsCreated++;
        paymentNotifications.push(`Payment Success: RM${payment.amount} - ${payment.profiles?.full_name || payment.profiles?.email}`);
        console.log(`✅ Created payment notification for: ${payment.id}`);
      }
    }
  }

  return { created: notificationsCreated };
}

// Helper function for subscription notifications
async function checkSubscriptionNotifications(supabaseClient: any, studentCount: number, subscriptionNotifications: string[]) {
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
    .gte('expires_at', new Date().toISOString()) // Not yet expired
    .order('expires_at', { ascending: true });

  if (expiringSubs && expiringSubs.length > 0) {
    console.log(`⏰ Found ${expiringSubs.length} expiring subscriptions`);

    for (const subscription of expiringSubs) {
      // Check if already notified in last 24 hours
      const oneDayAgo = new Date();
      oneDayAgo.setDate(oneDayAgo.getDate() - 1);

      const { data: existingExpiryNotif } = await supabaseClient
        .from('user_notifications')
        .select('id')
        .eq('user_id', subscription.user_id)
        .eq('metadata->>subscription_id', subscription.id)
        .eq('metadata->>type', 'subscription_expiring')
        .gte('delivered_at', oneDayAgo.toISOString())
        .limit(1);

      if (existingExpiryNotif && existingExpiryNotif.length > 0) {
        console.log(`⏭️ Skipping subscription ${subscription.id} - already notified recently`);
        continue;
      }

      // Calculate days until expiry
      const expiryDate = new Date(subscription.expires_at);
      const today = new Date();
      const daysUntilExpiry = Math.ceil((expiryDate.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));

      const expiryNotification = {
        id: crypto.randomUUID(),
        user_id: subscription.user_id, // Individual notification
        message: `⏰ Pelan Akan Tamat!\nPelan ${subscription.plan_type} anda akan tamat dalam ${daysUntilExpiry} hari. Sila buat pembaharuan untuk terus menikmati perkhidmatan.`,
        metadata: {
          title: '⏰ Pelan Akan Tamat!',
          body: `Pelan ${subscription.plan_type} anda akan tamat dalam ${daysUntilExpiry} hari. Sila buat pembaharuan untuk terus menikmati perkhidmatan.`,
          type: 'subscription_expiring',
          subscription_id: subscription.id,
          plan_type: subscription.plan_type,
          expires_at: subscription.expires_at,
          days_until_expiry: daysUntilExpiry,
          icon: '⏰',
          action_url: '/profile/subscription',
          source: 'unified_notifications',
          created_at: new Date().toISOString(),
          target_roles: ['student'],
          is_global: false
        },
        status: 'unread',
        delivered_at: new Date().toISOString(),
        target_criteria: {
          individual_notification: true,
          subscription_notification: true,
          approach: 'unified_table_system'
        }
      };

      const { error } = await supabaseClient.from('user_notifications').insert(expiryNotification);

      if (error) {
        console.error('Error creating subscription notification:', error);
      } else {
        notificationsCreated++;
        subscriptionNotifications.push(`Expiry Warning: ${subscription.plan_type} - ${daysUntilExpiry} days - ${subscription.profiles?.full_name || subscription.profiles?.email}`);
        console.log(`✅ Created expiry notification for: ${subscription.id} (${daysUntilExpiry} days)`);
      }
    }
  }

  // Check for recently expired subscriptions
  const { data: recentlyExpired } = await supabaseClient
    .from('user_subscriptions')
    .select(`
      id,
      user_id,
      plan_type,
      expires_at,
      status,
      profiles (email, full_name)
    `)
    .eq('status', 'expired')
    .gte('expires_at', new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()) // Expired in last 24 hours
    .order('expires_at', { ascending: false });

  if (recentlyExpired && recentlyExpired.length > 0) {
    console.log(`📋 Found ${recentlyExpired.length} recently expired subscriptions`);

    for (const expiredSub of recentlyExpired) {
      // Check if already notified
      const { data: existingExpiredNotif } = await supabaseClient
        .from('user_notifications')
        .select('id')
        .eq('user_id', expiredSub.user_id)
        .eq('metadata->>subscription_id', expiredSub.id)
        .eq('metadata->>type', 'subscription_expired')
        .limit(1);

      if (existingExpiredNotif && existingExpiredNotif.length > 0) {
        console.log(`⏭️ Skipping expired subscription ${expiredSub.id} - already notified`);
        continue;
      }

      const expiredNotification = {
        id: crypto.randomUUID(),
        user_id: expiredSub.user_id,
        message: `📋 Pelan Telah Tamat\nPelan ${expiredSub.plan_type} anda telah tamat. Sila buat pembaharuan untuk terus mengakses kandungan premium.`,
        metadata: {
          title: '📋 Pelan Telah Tamat',
          body: `Pelan ${expiredSub.plan_type} anda telah tamat. Sila buat pembaharuan untuk terus mengakses kandungan premium.`,
          type: 'subscription_expired',
          subscription_id: expiredSub.id,
          plan_type: expiredSub.plan_type,
          expired_at: expiredSub.expires_at,
          icon: '📋',
          action_url: '/profile/subscription',
          source: 'unified_notifications',
          created_at: new Date().toISOString(),
          target_roles: ['student'],
          is_global: false
        },
        status: 'unread',
        delivered_at: new Date().toISOString(),
        target_criteria: {
          individual_notification: true,
          subscription_notification: true,
          approach: 'unified_table_system'
        }
      };

      const { error } = await supabaseClient.from('user_notifications').insert(expiredNotification);

      if (error) {
        console.error('Error creating expired notification:', error);
      } else {
        notificationsCreated++;
        subscriptionNotifications.push(`Expired: ${expiredSub.plan_type} - ${expiredSub.profiles?.full_name || expiredSub.profiles?.email}`);
        console.log(`✅ Created expired notification for: ${expiredSub.id}`);
      }
    }
  }

  return { created: notificationsCreated };
}
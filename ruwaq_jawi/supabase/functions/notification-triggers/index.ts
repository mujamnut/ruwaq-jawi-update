import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface NotificationTrigger {
  type: 'payment_success' | 'content_published' | 'subscription_expiring' | 'admin_announcement' | 'system_maintenance' | 'inactive_user_engagement' | 'daily_content_check';
  data: any;
  target_users?: string[]; // Specific user IDs, if null = all users
  target_roles?: string[]; // Target specific roles: 'student', 'admin'
  target_subscription?: string[]; // Target subscription status: 'active', 'inactive', 'expired'
  target_criteria?: Record<string, any>; // Flexible targeting criteria
  purchase_id?: string; // For purchase-specific notifications
}

interface NotificationData {
  title: string;
  body: string;
  type: string;
  data?: any;
  icon?: string;
  action_url?: string;
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    console.log('🔔 Notification trigger endpoint called');

    // Initialize Supabase client with service role key for admin access
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    // Parse trigger payload
    const trigger: NotificationTrigger = await req.json();

    console.log('🔔 Notification trigger received:', JSON.stringify(trigger));

    let notificationData: NotificationData;
    let targetUserIds: string[] = [];

    // Process different trigger types
    switch (trigger.type) {
      case 'payment_success':
        notificationData = await handlePaymentSuccess(supabaseClient, trigger);
        targetUserIds = trigger.target_users || [];
        break;

      case 'content_published':
        notificationData = await handleContentPublished(supabaseClient, trigger);
        targetUserIds = await getTargetUsers(supabaseClient, trigger);
        break;

      case 'subscription_expiring':
        notificationData = await handleSubscriptionExpiring(supabaseClient, trigger);
        targetUserIds = await getTargetUsers(supabaseClient, trigger);
        break;

      case 'admin_announcement':
        notificationData = await handleAdminAnnouncement(supabaseClient, trigger);
        targetUserIds = await getTargetUsers(supabaseClient, trigger);
        break;

      case 'system_maintenance':
        notificationData = await handleSystemMaintenance(supabaseClient, trigger);
        targetUserIds = await getTargetUsers(supabaseClient, trigger);
        break;

      case 'inactive_user_engagement':
        notificationData = await handleInactiveUserEngagement(supabaseClient, trigger);
        targetUserIds = trigger.target_users || [];
        break;

      case 'daily_content_check':
        const contentResults = await handleDailyContentCheck(supabaseClient, trigger);
        if (contentResults.length === 0) {
          return new Response(
            JSON.stringify({
              success: true,
              message: 'No new content found in the specified time period',
              target_users_count: 0
            }),
            {
              headers: { ...corsHeaders, 'Content-Type': 'application/json' },
              status: 200,
            },
          );
        }

        // Send notifications for all new content found
        let totalNotificationsSent = 0;
        for (const contentItem of contentResults) {
          const contentTargetUsers = await getTargetUsers(supabaseClient, {
            ...trigger,
            data: contentItem.data
          });
          await sendToUsers(supabaseClient, contentItem.notification, contentTargetUsers, trigger.target_criteria);
          totalNotificationsSent += contentTargetUsers.length;
        }

        return new Response(
          JSON.stringify({
            success: true,
            message: `Found ${contentResults.length} new content items, sent ${totalNotificationsSent} notifications`,
            content_items: contentResults.length,
            target_users_count: totalNotificationsSent
          }),
          {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
          },
        );

      default:
        throw new Error(`Unknown notification type: ${trigger.type}`);
    }

    // Send notification directly to target users
    await sendToUsers(supabaseClient, notificationData, targetUserIds, trigger.target_criteria, trigger.purchase_id);

    console.log(`✅ Notification sent to ${targetUserIds.length} users`);

    return new Response(
      JSON.stringify({
        success: true,
        message: `Notification sent to ${targetUserIds.length} users`,
        target_users_count: targetUserIds.length
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    );
  } catch (error) {
    console.error('❌ Notification trigger error:', error);

    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      },
    );
  }
});

// Handle payment success notification
async function handlePaymentSuccess(supabaseClient: any, trigger: NotificationTrigger): Promise<NotificationData> {
  const { user_id, payment_id, amount, reference_number } = trigger.data;

  return {
    title: '🎉 Pembayaran Berjaya!',
    body: `Pembayaran anda sebanyak RM${amount} telah berjaya diproses. Terima kasih!`,
    type: 'payment_success',
    icon: '✅',
    action_url: '/subscription',
    data: {
      payment_id,
      amount,
      reference_number,
      user_id
    }
  };
}

// Handle new content published notification
async function handleContentPublished(supabaseClient: any, trigger: NotificationTrigger): Promise<NotificationData> {
  const { content_type, title, author, category, parent_kitab, episode_number } = trigger.data;

  let contentTypeText = '';
  let icon = '';
  let body = '';
  let actionUrl = '';

  switch (content_type) {
    case 'video_kitab':
      contentTypeText = 'Kitab Video';
      icon = '📹';
      body = `"${title}" oleh ${author || 'Penulis'} telah ditambah dalam kategori ${category}.`;
      actionUrl = '/kitab';
      break;

    case 'video_episode':
      contentTypeText = 'Episode Baharu';
      icon = '🎬';
      body = `Episode ${episode_number}: "${title}" telah ditambah dalam kitab "${parent_kitab}".`;
      actionUrl = '/kitab';
      break;

    case 'ebook':
      contentTypeText = 'E-Book';
      icon = '📚';
      body = `"${title}" oleh ${author || 'Penulis'} telah ditambah dalam kategori ${category}.`;
      actionUrl = '/ebook';
      break;

    default:
      contentTypeText = 'Kandungan';
      icon = '📖';
      body = `"${title}" telah ditambah.`;
      actionUrl = '/home';
  }

  return {
    title: `${icon} ${contentTypeText} Baharu!`,
    body,
    type: 'content_published',
    icon,
    action_url: actionUrl,
    data: {
      content_type,
      title,
      author,
      category,
      parent_kitab,
      episode_number
    }
  };
}

// Handle subscription expiring notification
async function handleSubscriptionExpiring(supabaseClient: any, trigger: NotificationTrigger): Promise<NotificationData> {
  const { days_remaining, plan_name } = trigger.data;

  return {
    title: '⏰ Langganan Akan Tamat',
    body: `Langganan ${plan_name} anda akan tamat dalam ${days_remaining} hari. Sila perbaharui untuk terus menikmati kandungan premium.`,
    type: 'subscription_expiring',
    icon: '⚠️',
    action_url: '/subscription',
    data: {
      days_remaining,
      plan_name
    }
  };
}

// Handle admin announcement notification
async function handleAdminAnnouncement(supabaseClient: any, trigger: NotificationTrigger): Promise<NotificationData> {
  const { title, message, priority } = trigger.data;

  const priorityIcon = priority === 'high' ? '🚨' : priority === 'medium' ? '📢' : 'ℹ️';

  return {
    title: `${priorityIcon} ${title}`,
    body: message,
    type: 'admin_announcement',
    icon: priorityIcon,
    action_url: '/notifications',
    data: {
      priority,
      admin_message: true
    }
  };
}

// Handle inactive user engagement notification
async function handleInactiveUserEngagement(supabaseClient: any, trigger: NotificationTrigger): Promise<NotificationData> {
  const { user_name, days_inactive } = trigger.data;

  return {
    title: '👋 Kami Rindu Anda!',
    body: `Hai ${user_name || 'Pengguna'}! Anda tidak aktif selama ${days_inactive} hari. Mari kembali belajar dengan kandungan terbaru kami.`,
    type: 'inactive_user_engagement',
    icon: '📚',
    action_url: '/home',
    data: {
      days_inactive,
      re_engagement: true
    }
  };
}

// Handle system maintenance notification
async function handleSystemMaintenance(supabaseClient: any, trigger: NotificationTrigger): Promise<NotificationData> {
  const { scheduled_time, duration, description } = trigger.data;

  return {
    title: '🔧 Penyelenggaraan Sistem',
    body: `Sistem akan diselenggara pada ${scheduled_time} selama ${duration}. ${description}`,
    type: 'system_maintenance',
    icon: '🔧',
    action_url: '/notifications',
    data: {
      scheduled_time,
      duration,
      description
    }
  };
}

// Handle daily content check - find new content published in the last X hours
async function handleDailyContentCheck(supabaseClient: any, trigger: NotificationTrigger): Promise<Array<{notification: NotificationData, data: any}>> {
  const { check_hours = 24, content_types = ['video_kitab', 'video_episodes', 'ebooks'] } = trigger.data;
  const hoursAgo = new Date();
  hoursAgo.setHours(hoursAgo.getHours() - check_hours);

  const results = [];

  // Check video_kitab table
  if (content_types.includes('video_kitab')) {
    const { data: videoKitabs, error } = await supabaseClient
      .from('video_kitab')
      .select(`
        id, title, author, is_active, created_at, updated_at,
        categories (name)
      `)
      .eq('is_active', true)
      .or(`created_at.gte.${hoursAgo.toISOString()},updated_at.gte.${hoursAgo.toISOString()}`)
      .order('created_at', { ascending: false });

    if (!error && videoKitabs) {
      for (const video of videoKitabs) {
        const notification = await handleContentPublished(supabaseClient, {
          type: 'content_published',
          data: {
            content_type: 'video_kitab',
            title: video.title,
            author: video.author || 'Penulis',
            category: video.categories?.name || 'Kategori Umum'
          }
        } as NotificationTrigger);

        results.push({
          notification,
          data: {
            content_type: 'video_kitab',
            title: video.title,
            author: video.author || 'Penulis',
            category: video.categories?.name || 'Kategori Umum'
          }
        });
      }
    }
  }

  // Check video_episodes table
  if (content_types.includes('video_episodes')) {
    const { data: episodes, error } = await supabaseClient
      .from('video_episodes')
      .select(`
        id, title, part_number, is_active, created_at, updated_at,
        video_kitab (
          title,
          categories (name)
        )
      `)
      .eq('is_active', true)
      .or(`created_at.gte.${hoursAgo.toISOString()},updated_at.gte.${hoursAgo.toISOString()}`)
      .order('created_at', { ascending: false });

    if (!error && episodes) {
      for (const episode of episodes) {
        const notification = await handleContentPublished(supabaseClient, {
          type: 'content_published',
          data: {
            content_type: 'video_episode',
            title: episode.title,
            author: 'Penulis',
            category: episode.video_kitab?.categories?.name || 'Kategori Umum',
            parent_kitab: episode.video_kitab?.title,
            episode_number: episode.part_number
          }
        } as NotificationTrigger);

        results.push({
          notification,
          data: {
            content_type: 'video_episode',
            title: episode.title,
            author: 'Penulis',
            category: episode.video_kitab?.categories?.name || 'Kategori Umum',
            parent_kitab: episode.video_kitab?.title,
            episode_number: episode.part_number
          }
        });
      }
    }
  }

  // Check ebooks table
  if (content_types.includes('ebooks')) {
    const { data: ebooks, error } = await supabaseClient
      .from('ebooks')
      .select(`
        id, title, author, is_active, created_at, updated_at,
        categories (name)
      `)
      .eq('is_active', true)
      .or(`created_at.gte.${hoursAgo.toISOString()},updated_at.gte.${hoursAgo.toISOString()}`)
      .order('created_at', { ascending: false });

    if (!error && ebooks) {
      for (const ebook of ebooks) {
        const notification = await handleContentPublished(supabaseClient, {
          type: 'content_published',
          data: {
            content_type: 'ebook',
            title: ebook.title,
            author: ebook.author || 'Penulis',
            category: ebook.categories?.name || 'Kategori Umum'
          }
        } as NotificationTrigger);

        results.push({
          notification,
          data: {
            content_type: 'ebook',
            title: ebook.title,
            author: ebook.author || 'Penulis',
            category: ebook.categories?.name || 'Kategori Umum'
          }
        });
      }
    }
  }

  console.log(`🔍 Daily content check found ${results.length} new content items in the last ${check_hours} hours`);

  return results;
}

// Get target users based on criteria
async function getTargetUsers(supabaseClient: any, trigger: NotificationTrigger): Promise<string[]> {
  // If specific users are targeted, use those instead
  if (trigger.target_users && trigger.target_users.length > 0) {
    return trigger.target_users;
  }

  let query = supabaseClient.from('profiles').select('id, updated_at, last_seen_at, role');

  // Filter by roles
  if (trigger.target_roles && trigger.target_roles.length > 0) {
    query = query.in('role', trigger.target_roles);
  }

  // Filter by subscription status - check user_subscriptions table
  if (trigger.target_subscription && trigger.target_subscription.length > 0) {
    // Join with user_subscriptions to check active subscriptions
    const { data: activeUsers, error: subError } = await supabaseClient
      .from('user_subscriptions')
      .select('user_id')
      .in('status', trigger.target_subscription)
      .gt('end_date', new Date().toISOString());

    if (subError) {
      console.error('Error fetching subscription users:', subError);
      return [];
    }

    const activeUserIds = activeUsers.map(u => u.user_id);
    if (activeUserIds.length === 0) return [];

    query = query.in('id', activeUserIds);
  }

  // Apply additional filtering based on target_criteria
  if (trigger.target_criteria) {
    const criteria = trigger.target_criteria;

    // Filter by purchase history - check user_subscriptions table
    if (criteria.has_purchased && criteria.plan_id) {
      const { data: purchasedUsers, error: purchaseError } = await supabaseClient
        .from('user_subscriptions')
        .select('user_id')
        .eq('subscription_plan_id', criteria.plan_id);

      if (purchaseError) {
        console.error('Error fetching purchased users:', purchaseError);
        return [];
      }

      const purchasedUserIds = purchasedUsers.map(u => u.user_id);
      if (purchasedUserIds.length === 0) return [];

      query = query.in('id', purchasedUserIds);
    }

    // Filter by activity level (using last_seen_at if available, otherwise updated_at)
    if (criteria.inactive_days) {
      const daysAgo = new Date();
      daysAgo.setDate(daysAgo.getDate() - criteria.inactive_days);

      // Use a complex filter to handle both last_seen_at and updated_at
      const { data: users, error } = await query;
      if (error) {
        console.error('Error fetching users for activity filter:', error);
        return [];
      }

      const activeUserIds = users
        .filter(user => {
          const lastActivity = user.last_seen_at ? new Date(user.last_seen_at) : new Date(user.updated_at);
          return lastActivity < daysAgo;
        })
        .map(user => user.id);

      return activeUserIds;
    }

    // Filter by content engagement
    if (criteria.content_category_id) {
      // This would require joining with user activity tables
      // For now, we'll return all matching users
    }
  }

  const { data: users, error } = await query;

  if (error) {
    console.error('Error fetching target users:', error);
    return [];
  }

  return users.map(user => user.id);
}

// Send notification using enhanced system with fallback to legacy
async function sendToUsers(
  supabaseClient: any,
  notificationData: NotificationData,
  userIds: string[],
  targetCriteria?: Record<string, any>,
  purchaseId?: string
): Promise<void> {
  if (userIds.length === 0) {
    // Empty userIds means broadcast to all matching criteria
    await sendBroadcastNotification(supabaseClient, notificationData, targetCriteria);
    return;
  }

  // Determine if this should be a broadcast or personal notifications
  const isBroadcast = userIds.length > 5; // Threshold for broadcast vs individual

  if (isBroadcast) {
    // Use enhanced system for broadcast notifications
    await sendBroadcastNotification(supabaseClient, notificationData, targetCriteria);
  } else {
    // Use enhanced system for personal notifications
    await sendPersonalNotifications(supabaseClient, notificationData, userIds, targetCriteria, purchaseId);
  }
}

// Send broadcast notification using new system
async function sendBroadcastNotification(
  supabaseClient: any,
  notificationData: NotificationData,
  targetCriteria?: Record<string, any>
): Promise<void> {
  try {
    console.log('🔄 Attempting to use enhanced notification system for broadcast...');

    // Try new system first
    const { data, error } = await supabaseClient.rpc('create_broadcast_notification', {
      p_title: notificationData.title,
      p_message: notificationData.body,
      p_metadata: {
        icon: notificationData.icon,
        action_url: notificationData.action_url,
        type: notificationData.type,
        data: notificationData.data || {},
        created_at: new Date().toISOString(),
        source: 'edge_function_enhanced'
      },
      p_target_roles: ['student'] // Default to students
    });

    if (error) {
      throw error;
    }

    console.log('✅ Broadcast notification created using enhanced system');
    return;

  } catch (error) {
    console.log('⚠️ Enhanced system failed, falling back to legacy:', error);

    // Fallback to legacy system
    await sendToUsersLegacy(supabaseClient, notificationData, [], targetCriteria);
  }
}

// Send personal notifications using new system
async function sendPersonalNotifications(
  supabaseClient: any,
  notificationData: NotificationData,
  userIds: string[],
  targetCriteria?: Record<string, any>,
  purchaseId?: string
): Promise<void> {
  try {
    console.log('🔄 Attempting to use enhanced notification system for personal notifications...');

    // Send to each user individually using new system
    for (const userId of userIds) {
      const { data, error } = await supabaseClient.rpc('create_personal_notification', {
        p_user_id: userId,
        p_title: notificationData.title,
        p_message: notificationData.body,
        p_metadata: {
          icon: notificationData.icon,
          action_url: notificationData.action_url,
          type: notificationData.type,
          data: notificationData.data || {},
          created_at: new Date().toISOString(),
          source: 'edge_function_enhanced',
          purchase_id: purchaseId
        }
      });

      if (error) {
        throw error;
      }
    }

    console.log('✅ Personal notifications created using enhanced system');
    return;

  } catch (error) {
    console.log('⚠️ Enhanced system failed, falling back to legacy:', error);

    // Fallback to legacy system
    await sendToUsersLegacy(supabaseClient, notificationData, userIds, targetCriteria, purchaseId);
  }
}

// Legacy notification sending (unchanged for backward compatibility)
async function sendToUsersLegacy(
  supabaseClient: any,
  notificationData: NotificationData,
  userIds: string[],
  targetCriteria?: Record<string, any>,
  purchaseId?: string
): Promise<void> {
  console.log('📬 Using legacy notification system...');

  // For broadcast notifications in legacy system, use null user_id
  if (userIds.length === 0) {
    // Broadcast notification
    const metadata = {
      title: notificationData.title,
      body: notificationData.body,
      type: notificationData.type,
      icon: notificationData.icon,
      action_url: notificationData.action_url,
      data: notificationData.data || {},
      created_at: new Date().toISOString(),
      source: 'edge_function_legacy',
      target_roles: ['student']
    };

    const { error } = await supabaseClient
      .from('user_notifications')
      .insert({
        user_id: null, // Global notification
        message: `${notificationData.title}\n${notificationData.body}`,
        metadata: metadata,
        delivered_at: new Date().toISOString(),
        target_criteria: targetCriteria || {}
      });

    if (error) {
      throw new Error(`Failed to send broadcast notification: ${error.message}`);
    }

    console.log('📬 Broadcast notification delivered using legacy system');
    return;
  }

  // Personal notifications
  const message = `${notificationData.title}\n${notificationData.body}`;

  const metadata = {
    title: notificationData.title,
    body: notificationData.body,
    type: notificationData.type,
    icon: notificationData.icon,
    action_url: notificationData.action_url,
    data: notificationData.data || {},
    created_at: new Date().toISOString(),
    source: 'edge_function_legacy'
  };

  const userNotifications = userIds.map(userId => ({
    user_id: userId,
    message: message,
    metadata: metadata,
    delivered_at: new Date().toISOString(),
    target_criteria: targetCriteria || {},
    purchase_id: purchaseId || null
  }));

  const { error } = await supabaseClient
    .from('user_notifications')
    .insert(userNotifications);

  if (error) {
    throw new Error(`Failed to send notifications: ${error.message}`);
  }

  console.log(`📬 Personal notifications delivered to ${userIds.length} users using legacy system`);
}
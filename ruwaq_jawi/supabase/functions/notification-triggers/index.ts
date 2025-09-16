import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface NotificationTrigger {
  type: 'payment_success' | 'content_published' | 'subscription_expiring' | 'admin_announcement' | 'system_maintenance' | 'inactive_user_engagement';
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

// Get target users based on criteria
async function getTargetUsers(supabaseClient: any, trigger: NotificationTrigger): Promise<string[]> {
  let query = supabaseClient.from('profiles').select('id, last_seen_at, subscription_status, role');

  // Filter by roles
  if (trigger.target_roles && trigger.target_roles.length > 0) {
    query = query.in('role', trigger.target_roles);
  }

  // Filter by subscription status
  if (trigger.target_subscription && trigger.target_subscription.length > 0) {
    query = query.in('subscription_status', trigger.target_subscription);
  }

  // If specific users are targeted, use those instead
  if (trigger.target_users && trigger.target_users.length > 0) {
    return trigger.target_users;
  }

  // Apply additional filtering based on target_criteria
  if (trigger.target_criteria) {
    const criteria = trigger.target_criteria;

    // Filter by purchase history
    if (criteria.has_purchased && criteria.plan_id) {
      query = query.not('subscription_plan_id', 'is', null);
      if (criteria.plan_id !== 'any') {
        query = query.eq('subscription_plan_id', criteria.plan_id);
      }
    }

    // Filter by activity level
    if (criteria.inactive_days) {
      const daysAgo = new Date();
      daysAgo.setDate(daysAgo.getDate() - criteria.inactive_days);
      query = query.or(`last_seen_at.is.null,last_seen_at.lt.${daysAgo.toISOString()}`);
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

// Send notification directly to users (using existing user_notifications structure)
async function sendToUsers(
  supabaseClient: any,
  notificationData: NotificationData,
  userIds: string[],
  targetCriteria?: Record<string, any>,
  purchaseId?: string
): Promise<void> {
  if (userIds.length === 0) {
    console.log('No target users specified');
    return;
  }

  // Create message with title and body
  const message = `${notificationData.title}\n${notificationData.body}`;

  // Prepare metadata with all notification info
  const metadata = {
    title: notificationData.title,
    body: notificationData.body,
    type: notificationData.type,
    icon: notificationData.icon,
    action_url: notificationData.action_url,
    data: notificationData.data || {},
    created_at: new Date().toISOString()
  };

  const userNotifications = userIds.map(userId => ({
    user_id: userId,
    message: message,
    metadata: metadata,
    status: 'unread',
    delivery_status: 'delivered',
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

  console.log(`📬 Notifications delivered to ${userIds.length} users`);
}
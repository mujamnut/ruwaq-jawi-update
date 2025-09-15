import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface NotificationTrigger {
  type: 'payment_success' | 'content_published' | 'subscription_expiring' | 'admin_announcement' | 'system_maintenance';
  data: any;
  target_users?: string[]; // Specific user IDs, if null = all users
  target_roles?: string[]; // Target specific roles: 'student', 'admin'
  target_subscription?: string[]; // Target subscription status: 'active', 'inactive', 'expired'
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

      default:
        throw new Error(`Unknown notification type: ${trigger.type}`);
    }

    // Send notification directly to target users
    await sendToUsers(supabaseClient, notificationData, targetUserIds);

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
  const { user_id, plan_name, amount, bill_id } = trigger.data;

  return {
    title: '🎉 Pembayaran Berjaya!',
    body: `Langganan ${plan_name} anda telah diaktifkan. Terima kasih atas pembayaran RM${amount}.`,
    type: 'payment_success',
    icon: '✅',
    action_url: '/subscription',
    data: {
      bill_id,
      amount,
      plan_name,
      user_id
    }
  };
}

// Handle new content published notification
async function handleContentPublished(supabaseClient: any, trigger: NotificationTrigger): Promise<NotificationData> {
  const { content_type, title, author, category } = trigger.data;

  const contentTypeText = content_type === 'video_kitab' ? 'Kitab Video' : 'E-Book';
  const icon = content_type === 'video_kitab' ? '📹' : '📚';

  return {
    title: `${icon} ${contentTypeText} Baharu!`,
    body: `"${title}" oleh ${author || 'Penulis'} telah ditambah dalam kategori ${category}.`,
    type: 'content_published',
    icon,
    action_url: content_type === 'video_kitab' ? '/kitab' : '/ebook',
    data: {
      content_type,
      title,
      author,
      category
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
  let query = supabaseClient.from('profiles').select('id');

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

  const { data: users, error } = await query;

  if (error) {
    console.error('Error fetching target users:', error);
    return [];
  }

  return users.map(user => user.id);
}

// Send notification directly to users (using existing user_notifications structure)
async function sendToUsers(supabaseClient: any, notificationData: NotificationData, userIds: string[]): Promise<void> {
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
    delivered_at: new Date().toISOString()
  }));

  const { error } = await supabaseClient
    .from('user_notifications')
    .insert(userNotifications);

  if (error) {
    throw new Error(`Failed to send notifications: ${error.message}`);
  }

  console.log(`📬 Notifications delivered to ${userIds.length} users`);
}
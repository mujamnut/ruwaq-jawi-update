# 🔔 Notification System Guide

Sistem notifikasi automatik untuk Maktabah Ruwaq Jawi app dengan berbagai trigger events.

## 📋 Overview

Sistem ini menggunakan:
- **Edge Function**: `notification-triggers` untuk memproses dan menghantar notifikasi
- **Database Triggers**: Auto-trigger untuk content baru
- **Webhook Integration**: Notifikasi payment success/failure
- **Manual Functions**: Admin announcements & maintenance alerts

## 🚀 Available Notification Types

### 1. **Payment Success** 💳✅
**Auto-triggered** ketika payment berjaya via webhook

```typescript
// Triggered automatically in payment-webhook
{
  type: 'payment_success',
  data: {
    user_id: 'uuid',
    plan_name: 'Premium',
    amount: 29.90,
    bill_id: 'TPY123456'
  },
  target_users: ['specific-user-id']
}
```

### 2. **New Content Published** 📚📹
**Auto-triggered** ketika content baru di-activate

```sql
-- Triggered automatically when:
-- video_kitab or ebooks is_active = true
-- Sends to all active subscribers
```

### 3. **Subscription Expiring** ⏰
**Manual trigger** via cron job (daily)

```sql
-- Run this daily (e.g., via cron or scheduled function)
SELECT check_expiring_subscriptions();
```

### 4. **Admin Announcements** 📢
**Manual trigger** oleh admin

```sql
-- Send announcement to students
SELECT send_admin_announcement(
  'Pengumuman Penting',
  'Sistem akan diselenggara esok pagi dari 2am-4am',
  'high',
  ARRAY['student'],
  ARRAY['active', 'inactive']
);
```

### 5. **System Maintenance** 🔧
**Manual trigger** sebelum maintenance

```sql
-- Send maintenance notification
SELECT send_maintenance_notification(
  '2 Januari 2025, 2:00 AM - 4:00 AM',
  '2 jam',
  'Penyelenggaraan server dan database untuk meningkatkan prestasi'
);
```

## 🛠️ Setup Instructions

### 1. Deploy Edge Function
```bash
# Already deployed as 'notification-triggers'
# URL: https://your-project.supabase.co/functions/v1/notification-triggers
```

### 2. Setup Database Environment
```sql
-- Set in your Supabase SQL editor or environment
ALTER DATABASE postgres SET app.supabase_url = 'https://your-project.supabase.co';
ALTER DATABASE postgres SET app.service_role_key = 'your-service-role-key';
```

### 3. Run Migration
```bash
# Apply notification triggers
supabase db reset
# OR apply specific migration
psql -f database/migrations/020_notification_triggers.sql
```

### 4. Setup Cron Job for Expiring Subscriptions
```sql
-- Create a cron job (if pg_cron is available)
-- Or schedule this to run daily via external cron
SELECT cron.schedule(
  'check-expiring-subscriptions',
  '0 9 * * *', -- Daily at 9 AM
  'SELECT check_expiring_subscriptions();'
);
```

## 📱 Frontend Integration

### Update NotificationsProvider
```dart
// In lib/core/providers/notifications_provider.dart
// Add refresh after new notifications
void listenForNewNotifications() {
  // Listen to real-time updates
  _supabase
    .from('user_notifications')
    .stream(primaryKey: ['id'])
    .eq('user_id', currentUserId)
    .listen((data) {
      loadInbox(); // Refresh notifications
    });
}
```

### Show Notification Badge
```dart
// In StudentBottomNav or AppBar
Consumer<NotificationsProvider>(
  builder: (context, notifProvider, child) {
    return Badge(
      isLabelVisible: notifProvider.unreadCount > 0,
      label: Text('${notifProvider.unreadCount}'),
      child: IconButton(
        icon: PhosphorIcon(PhosphorIcons.bell()),
        onPressed: () => context.push('/notifications'),
      ),
    );
  },
)
```

## 🧪 Testing Examples

### Test Payment Success Notification
```bash
curl -X POST https://your-project.supabase.co/functions/v1/notification-triggers \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "payment_success",
    "data": {
      "user_id": "test-user-id",
      "plan_name": "Premium",
      "amount": 29.90,
      "bill_id": "TEST123"
    },
    "target_users": ["test-user-id"]
  }'
```

### Test Content Published Notification
```sql
-- Insert new active video kitab to trigger notification
INSERT INTO video_kitab (
  id, title, author, category_id, is_active, created_at, updated_at
) VALUES (
  'test-kitab-id',
  'Kitab Test Baru',
  'Ustaz Test',
  'some-category-id',
  true,
  NOW(),
  NOW()
);
```

### Test Admin Announcement
```sql
SELECT send_admin_announcement(
  'Testing Notification',
  'Ini adalah test pengumuman admin',
  'medium',
  ARRAY['student'],
  ARRAY['active']
);
```

## 📊 Monitoring & Logs

### Check Edge Function Logs
```bash
# View notification-triggers function logs
supabase functions logs notification-triggers
```

### Check Database Trigger Logs
```sql
-- Check recent notifications sent
SELECT
  n.title,
  n.body,
  n.type,
  n.created_at,
  COUNT(un.id) as sent_to_users
FROM notifications n
LEFT JOIN user_notifications un ON n.id = un.notification_id
WHERE n.created_at >= NOW() - INTERVAL '24 hours'
GROUP BY n.id, n.title, n.body, n.type, n.created_at
ORDER BY n.created_at DESC;
```

### Monitor User Notifications
```sql
-- Check user's notification inbox
SELECT
  n.title,
  n.body,
  n.type,
  un.delivered_at,
  un.read_at
FROM user_notifications un
JOIN notifications n ON un.notification_id = n.id
WHERE un.user_id = 'specific-user-id'
ORDER BY un.delivered_at DESC;
```

## 🔧 Troubleshooting

### Common Issues

1. **Notifications not sending**
   - Check environment variables (supabase_url, service_role_key)
   - Verify edge function is deployed and active
   - Check function logs for errors

2. **Database triggers not firing**
   - Ensure triggers are created properly
   - Check if net.http_post is available (may need to enable)
   - Verify database settings

3. **Users not receiving notifications**
   - Check if user exists in profiles table
   - Verify target_roles and target_subscription filters
   - Check user_notifications table for delivery status

### Manual Recovery
```sql
-- Manually send notification to specific user
INSERT INTO user_notifications (user_id, notification_id, delivered_at)
SELECT
  'user-id-here',
  'notification-id-here',
  NOW();
```

## 📈 Future Enhancements

- Push notifications (FCM/APNs)
- Email notifications
- SMS notifications
- Notification preferences per user
- Rich notifications with images
- Scheduled notifications
- A/B testing for notification content

## 🔗 Related Files

- `supabase/functions/notification-triggers/index.ts` - Main notification processor
- `database/migrations/020_notification_triggers.sql` - Database triggers & functions
- `lib/core/providers/notifications_provider.dart` - Frontend notification management
- `lib/features/student/screens/notification_screen.dart` - Notification UI
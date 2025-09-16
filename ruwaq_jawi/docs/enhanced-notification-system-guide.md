# Enhanced Notification System Guide

## Overview
Sistem notifikasi yang telah dipertingkatkan untuk Maktabah Ruwaq Jawi dengan targeting yang lebih fleksibel dan pengkategorian yang lebih baik.

## Key Features

### 1. Flexible Targeting
- **Specific Users**: Target user ID tertentu
- **Role-based**: Target berdasarkan role (student/admin)
- **Subscription-based**: Target berdasarkan status subscription
- **Purchase-specific**: Notification berkaitan dengan pembelian tertentu
- **Activity-based**: Target berdasarkan tahap aktiviti user

### 2. Enhanced Database Structure

#### user_notifications Table (Enhanced)
```sql
- target_criteria JSONB -- Flexible targeting criteria
- purchase_id UUID -- Reference to specific purchase
- notification_id UUID -- Foreign key to notifications table
```

#### notifications Table
```sql
- id UUID -- Template notification ID
- title TEXT -- Notification title
- body TEXT -- Notification content
- type TEXT -- Notification type
- data JSONB -- Additional data
```

### 3. Notification Types

#### Core Types:
- `payment_success` - Payment berhasil
- `content_published` - Kandungan baru diterbitkan
- `subscription_expiring` - Subscription akan tamat
- `admin_announcement` - Pengumuman admin
- `system_maintenance` - Penyelenggaraan sistem
- `inactive_user_engagement` - Re-engagement untuk user tidak aktif

### 4. Targeting Examples

#### Payment-specific Notifications:
```json
{
  "type": "payment_success",
  "target_users": ["user_uuid"],
  "target_criteria": {
    "purchase_specific": true,
    "bill_id": "bill_uuid"
  },
  "purchase_id": "bill_uuid"
}
```

#### Role-based Content Notifications:
```json
{
  "type": "content_published",
  "target_roles": ["student"],
  "target_subscription": ["active"],
  "target_criteria": {
    "role_based": true,
    "content_specific": true
  }
}
```

#### Admin Announcements:
```json
{
  "type": "admin_announcement",
  "target_criteria": {
    "admin_announcement": true,
    "priority": "high",
    "target_all_users": true
  }
}
```

#### Re-engagement Notifications:
```json
{
  "type": "inactive_user_engagement",
  "target_users": ["inactive_user_uuid"],
  "target_criteria": {
    "re_engagement": true,
    "inactive_days": 7
  }
}
```

## Implementation

### 1. Database Migration
Run migration `022_enhance_notification_targeting.sql` untuk menambah kolom baru dan functions.

### 2. Edge Function
Updated `notification-triggers` function dengan:
- Enhanced targeting logic
- New notification types
- Flexible criteria processing

### 3. Flutter Model
Updated `UserNotificationItem` model dengan:
- New targeting fields
- Helper getters untuk notification types
- Enhanced filtering capabilities

### 4. Flutter Provider
Enhanced `NotificationsProvider` dengan:
- Type-specific getters
- Priority-based filtering
- Better categorization

## Triggers

### Purchase Notifications
Automatically triggered pada `bills` table ketika:
- Status berubah kepada 'paid'
- New bill dengan status 'paid' dibuat

### Content Published
Triggered pada `video_kitab` dan `ebooks` table ketika:
- New content dengan `is_active = true`
- Existing content activated (`is_active` changed to true)

### Subscription Expiry (Manual)
Function `trigger_subscription_expiry_check()` perlu dipanggil secara berkala untuk:
- Check subscription yang akan tamat dalam 3 hari
- Send warning notifications

### Inactive User Re-engagement (Manual)
Function `trigger_inactive_user_notification()` untuk:
- Find users tidak aktif lebih dari 7 hari
- Send re-engagement notifications

## Usage Examples

### Send Admin Announcement to All Students
```typescript
await supabase.functions.invoke('notification-triggers', {
  body: {
    type: 'admin_announcement',
    data: {
      title: 'Pengumuman Penting',
      message: 'Sistem akan diselenggara esok.',
      priority: 'high'
    },
    target_roles: ['student'],
    target_subscription: ['active'],
    target_criteria: {
      admin_announcement: true,
      priority: 'high'
    }
  }
});
```

### Send Content Notification to Specific Category Users
```typescript
await supabase.functions.invoke('notification-triggers', {
  body: {
    type: 'content_published',
    data: {
      content_type: 'video_kitab',
      title: 'Kitab Baru',
      author: 'Ustaz Ahmad',
      category: 'Fiqh'
    },
    target_roles: ['student'],
    target_subscription: ['active'],
    target_criteria: {
      content_specific: true,
      category: 'Fiqh'
    }
  }
});
```

## Maintenance

### Daily Tasks
- Run `trigger_subscription_expiry_check()` untuk subscription warnings
- Run `trigger_inactive_user_notification()` untuk re-engagement

### Weekly Tasks
- Review notification analytics
- Clean old notifications (optional)

## Benefits

1. **Targeted Messaging**: Hantar notification kepada user yang relevan sahaja
2. **Better Organization**: Kategori notification yang jelas
3. **Purchase Tracking**: Track notification berkaitan dengan purchase tertentu
4. **Admin Control**: Flexible admin announcements dengan priority levels
5. **User Engagement**: Re-engagement notifications untuk user tidak aktif
6. **Performance**: Efficient targeting reduces unnecessary notifications
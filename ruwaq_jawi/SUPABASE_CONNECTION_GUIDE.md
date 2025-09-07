# Supabase Connection Setup Guide

## ✅ What's Already Done

Your project is already set up with:
- Complete Flutter Supabase integration
- All required Dart models matching TABLE.md schema
- Enhanced SupabaseService with database operations
- Proper authentication system

## 🔧 Steps to Connect to Supabase

### 1. Apply Database Schema

Run this SQL in your Supabase SQL Editor to upgrade your database:

```sql
-- Copy and paste the contents of: database/upgrade_to_table_md_schema.sql
```

This will add missing fields from TABLE.md without breaking existing features.

### 2. Update Supabase Credentials

Update your Supabase URL and anon key in `lib/core/services/supabase_service.dart`:

```dart
const String supabaseUrl = 'YOUR_SUPABASE_URL_HERE';
const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY_HERE';
```

### 3. Test Connection

Run this command to test your connection:

```bash
cd ruwaq_jawi
flutter run
```

## 🔍 Database Schema Overview

Your updated database now includes all tables from TABLE.md:

### Core Tables:
- **profiles** - User data (with phone_number, avatar_url)
- **categories** - Content categories (with is_active, updated_at)
- **kitab** - Main content (with total_pages, is_active)
- **subscriptions** - User subscriptions (with auto_renew, updated_at)
- **transactions** - Payment records (with gateway_reference, failure_reason)
- **saved_items** - User bookmarks (with notes)
- **reading_progress** - Progress tracking (with completion_percentage)

### New Tables:
- **app_settings** - App configuration
- **admin_logs** - Admin activity tracking

## 📱 Available Operations

Your SupabaseService now supports:

### User Management
- `getCurrentUserProfile()` - Get current user profile
- `updateProfile(profile)` - Update user profile

### Content Operations
- `getActiveCategories()` - Get all active categories
- `getKitabByCategory(categoryId)` - Get books by category
- `searchKitab(query)` - Search for content
- `getKitabById(id)` - Get specific book

### Subscription Management
- `getUserSubscriptions()` - Get user's subscriptions
- `hasActiveSubscription()` - Check if user has active subscription

### Saved Items
- `getUserSavedItems()` - Get user's saved content
- `saveKitab(kitabId)` - Save content to favorites
- `removeSavedKitab(kitabId)` - Remove from favorites

### Progress Tracking
- `getReadingProgress(kitabId)` - Get reading progress
- `updateReadingProgress(progress)` - Update progress

## 🛡️ Security Features

All features maintain:
- Row Level Security (RLS) policies
- User data isolation
- Role-based access control
- Subscription-based content access

## ⚠️ Important Notes

1. Your existing Flutter code will continue working unchanged
2. New fields are optional and backward-compatible
3. All authentication features remain functional
4. No breaking changes to existing API

## 🎯 Next Steps

1. Apply the database upgrade SQL
2. Update Supabase credentials
3. Test the connection with `flutter run`
4. Your app is ready to use the enhanced TABLE.md schema!
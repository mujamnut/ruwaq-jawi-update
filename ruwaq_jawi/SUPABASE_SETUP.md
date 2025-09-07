# Supabase Setup Guide for Maktabah App

## 🚀 Quick Setup Steps

### 1. Create Supabase Project
1. Go to [supabase.com](https://supabase.com)
2. Click "Start your project" → "New project"
3. Choose your organization
4. Enter project details:
   - **Name**: `maktabah-dev` (for development)
   - **Database Password**: Create a strong password (save it!)
   - **Region**: Choose closest to your users (Malaysia/Singapore)
5. Click "Create new project"
6. Wait for project setup (2-3 minutes)

### 2. Get Project Configuration
After project is ready:
1. Go to **Settings** → **API** in your Supabase dashboard
2. Copy the following values:
   - **Project URL**: `https://your-project-id.supabase.co`
   - **anon public key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`

### 3. Configure Environment Variables
1. Copy `.env.example` to `.env`
2. Fill in your Supabase project details:
```bash
# Development Environment
SUPABASE_URL_DEV=https://your-project-id.supabase.co
SUPABASE_ANON_KEY_DEV=your-anon-key-here
```

### 4. Update Supabase Service
Update `lib/core/services/supabase_service.dart`:
```dart
// Replace these lines:
const String supabaseUrl = 'YOUR_SUPABASE_URL';
const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

// With your actual values:
const String supabaseUrl = 'https://your-project-id.supabase.co';
const String supabaseAnonKey = 'your-anon-key-here';
```

## 🗄️ Database Setup

### 1. Run SQL Migrations
Copy and paste each SQL file from `database/migrations/` into your Supabase SQL Editor:

1. **001_create_profiles_table.sql** - User profiles table
2. **002_create_categories_table.sql** - Content categories  
3. **003_create_kitab_table.sql** - Main content table
4. **004_create_subscriptions_table.sql** - User subscriptions
5. **005_create_transactions_table.sql** - Payment records
6. **006_create_saved_items_table.sql** - User bookmarks
7. **007_create_reading_progress_table.sql** - Reading progress

### 2. Insert Sample Data
After migrations, run the sample data files:
1. **001_insert_categories.sql** - Sample categories
2. **002_insert_sample_kitab.sql** - Sample books
3. **003_insert_sample_users.sql** - Sample users

### 3. Verify Setup
Check in your Supabase dashboard:
- **Database** → **Tables**: Should see 7 tables
- **Authentication** → **Users**: Can see sample users
- **Storage**: Create bucket named `kitab-pdfs`

## 🔒 Security Configuration

### Authentication Settings
1. Go to **Authentication** → **Settings**
2. Configure:
   - **Site URL**: `com.maktabah.app://` (for mobile deep links)
   - **Confirm email**: Enabled
   - **Email confirmations**: 24 hours

### Storage Buckets
Create storage buckets:
1. **kitab-pdfs**: For PDF files
   - Public: `false` (private)
   - File size limit: `50MB`
2. **thumbnails**: For cover images
   - Public: `true`
   - File size limit: `5MB`

## ✅ Verification Checklist

- [ ] Supabase project created
- [ ] Environment variables configured
- [ ] All 7 database tables created
- [ ] Sample data inserted
- [ ] Row Level Security policies active
- [ ] Storage buckets created
- [ ] Authentication settings configured

## 🚨 Important Notes

1. **Keep API Keys Secure**: Never commit `.env` file to git
2. **Use Different Projects**: Separate projects for dev/staging/production
3. **Database Passwords**: Save your database password securely
4. **RLS Policies**: Test with different user roles before going live

## 📞 Support

If you encounter issues:
1. Check Supabase logs in the dashboard
2. Verify all SQL migrations ran successfully
3. Test authentication flow with sample users
4. Ensure RLS policies are working correctly
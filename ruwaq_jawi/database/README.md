# Database Schema - Maktabah App

This directory contains the database schema and migration files for the Maktabah Islamic educational platform.

## 📁 Structure

```
database/
├── migrations/           # SQL migration files
│   ├── 001_create_profiles_table.sql
│   ├── 002_create_categories_table.sql
│   ├── 003_create_kitab_table.sql
│   ├── 004_create_subscriptions_table.sql
│   ├── 005_create_transactions_table.sql
│   ├── 006_create_saved_items_table.sql
│   └── 007_create_reading_progress_table.sql
└── sample_data/          # Sample data for testing
    ├── 001_insert_categories.sql
    ├── 002_insert_sample_kitab.sql
    └── 003_insert_sample_users.sql
```

## 🗄 Database Tables

### Core Tables

1. **profiles** - User profile information (extends Supabase auth.users)
2. **categories** - Content categorization (Hadis, Tafsir, Fiqh, etc.)
3. **kitab** - Main content table (books with PDF and YouTube videos)
4. **subscriptions** - User subscription management
5. **transactions** - Payment transaction records
6. **saved_items** - User bookmarks and saved content
7. **reading_progress** - User progress tracking

### Key Features

- **Row Level Security (RLS)** enabled on all tables
- **Role-based access control** (student vs admin)
- **Automatic triggers** for updated_at timestamps
- **Foreign key constraints** for data integrity
- **Indexes** for optimal query performance

## 🔐 Security Model

### User Roles
- **student**: Can view content, manage subscriptions, save items
- **admin**: Full access to manage content, users, and payments

### Access Patterns
- Students can only access their own data
- Premium content requires active subscription
- Admins have full access to all data
- Public access to categories and non-premium content

## 🚀 Setup Instructions

### 1. Create Supabase Project
1. Go to [supabase.com](https://supabase.com)
2. Create a new project
3. Note down your project URL and anon key

### 2. Run Migrations
Execute the migration files in order:

```sql
-- Run each file in the Supabase SQL Editor
-- 001_create_profiles_table.sql
-- 002_create_categories_table.sql
-- 003_create_kitab_table.sql
-- 004_create_subscriptions_table.sql
-- 005_create_transactions_table.sql
-- 006_create_saved_items_table.sql
-- 007_create_reading_progress_table.sql
```

### 3. Insert Sample Data
```sql
-- Run sample data files for testing
-- sample_data/001_insert_categories.sql
-- sample_data/002_insert_sample_kitab.sql
```

### 4. Configure Flutter App
Update `lib/core/services/supabase_service.dart` with your Supabase credentials:

```dart
const String supabaseUrl = 'YOUR_SUPABASE_URL';
const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

## 📊 Sample Data

The sample data includes:
- **8 Categories**: Hadis, Tafsir, Fiqh, Aqidah, Sirah, Akhlak, Tarikh, Bahasa Arab
- **6 Sample Kitab**: Mix of premium and free content
- **Subscription Plans**: 1, 3, 6, and 12-month options

## 🔧 Maintenance

### Regular Tasks
- Monitor subscription expiry with automated jobs
- Clean up expired sessions
- Backup transaction data
- Update content thumbnails

### Performance Optimization
- All tables have appropriate indexes
- RLS policies are optimized for common queries
- Foreign keys ensure data integrity

## 📝 Notes

- All timestamps use `TIMESTAMP WITH TIME ZONE`
- UUIDs are used for all primary keys
- Soft deletes are implemented where needed
- Metadata fields use JSONB for flexibility

---

**Created**: August 28, 2025  
**Last Updated**: August 28, 2025  
**Version**: 1.0.0

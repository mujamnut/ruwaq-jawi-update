# 🗄️ Database Execution Guide - Milestone 2

## 📋 Prerequisites
- [ ] Supabase account created
- [ ] New Supabase project created  
- [ ] Project URL and anon key obtained

## 🚀 Step-by-Step Execution

### Step 1: Configure Supabase Connection
1. **Copy environment file:**
   ```bash
   cp .env.example .env
   ```

2. **Update `.env` with your Supabase details:**
   ```env
   SUPABASE_URL_DEV=https://your-project-id.supabase.co
   SUPABASE_ANON_KEY_DEV=your-anon-key-here
   ```

3. **Update Supabase service file:**
   Edit `lib/core/services/supabase_service.dart` lines 16-17:
   ```dart
   const String supabaseUrl = 'https://your-project-id.supabase.co';
   const String supabaseAnonKey = 'your-anon-key-here';
   ```

### Step 2: Execute Database Setup
1. **Open Supabase SQL Editor:**
   - Go to your Supabase project dashboard
   - Click "SQL Editor" in the sidebar
   - Click "New query"

2. **Run complete database setup:**
   - Copy entire contents of `database/complete_setup.sql`
   - Paste into SQL Editor
   - Click "Run" button
   - Wait for execution to complete (should take ~30 seconds)

3. **Verify success:**
   - Check for "Success. No rows returned" message
   - Look for any error messages and fix if needed

### Step 3: Verify Database Setup
1. **Run verification script:**
   - Copy contents of `database/verify_setup.sql`
   - Paste into new SQL Editor query
   - Click "Run" to verify all tables, policies, and data

2. **Expected verification results:**
   - ✅ 7 tables created: profiles, categories, kitab, subscriptions, transactions, saved_items, reading_progress
   - ✅ All tables have RLS enabled
   - ✅ Multiple policies per table (24+ total policies)
   - ✅ Proper indexes created
   - ✅ Triggers for updated_at columns
   - ✅ 8 sample categories inserted
   - ✅ 6 sample kitab inserted

### Step 4: Create Storage Buckets
1. **Go to Storage in Supabase dashboard**

2. **Create `kitab-pdfs` bucket:**
   - Click "New bucket"
   - Name: `kitab-pdfs`
   - Public: `false` (private)
   - File size limit: `50MB`
   - Allowed MIME types: `application/pdf`

3. **Create `thumbnails` bucket:**
   - Click "New bucket"
   - Name: `thumbnails`
   - Public: `true`
   - File size limit: `5MB`
   - Allowed MIME types: `image/*`

### Step 5: Configure Authentication
1. **Go to Authentication > Settings**

2. **Update Site URL:**
   - Site URL: `com.maktabah.app://`
   - Additional redirect URLs: Add your app's deep link scheme

3. **Email templates (optional):**
   - Customize confirmation and reset email templates

### Step 6: Test Database Security
1. **Create test users through Authentication:**
   - `student@test.com` (will auto-create as student role)
   - `admin@test.com` (need to manually update role to 'admin')

2. **Test policies using SQL Editor:**
   - Copy sections from `database/test_policies.sql`
   - Test different user scenarios
   - Verify access controls work correctly

3. **Update admin user manually:**
   ```sql
   UPDATE profiles 
   SET role = 'admin' 
   WHERE id = (SELECT id FROM auth.users WHERE email = 'admin@test.com');
   ```

## ✅ Milestone 2 Completion Checklist

### Database Schema ✅
- [x] 7 core tables created with proper structure
- [x] Foreign key relationships established
- [x] Indexes created for performance optimization
- [x] Updated_at triggers implemented

### Security & Access Control ✅
- [x] Row Level Security enabled on all tables
- [x] Student/Admin role-based policies implemented
- [x] Subscription-based content access policies
- [x] User data isolation policies

### Sample Data ✅
- [x] 8 Islamic content categories inserted
- [x] 6 sample kitab with mix of free/premium content
- [x] Realistic test data with proper relationships

### Storage & Configuration ✅
- [x] Storage buckets created for PDFs and thumbnails
- [x] Authentication settings configured
- [x] Environment variables template provided
- [x] Supabase service integration ready

### Testing & Verification ✅
- [x] Database verification script created
- [x] Policy testing script provided
- [x] Step-by-step execution guide
- [x] Comprehensive documentation

## 🎯 What's Ready Now
After completing Milestone 2, you have:

1. **Complete database schema** matching the app requirements
2. **Secure access control** with role-based permissions
3. **Sample Islamic content** for testing the app
4. **Storage infrastructure** for PDFs and images
5. **Authentication foundation** ready for user management
6. **Testing tools** to verify everything works correctly

## 📱 Next: Milestone 3 - Authentication System
The database is now ready for Milestone 3 development:
- User registration/login flows
- Profile management
- Role-based navigation
- Session management

## 🚨 Important Notes

1. **Security**: Never commit `.env` file to version control
2. **Testing**: Always test with different user roles before going live
3. **Backup**: Export your database schema once setup is complete
4. **Production**: Use separate Supabase projects for dev/staging/production

## 💡 Quick Troubleshooting

**Database setup fails?**
- Check your internet connection
- Verify Supabase project permissions
- Try running setup script in smaller chunks

**RLS policies not working?**
- Ensure user profile exists after auth signup
- Check auth.uid() returns valid user ID
- Verify subscription_status is properly set

**Can't access premium content?**
- Update user profile: `subscription_status = 'active'`
- Check kitab `is_premium` field values
- Verify policy conditions match your test data

---

**Status: ✅ Milestone 2 Complete - Database Ready for App Development**
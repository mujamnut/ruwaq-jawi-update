-- ============================================
-- RLS POLICIES TESTING SCRIPT
-- ============================================
-- This script helps test Row Level Security policies
-- Run sections individually to test different scenarios

-- ============================================
-- SETUP: Create test users for policy testing
-- ============================================

-- Note: These users should be created through Supabase Auth, not directly in database
-- This is just for reference - actual user creation happens via signup flow

-- Test users needed:
-- 1. student@test.com (role: student, subscription_status: inactive)
-- 2. subscriber@test.com (role: student, subscription_status: active)  
-- 3. admin@test.com (role: admin, subscription_status: inactive)

-- ============================================
-- TEST 1: Categories Access (Should work for everyone)
-- ============================================

-- Test as anonymous user (should work)
SELECT name, description FROM categories ORDER BY sort_order LIMIT 3;

-- Result: Should return categories (open access)

-- ============================================
-- TEST 2: Kitab Access - Non-Premium Content
-- ============================================

-- Test as anonymous user - should see only non-premium kitab
SELECT 
    title,
    author,
    is_premium,
    'anonymous' as tested_as
FROM kitab 
WHERE NOT is_premium 
ORDER BY title;

-- Result: Should return 2 non-premium kitab (Fiqh Sunnah, Akhlak Mulia)

-- ============================================
-- TEST 3: Kitab Access - Premium Content Tests
-- ============================================

-- These tests require actual authenticated users
-- Run after creating test users through Supabase Auth

-- Test as student without subscription (should see no premium content)
-- SELECT title, is_premium FROM kitab WHERE is_premium = true;
-- Expected result: No rows (access denied)

-- Test as student with active subscription (should see premium content)  
-- SELECT title, is_premium FROM kitab WHERE is_premium = true;
-- Expected result: 4 premium kitab visible

-- Test as admin (should see all content regardless of subscription)
-- SELECT title, is_premium FROM kitab ORDER BY title;
-- Expected result: All 6 kitab visible

-- ============================================
-- TEST 4: Profile Access Tests
-- ============================================

-- Test user can view own profile
-- SELECT full_name, role, subscription_status FROM profiles WHERE id = auth.uid();
-- Expected: Own profile data

-- Test user cannot view other profiles (unless admin)
-- SELECT full_name FROM profiles WHERE id != auth.uid();
-- Expected for student: No rows
-- Expected for admin: All profiles

-- ============================================
-- TEST 5: Admin-Only Operations
-- ============================================

-- Test category creation (admin only)
-- INSERT INTO categories (name, description) VALUES ('Test Category', 'Test Description');
-- Expected for admin: Success
-- Expected for student: Access denied

-- Test kitab creation (admin only)
-- INSERT INTO kitab (title, author, is_premium) VALUES ('Test Kitab', 'Test Author', false);
-- Expected for admin: Success  
-- Expected for student: Access denied

-- ============================================
-- TEST 6: User-Specific Data Access
-- ============================================

-- Test saved_items (user can only see own saved items)
-- INSERT INTO saved_items (user_id, kitab_id) 
-- VALUES (auth.uid(), '660e8400-e29b-41d4-a716-446655440001');
-- SELECT * FROM saved_items;
-- Expected: Only own saved items

-- Test reading_progress (user can only see own progress)
-- INSERT INTO reading_progress (user_id, kitab_id, video_progress, pdf_page)
-- VALUES (auth.uid(), '660e8400-e29b-41d4-a716-446655440001', 120, 5);
-- SELECT * FROM reading_progress;
-- Expected: Only own progress

-- ============================================
-- TEST 7: Subscription and Transaction Access
-- ============================================

-- Test subscription access
-- SELECT plan_type, status, end_date FROM subscriptions WHERE user_id = auth.uid();
-- Expected for user: Own subscriptions only
-- Expected for admin: All subscriptions

-- Test transaction access  
-- SELECT amount, status, created_at FROM transactions WHERE user_id = auth.uid();
-- Expected for user: Own transactions only
-- Expected for admin: All transactions

-- ============================================
-- POLICY TESTING CHECKLIST
-- ============================================
--
-- □ Anonymous users can view categories
-- □ Anonymous users can view non-premium kitab only
-- □ Students without subscription cannot view premium kitab
-- □ Students with active subscription can view premium kitab
-- □ Admins can view all kitab regardless of subscription
-- □ Users can view/update own profile only
-- □ Admins can view all profiles
-- □ Only admins can create/update/delete categories
-- □ Only admins can create/update/delete kitab
-- □ Users can only access own saved_items
-- □ Users can only access own reading_progress
-- □ Users can only access own subscriptions
-- □ Users can only access own transactions
-- □ Admins can access all data
--
-- ============================================
-- TROUBLESHOOTING
-- ============================================
--
-- If policies aren't working:
-- 1. Check RLS is enabled: ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;
-- 2. Verify user authentication: SELECT auth.uid(), auth.role();
-- 3. Check profile exists: SELECT * FROM profiles WHERE id = auth.uid();
-- 4. Test policies individually by name
-- 5. Check policy conditions match your test data
--
-- Common issues:
-- - User profile not created after signup (check trigger)
-- - Subscription status not updated (check payment flow)
-- - Admin role not set (manual update needed)
-- - Auth token expired (re-login required)
--
-- ============================================
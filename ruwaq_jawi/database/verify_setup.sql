-- ============================================
-- DATABASE SETUP VERIFICATION SCRIPT
-- ============================================
-- Run this script to verify your database setup is complete and working

-- ============================================
-- 1. CHECK ALL TABLES EXIST
-- ============================================
SELECT 
    schemaname,
    tablename,
    tableowner,
    hasindexes,
    hasrules,
    hastriggers
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY tablename;

-- Expected tables:
-- - categories
-- - kitab  
-- - profiles
-- - reading_progress
-- - saved_items
-- - subscriptions
-- - transactions

-- ============================================
-- 2. CHECK ROW LEVEL SECURITY STATUS
-- ============================================
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY tablename;

-- All tables should have rowsecurity = true

-- ============================================
-- 3. CHECK RLS POLICIES
-- ============================================
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- ============================================
-- 4. CHECK INDEXES
-- ============================================
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- ============================================
-- 5. CHECK TRIGGERS
-- ============================================
SELECT 
    event_object_table,
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE event_object_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- ============================================
-- 6. CHECK FOREIGN KEY CONSTRAINTS
-- ============================================
SELECT 
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
LEFT JOIN information_schema.constraint_column_usage ccu
    ON tc.constraint_name = ccu.constraint_name
WHERE tc.table_schema = 'public'
    AND tc.constraint_type = 'FOREIGN KEY'
ORDER BY tc.table_name, tc.constraint_name;

-- ============================================
-- 7. CHECK SAMPLE DATA
-- ============================================

-- Check categories
SELECT 'categories' as table_name, COUNT(*) as record_count FROM categories
UNION ALL
SELECT 'kitab', COUNT(*) FROM kitab
UNION ALL
SELECT 'profiles', COUNT(*) FROM profiles
UNION ALL
SELECT 'subscriptions', COUNT(*) FROM subscriptions
UNION ALL
SELECT 'transactions', COUNT(*) FROM transactions
UNION ALL
SELECT 'saved_items', COUNT(*) FROM saved_items
UNION ALL
SELECT 'reading_progress', COUNT(*) FROM reading_progress;

-- Expected counts after sample data:
-- - categories: 8
-- - kitab: 6
-- - profiles: depends on users created
-- - others: 0 (empty initially)

-- ============================================
-- 8. CHECK CATEGORY DATA
-- ============================================
SELECT name, description, sort_order FROM categories ORDER BY sort_order;

-- ============================================
-- 9. CHECK KITAB DATA
-- ============================================
SELECT 
    k.title,
    k.author,
    c.name as category,
    k.is_premium,
    k.duration_minutes
FROM kitab k
LEFT JOIN categories c ON k.category_id = c.id
ORDER BY k.sort_order, k.title;

-- ============================================
-- 10. TEST FUNCTIONS
-- ============================================

-- Check if update_updated_at_column function exists
SELECT 
    proname,
    prorettype::regtype,
    prosrc
FROM pg_proc 
WHERE proname = 'update_updated_at_column';

-- Check if handle_new_user function exists
SELECT 
    proname,
    prorettype::regtype,
    prosrc
FROM pg_proc 
WHERE proname = 'handle_new_user';

-- ============================================
-- VERIFICATION CHECKLIST
-- ============================================
-- 
-- After running this script, verify:
-- □ All 7 tables exist
-- □ All tables have RLS enabled (rowsecurity = true)
-- □ Multiple policies exist for each table
-- □ Indexes are created for performance
-- □ Triggers exist for updated_at columns
-- □ Foreign key constraints are properly set
-- □ Sample data is inserted (8 categories, 6 kitab)
-- □ Functions exist and are correct
-- 
-- If any check fails:
-- 1. Re-run the complete_setup.sql script
-- 2. Check for any error messages
-- 3. Verify your user has proper permissions
-- 4. Ensure you're connected to the correct database
-- 
-- ============================================
-- Insert sample user profiles for testing
-- Note: These will be created automatically when users sign up through Supabase Auth
-- This is just for reference of the expected data structure

-- Sample admin user profile (will be created via trigger)
-- INSERT INTO profiles (id, full_name, role, subscription_status) VALUES
--   ('770e8400-e29b-41d4-a716-446655440001', 'Admin User', 'admin', 'active');

-- Sample student user profiles (will be created via trigger)
-- INSERT INTO profiles (id, full_name, role, subscription_status) VALUES
--   ('770e8400-e29b-41d4-a716-446655440002', 'Ahmad bin Ali', 'student', 'active'),
--   ('770e8400-e29b-41d4-a716-446655440003', 'Fatimah binti Hassan', 'student', 'inactive'),
--   ('770e8400-e29b-41d4-a716-446655440004', 'Muhammad bin Omar', 'student', 'active');

-- Sample subscription plans data (for reference)
-- Plan types: '1month', '3month', '6month', '12month'
-- Pricing structure (in MYR):
-- 1 month: RM 15.00
-- 3 months: RM 40.00 (save RM 5.00)
-- 6 months: RM 75.00 (save RM 15.00)
-- 12 months: RM 140.00 (save RM 40.00)

-- =============================================
-- UPGRADE EXISTING DATABASE TO TABLE.MD SCHEMA
-- =============================================
-- This migration adds missing fields and tables to match TABLE.md
-- without breaking existing functionality

-- Add missing columns to profiles table
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone_number TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Add missing columns to categories table
ALTER TABLE categories ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE categories ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Add missing columns to kitab table
ALTER TABLE kitab ADD COLUMN IF NOT EXISTS total_pages INTEGER;
ALTER TABLE kitab ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

-- Add missing columns to subscriptions table
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS auto_renew BOOLEAN DEFAULT false;
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Add missing columns to transactions table
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS gateway_reference TEXT;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS failure_reason TEXT;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS processed_at TIMESTAMP WITH TIME ZONE;

-- Add missing columns to reading_progress table
ALTER TABLE reading_progress ADD COLUMN IF NOT EXISTS video_duration INTEGER DEFAULT 0;
ALTER TABLE reading_progress ADD COLUMN IF NOT EXISTS pdf_total_pages INTEGER;
ALTER TABLE reading_progress ADD COLUMN IF NOT EXISTS completion_percentage DECIMAL(5,2) DEFAULT 0.00;
ALTER TABLE reading_progress ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE reading_progress ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Add missing columns to saved_items table
ALTER TABLE saved_items ADD COLUMN IF NOT EXISTS notes TEXT;

-- Create app_settings table if it doesn't exist
CREATE TABLE IF NOT EXISTS app_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    setting_key TEXT NOT NULL UNIQUE,
    setting_value JSONB,
    description TEXT,
    is_public BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create admin_logs table if it doesn't exist
CREATE TABLE IF NOT EXISTS admin_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    table_name TEXT,
    record_id UUID,
    old_values JSONB,
    missing VALUES JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add updated_at triggers for new columns
CREATE TRIGGER IF NOT EXISTS handle_updated_at_categories
    BEFORE UPDATE ON categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER IF NOT EXISTS handle_updated_at_subscriptions
    BEFORE UPDATE ON subscriptions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER IF NOT EXISTS handle_updated_at_reading_progress
    BEFORE UPDATE ON reading_progress
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER IF NOT EXISTS handle_updated_at_app_settings
    BEFORE UPDATE ON app_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS on new tables
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_logs ENABLE ROW LEVEL SECURITY;

-- Add RLS policies for app_settings
CREATE POLICY IF NOT EXISTS "Anyone can view public settings" ON app_settings
    FOR SELECT USING (is_public = true);

CREATE POLICY IF NOT EXISTS "Admins can manage all settings" ON app_settings
    FOR ALL USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- Add RLS policies for admin_logs
CREATE POLICY IF NOT EXISTS "Admins can view admin logs" ON admin_logs
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY IF NOT EXISTS "Admins can create admin logs" ON admin_logs
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- Insert default app settings from TABLE.md
INSERT INTO app_settings (setting_key, setting_value, description, is_public) VALUES
    ('app_version', '"1.0.0"', 'Current app version', true),
    ('maintenance_mode', 'false', 'Enable maintenance mode', true),
    ('subscription_plans', '{
        "1month": {"price": 15.00, "currency": "MYR", "name": "1 Bulan"},
        "3month": {"price": 40.00, "currency": "MYR", "name": "3 Bulan"},
        "6month": {"price": 75.00, "currency": "MYR", "name": "6 Bulan"},
        "12month": {"price": 140.00, "currency": "MYR", "name": "1 Tahun"}
    }', 'Available subscription plans', true),
    ('payment_gateways', '{
        "chip": {"enabled": true, "name": "Chip by Razer"},
        "stripe": {"enabled": false, "name": "Stripe"}
    }', 'Enabled payment gateways', false)
ON CONFLICT (setting_key) DO NOTHING;

-- Create additional indexes for performance (from TABLE.md)
CREATE INDEX IF NOT EXISTS idx_kitab_title_search ON kitab USING GIN (to_tsvector('english', title || ' ' || COALESCE(author, '') || ' ' || COALESCE(description, '')));
CREATE INDEX IF NOT EXISTS idx_subscriptions_active ON subscriptions(user_id, status) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_reading_progress_last_accessed ON reading_progress(user_id, last_accessed DESC);
CREATE INDEX IF NOT EXISTS idx_admin_logs_admin ON admin_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_logs_action ON admin_logs(action);
CREATE INDEX IF NOT EXISTS idx_admin_logs_created ON admin_logs(created_at DESC);
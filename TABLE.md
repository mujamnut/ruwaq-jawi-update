-- =============================================
-- RUWAQ JAWI - SUPABASE DATABASE SETUP
-- Copy and paste each section into Supabase SQL Editor
-- =============================================

-- =============================================
-- 1. ENABLE ROW LEVEL SECURITY (RLS)
-- =============================================

-- Enable RLS on auth.users table (if not already enabled)
ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;

-- =============================================
-- 2. CREATE CUSTOM TYPES
-- =============================================

-- User roles enum
CREATE TYPE user_role AS ENUM ('student', 'admin');

-- Subscription status enum  
CREATE TYPE subscription_status AS ENUM ('active', 'expired', 'cancelled', 'pending');

-- Transaction status enum
CREATE TYPE transaction_status AS ENUM ('pending', 'completed', 'failed', 'refunded');

-- Plan types enum
CREATE TYPE plan_type AS ENUM ('1month', '3month', '6month', '12month');

-- =============================================
-- 3. CREATE MAIN TABLES
-- =============================================

-- User Profiles (extends auth.users)
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    role user_role DEFAULT 'student',
    subscription_status TEXT DEFAULT 'inactive',
    phone_number TEXT,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Content Categories
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    icon_url TEXT,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Kitab (Books/Content)
CREATE TABLE kitab (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    author TEXT,
    description TEXT,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    pdf_url TEXT,
    youtube_video_id TEXT, -- YouTube video ID only (e.g., 'dQw4w9WgXcQ')
    youtube_video_url TEXT, -- Full YouTube URL for backup
    thumbnail_url TEXT, -- YouTube thumbnail or custom thumbnail
    is_premium BOOLEAN DEFAULT true,
    duration_minutes INTEGER, -- Video duration in minutes
    total_pages INTEGER, -- PDF page count
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User Subscriptions
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    plan_type plan_type NOT NULL,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    status subscription_status DEFAULT 'pending',
    payment_method TEXT, -- 'chip', 'stripe', etc.
    amount DECIMAL(10,2) NOT NULL,
    currency TEXT DEFAULT 'MYR',
    auto_renew BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Payment Transactions
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
    amount DECIMAL(10,2) NOT NULL,
    currency TEXT DEFAULT 'MYR',
    payment_method TEXT NOT NULL, -- 'chip_fpx', 'chip_card', 'stripe', etc.
    gateway_transaction_id TEXT, -- Transaction ID from payment gateway
    gateway_reference TEXT, -- Additional gateway reference
    status transaction_status DEFAULT 'pending',
    failure_reason TEXT, -- Error message if failed
    metadata JSONB, -- Additional payment gateway data
    processed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User Saved Items (Bookmarks)
CREATE TABLE saved_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    kitab_id UUID REFERENCES kitab(id) ON DELETE CASCADE,
    folder_name TEXT DEFAULT 'Default',
    notes TEXT, -- User's personal notes
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, kitab_id)
);

-- User Reading/Viewing Progress
CREATE TABLE reading_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    kitab_id UUID REFERENCES kitab(id) ON DELETE CASCADE,
    video_progress INTEGER DEFAULT 0, -- seconds watched
    video_duration INTEGER DEFAULT 0, -- total video duration in seconds
    pdf_page INTEGER DEFAULT 1, -- current PDF page
    pdf_total_pages INTEGER, -- total PDF pages
    completion_percentage DECIMAL(5,2) DEFAULT 0.00, -- 0.00 to 100.00
    last_accessed TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, kitab_id)
);

-- App Settings/Configuration
CREATE TABLE app_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    setting_key TEXT NOT NULL UNIQUE,
    setting_value JSONB,
    description TEXT,
    is_public BOOLEAN DEFAULT false, -- Whether students can read this setting
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Admin Activity Logs
CREATE TABLE admin_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    action TEXT NOT NULL, -- 'create_kitab', 'update_user', etc.
    table_name TEXT,
    record_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================
-- 4. CREATE INDEXES FOR PERFORMANCE
-- =============================================

-- Profiles indexes
CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_profiles_subscription_status ON profiles(subscription_status);

-- Categories indexes
CREATE INDEX idx_categories_sort_order ON categories(sort_order);
CREATE INDEX idx_categories_active ON categories(is_active);

-- Kitab indexes
CREATE INDEX idx_kitab_category ON kitab(category_id);
CREATE INDEX idx_kitab_premium ON kitab(is_premium);
CREATE INDEX idx_kitab_active ON kitab(is_active);
CREATE INDEX idx_kitab_sort_order ON kitab(sort_order);
CREATE INDEX idx_kitab_title_search ON kitab USING GIN (to_tsvector('english', title || ' ' || COALESCE(author, '') || ' ' || COALESCE(description, '')));

-- Subscriptions indexes
CREATE INDEX idx_subscriptions_user ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_end_date ON subscriptions(end_date);
CREATE INDEX idx_subscriptions_active ON subscriptions(user_id, status) WHERE status = 'active';

-- Transactions indexes
CREATE INDEX idx_transactions_user ON transactions(user_id);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_transactions_gateway_id ON transactions(gateway_transaction_id);
CREATE INDEX idx_transactions_created ON transactions(created_at);

-- Saved items indexes
CREATE INDEX idx_saved_items_user ON saved_items(user_id);
CREATE INDEX idx_saved_items_folder ON saved_items(user_id, folder_name);

-- Reading progress indexes
CREATE INDEX idx_reading_progress_user ON reading_progress(user_id);
CREATE INDEX idx_reading_progress_last_accessed ON reading_progress(user_id, last_accessed DESC);

-- Admin logs indexes
CREATE INDEX idx_admin_logs_admin ON admin_logs(admin_id);
CREATE INDEX idx_admin_logs_action ON admin_logs(action);
CREATE INDEX idx_admin_logs_created ON admin_logs(created_at DESC);

-- =============================================
-- 5. CREATE ROW LEVEL SECURITY POLICIES
-- =============================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE kitab ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE reading_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_logs ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view own profile" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Admins can view all profiles" ON profiles FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "Admins can update all profiles" ON profiles FOR UPDATE USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Categories policies (public read, admin write)
CREATE POLICY "Anyone can view active categories" ON categories FOR SELECT USING (is_active = true);
CREATE POLICY "Admins can manage categories" ON categories FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Kitab policies
CREATE POLICY "Anyone can view active kitab" ON kitab FOR SELECT USING (is_active = true);
CREATE POLICY "Admins can manage kitab" ON kitab FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Subscriptions policies
CREATE POLICY "Users can view own subscriptions" ON subscriptions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Admins can view all subscriptions" ON subscriptions FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "Admins can manage subscriptions" ON subscriptions FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Transactions policies
CREATE POLICY "Users can view own transactions" ON transactions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Admins can view all transactions" ON transactions FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "Admins can manage transactions" ON transactions FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Saved items policies
CREATE POLICY "Users can manage own saved items" ON saved_items FOR ALL USING (auth.uid() = user_id);

-- Reading progress policies
CREATE POLICY "Users can manage own reading progress" ON reading_progress FOR ALL USING (auth.uid() = user_id);

-- App settings policies
CREATE POLICY "Anyone can view public settings" ON app_settings FOR SELECT USING (is_public = true);
CREATE POLICY "Admins can manage all settings" ON app_settings FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Admin logs policies (admin only)
CREATE POLICY "Admins can view admin logs" ON admin_logs FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "Admins can create admin logs" ON admin_logs FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- =============================================
-- 6. CREATE FUNCTIONS
-- =============================================

-- Function to automatically create profile when user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, role)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
        COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'student')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to check if user has active subscription
CREATE OR REPLACE FUNCTION public.user_has_active_subscription(user_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM subscriptions 
        WHERE user_id = user_uuid 
        AND status = 'active' 
        AND end_date > NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user's subscription status
CREATE OR REPLACE FUNCTION public.get_user_subscription_status(user_uuid UUID)
RETURNS TEXT AS $$
DECLARE
    sub_status TEXT;
BEGIN
    SELECT 
        CASE 
            WHEN COUNT(*) = 0 THEN 'none'
            WHEN MAX(end_date) < NOW() THEN 'expired'
            WHEN EXISTS (SELECT 1 FROM subscriptions WHERE user_id = user_uuid AND status = 'active' AND end_date > NOW()) THEN 'active'
            ELSE 'inactive'
        END INTO sub_status
    FROM subscriptions 
    WHERE user_id = user_uuid;
    
    RETURN sub_status;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 7. CREATE TRIGGERS
-- =============================================

-- Trigger to create profile on user signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Triggers for updated_at timestamps
CREATE TRIGGER handle_updated_at_profiles
    BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_updated_at_categories
    BEFORE UPDATE ON categories
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_updated_at_kitab
    BEFORE UPDATE ON kitab
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_updated_at_subscriptions
    BEFORE UPDATE ON subscriptions
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_updated_at_reading_progress
    BEFORE UPDATE ON reading_progress
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_updated_at_app_settings
    BEFORE UPDATE ON app_settings
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- =============================================
-- 8. INSERT DEFAULT DATA
-- =============================================

-- Insert default categories
INSERT INTO categories (name, description, icon_url, sort_order) VALUES
('Quran & Tafsir', 'Al-Quran dan Tafsir', 'https://example.com/icons/quran.svg', 1),
('Hadis & Sunnah', 'Hadis Rasulullah SAW dan Sunnah', 'https://example.com/icons/hadith.svg', 2),
('Fiqh', 'Hukum Islam dan Fiqh', 'https://example.com/icons/fiqh.svg', 3),
('Akidah', 'Akidah dan Keimanan', 'https://example.com/icons/akidah.svg', 4),
('Sirah', 'Sirah Nabawi dan Sejarah Islam', 'https://example.com/icons/sirah.svg', 5),
('Akhlak & Tasawuf', 'Akhlak Islami dan Tasawuf', 'https://example.com/icons/akhlak.svg', 6),
('Bahasa Arab', 'Pembelajaran Bahasa Arab', 'https://example.com/icons/arabic.svg', 7);

-- Insert default app settings
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
}', 'Enabled payment gateways', false);

-- =============================================
-- 9. CREATE VIEWS FOR COMMON QUERIES
-- =============================================

-- View for active subscriptions with user info
CREATE VIEW active_subscriptions AS
SELECT 
    s.*,
    p.full_name,
    p.role,
    EXTRACT(DAYS FROM (s.end_date - NOW())) as days_remaining
FROM subscriptions s
JOIN profiles p ON s.user_id = p.id
WHERE s.status = 'active' AND s.end_date > NOW();

-- View for kitab with category info
CREATE VIEW kitab_with_category AS
SELECT 
    k.*,
    c.name as category_name,
    c.description as category_description
FROM kitab k
LEFT JOIN categories c ON k.category_id = c.id
WHERE k.is_active = true;

-- View for user progress summary
CREATE VIEW user_progress_summary AS
SELECT 
    rp.user_id,
    COUNT(rp.kitab_id) as total_kitab_accessed,
    AVG(rp.completion_percentage) as avg_completion,
    COUNT(CASE WHEN rp.completion_percentage >= 100 THEN 1 END) as completed_kitab,
    MAX(rp.last_accessed) as last_activity
FROM reading_progress rp
GROUP BY rp.user_id;

-- =============================================
-- SETUP COMPLETE!
-- =============================================
-- 
-- Next steps:
-- 1. Go to Supabase Storage and create buckets:
--    - 'kitab-pdfs' (for PDF files)
--    - 'thumbnails' (for custom thumbnails)
--    - 'avatars' (for user profile pictures)
--
-- 2. Set up storage policies for these buckets
--
-- 3. Configure your Flutter app with Supabase credentials
--
-- 4. Set up Chip payment gateway webhook URLs
--
-- =============================================
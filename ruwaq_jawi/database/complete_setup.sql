-- ============================================
-- MAKTABAH APP - COMPLETE DATABASE SETUP
-- ============================================
-- This file contains all database migrations and sample data
-- Run this in your Supabase SQL Editor to set up the complete database

-- ============================================
-- STEP 1: CREATE PROFILES TABLE
-- ============================================

-- Create profiles table (extends Supabase auth.users)
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  role TEXT DEFAULT 'student' CHECK (role IN ('student', 'admin')),
  subscription_status TEXT DEFAULT 'inactive' CHECK (subscription_status IN ('active', 'inactive', 'expired', 'cancelled')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for profiles table
CREATE TRIGGER update_profiles_updated_at 
    BEFORE UPDATE ON profiles 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Create indexes for better performance
CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_profiles_subscription_status ON profiles(subscription_status);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view and update their own profile
CREATE POLICY "Users can view own profile" ON profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id);

-- Admins can view all profiles
CREATE POLICY "Admins can view all profiles" ON profiles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Admins can update any profile
CREATE POLICY "Admins can update any profile" ON profiles
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Auto-create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, role)
    VALUES (NEW.id, NEW.raw_user_meta_data->>'full_name', 'student');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile on signup
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- STEP 2: CREATE CATEGORIES TABLE
-- ============================================

-- Create categories table
CREATE TABLE categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  icon_url TEXT,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_categories_sort_order ON categories(sort_order);
CREATE INDEX idx_categories_name ON categories(name);

-- Enable Row Level Security
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Anyone can view categories
CREATE POLICY "Anyone can view categories" ON categories
    FOR SELECT USING (true);

-- Only admins can insert, update, delete categories
CREATE POLICY "Admins can insert categories" ON categories
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY "Admins can update categories" ON categories
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY "Admins can delete categories" ON categories
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- ============================================
-- STEP 3: CREATE KITAB TABLE
-- ============================================

-- Create kitab table (main content table)
CREATE TABLE kitab (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  author TEXT,
  description TEXT,
  category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
  pdf_url TEXT,
  youtube_video_id TEXT, -- YouTube video ID (e.g., 'dQw4w9WgXcQ')
  youtube_video_url TEXT, -- Full YouTube URL for backup
  thumbnail_url TEXT, -- YouTube thumbnail or custom thumbnail
  is_premium BOOLEAN DEFAULT true,
  duration_minutes INTEGER, -- Video duration in minutes
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create trigger for updated_at
CREATE TRIGGER update_kitab_updated_at 
    BEFORE UPDATE ON kitab 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Create indexes for better performance
CREATE INDEX idx_kitab_category_id ON kitab(category_id);
CREATE INDEX idx_kitab_is_premium ON kitab(is_premium);
CREATE INDEX idx_kitab_sort_order ON kitab(sort_order);
CREATE INDEX idx_kitab_title ON kitab(title);
CREATE INDEX idx_kitab_author ON kitab(author);

-- Enable Row Level Security
ALTER TABLE kitab ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Anyone can view non-premium kitab
CREATE POLICY "Anyone can view non-premium kitab" ON kitab
    FOR SELECT USING (NOT is_premium);

-- Authenticated users with active subscription can view premium kitab
CREATE POLICY "Subscribers can view premium kitab" ON kitab
    FOR SELECT USING (
        is_premium AND 
        auth.uid() IS NOT NULL AND
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() 
            AND subscription_status = 'active'
        )
    );

-- Admins can view all kitab
CREATE POLICY "Admins can view all kitab" ON kitab
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Only admins can insert, update, delete kitab
CREATE POLICY "Admins can insert kitab" ON kitab
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY "Admins can update kitab" ON kitab
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY "Admins can delete kitab" ON kitab
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- ============================================
-- STEP 4: CREATE SUBSCRIPTIONS TABLE
-- ============================================

CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  plan_type TEXT NOT NULL CHECK (plan_type IN ('1month', '3month', '6month', '12month')),
  start_date TIMESTAMP WITH TIME ZONE NOT NULL,
  end_date TIMESTAMP WITH TIME ZONE NOT NULL,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'expired', 'cancelled', 'pending')),
  payment_method TEXT,
  amount DECIMAL(10,2) NOT NULL,
  currency TEXT DEFAULT 'MYR',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_end_date ON subscriptions(end_date);

-- Enable Row Level Security
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own subscriptions" ON subscriptions
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Admins can view all subscriptions" ON subscriptions
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- ============================================
-- STEP 5: CREATE TRANSACTIONS TABLE
-- ============================================

CREATE TABLE transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
  amount DECIMAL(10,2) NOT NULL,
  currency TEXT DEFAULT 'MYR',
  payment_method TEXT,
  gateway_transaction_id TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_transactions_user_id ON transactions(user_id);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_transactions_created_at ON transactions(created_at);

-- Enable Row Level Security
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own transactions" ON transactions
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Admins can view all transactions" ON transactions
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- ============================================
-- STEP 6: CREATE SAVED_ITEMS TABLE
-- ============================================

CREATE TABLE saved_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  kitab_id UUID REFERENCES kitab(id) ON DELETE CASCADE,
  folder_name TEXT DEFAULT 'Default',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, kitab_id)
);

-- Create indexes
CREATE INDEX idx_saved_items_user_id ON saved_items(user_id);
CREATE INDEX idx_saved_items_kitab_id ON saved_items(kitab_id);

-- Enable Row Level Security
ALTER TABLE saved_items ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can manage own saved items" ON saved_items
    FOR ALL USING (user_id = auth.uid());

-- ============================================
-- STEP 7: CREATE READING_PROGRESS TABLE
-- ============================================

CREATE TABLE reading_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  kitab_id UUID REFERENCES kitab(id) ON DELETE CASCADE,
  video_progress INTEGER DEFAULT 0, -- seconds watched
  pdf_page INTEGER DEFAULT 1,
  last_accessed TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, kitab_id)
);

-- Create indexes
CREATE INDEX idx_reading_progress_user_id ON reading_progress(user_id);
CREATE INDEX idx_reading_progress_kitab_id ON reading_progress(kitab_id);
CREATE INDEX idx_reading_progress_last_accessed ON reading_progress(last_accessed);

-- Enable Row Level Security
ALTER TABLE reading_progress ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can manage own reading progress" ON reading_progress
    FOR ALL USING (user_id = auth.uid());

-- ============================================
-- STEP 8: INSERT SAMPLE CATEGORIES
-- ============================================

INSERT INTO categories (id, name, description, icon_url, sort_order) VALUES
  ('550e8400-e29b-41d4-a716-446655440001', 'Hadis', 'Koleksi hadis-hadis sahih dan hasan', 'https://example.com/icons/hadis.png', 1),
  ('550e8400-e29b-41d4-a716-446655440002', 'Tafsir', 'Tafsir Al-Quran dari ulama muktabar', 'https://example.com/icons/tafsir.png', 2),
  ('550e8400-e29b-41d4-a716-446655440003', 'Fiqh', 'Hukum-hukum Islam dalam kehidupan sehari-hari', 'https://example.com/icons/fiqh.png', 3),
  ('550e8400-e29b-41d4-a716-446655440004', 'Aqidah', 'Ilmu tauhid dan kepercayaan Islam', 'https://example.com/icons/aqidah.png', 4),
  ('550e8400-e29b-41d4-a716-446655440005', 'Sirah', 'Sejarah hidup Rasulullah SAW', 'https://example.com/icons/sirah.png', 5),
  ('550e8400-e29b-41d4-a716-446655440006', 'Akhlak', 'Budi pekerti dan moral Islam', 'https://example.com/icons/akhlak.png', 6),
  ('550e8400-e29b-41d4-a716-446655440007', 'Tarikh', 'Sejarah Islam dan peradaban', 'https://example.com/icons/tarikh.png', 7),
  ('550e8400-e29b-41d4-a716-446655440008', 'Bahasa Arab', 'Pembelajaran bahasa Arab untuk memahami Islam', 'https://example.com/icons/arabic.png', 8);

-- ============================================
-- STEP 9: INSERT SAMPLE KITAB
-- ============================================

INSERT INTO kitab (id, title, author, description, category_id, pdf_url, youtube_video_id, youtube_video_url, thumbnail_url, is_premium, duration_minutes, sort_order) VALUES
  (
    '660e8400-e29b-41d4-a716-446655440001',
    'Sahih Bukhari - Kitab Iman',
    'Imam Al-Bukhari',
    'Koleksi hadis-hadis sahih tentang iman dan kepercayaan dalam Islam',
    '550e8400-e29b-41d4-a716-446655440001',
    'https://example.com/pdfs/sahih-bukhari-iman.pdf',
    'dQw4w9WgXcQ',
    'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    'https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg',
    true,
    45,
    1
  ),
  (
    '660e8400-e29b-41d4-a716-446655440002',
    'Tafsir Ibn Kathir - Surah Al-Fatihah',
    'Ibn Kathir',
    'Tafsir lengkap Surah Al-Fatihah dengan penjelasan mendalam',
    '550e8400-e29b-41d4-a716-446655440002',
    'https://example.com/pdfs/tafsir-ibn-kathir-fatihah.pdf',
    'dQw4w9WgXcQ',
    'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    'https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg',
    true,
    60,
    1
  ),
  (
    '660e8400-e29b-41d4-a716-446655440003',
    'Fiqh Sunnah - Thaharah',
    'Sayyid Sabiq',
    'Panduan lengkap tentang bersuci dalam Islam',
    '550e8400-e29b-41d4-a716-446655440003',
    'https://example.com/pdfs/fiqh-sunnah-thaharah.pdf',
    'dQw4w9WgXcQ',
    'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    'https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg',
    false,
    30,
    1
  ),
  (
    '660e8400-e29b-41d4-a716-446655440004',
    'Aqidah Wasitiyyah',
    'Ibn Taymiyyah',
    'Penjelasan aqidah Islam yang lurus dan moderat',
    '550e8400-e29b-41d4-a716-446655440004',
    'https://example.com/pdfs/aqidah-wasitiyyah.pdf',
    'dQw4w9WgXcQ',
    'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    'https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg',
    true,
    90,
    1
  ),
  (
    '660e8400-e29b-41d4-a716-446655440005',
    'Sirah Nabawiyyah - Kelahiran Rasulullah',
    'Ibn Hisham',
    'Kisah kelahiran dan masa kecil Rasulullah SAW',
    '550e8400-e29b-41d4-a716-446655440005',
    'https://example.com/pdfs/sirah-kelahiran.pdf',
    'dQw4w9WgXcQ',
    'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    'https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg',
    true,
    75,
    1
  ),
  (
    '660e8400-e29b-41d4-a716-446655440006',
    'Akhlak Mulia - Adab Bergaul',
    'Imam Al-Ghazali',
    'Panduan berakhlak mulia dalam pergaulan sehari-hari',
    '550e8400-e29b-41d4-a716-446655440006',
    'https://example.com/pdfs/akhlak-mulia.pdf',
    'dQw4w9WgXcQ',
    'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    'https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg',
    false,
    40,
    1
  );

-- ============================================
-- DATABASE SETUP COMPLETE!
-- ============================================
-- 
-- Next steps:
-- 1. Verify all tables created successfully
-- 2. Check Row Level Security policies are active
-- 3. Test authentication and data access
-- 4. Create storage buckets for PDFs and thumbnails
-- 
-- Tables created:
-- - profiles (7 columns)
-- - categories (5 columns) 
-- - kitab (14 columns)
-- - subscriptions (9 columns)
-- - transactions (9 columns)
-- - saved_items (5 columns)
-- - reading_progress (6 columns)
-- 
-- Sample data inserted:
-- - 8 categories
-- - 6 sample kitab (mix of free and premium)
--
-- ============================================
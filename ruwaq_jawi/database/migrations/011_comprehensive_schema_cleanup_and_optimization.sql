-- =====================================================================================================
-- MIGRATION 011: COMPREHENSIVE SCHEMA CLEANUP AND OPTIMIZATION
-- =====================================================================================================
-- This migration performs comprehensive cleanup to optimize the Ruwaq Jawi database:
-- 1. Adds missing columns to existing tables (categories, kitab)
-- 2. Fixes and optimizes Foreign Key relationships
-- 3. Consolidates duplicate/overlapping tables
-- 4. Creates optimized indexes and constraints
-- 5. Updates RLS policies for security
-- 6. Adds proper triggers for updated_at columns
-- 
-- SAFE TO RUN: Uses IF NOT EXISTS and CREATE OR REPLACE patterns
-- =====================================================================================================

-- =====================================================================================================
-- STEP 1: CREATE HELPER FUNCTIONS AND TYPES
-- =====================================================================================================

-- Create updated_at trigger function (reusable)
CREATE OR REPLACE FUNCTION public.tg__set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create custom types for better data integrity
DO $$ 
BEGIN
    -- Subscription status enum
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subscription_status') THEN
        CREATE TYPE public.subscription_status AS ENUM (
            'trialing', 'active', 'past_due', 'canceled', 'paused', 'expired'
        );
    END IF;
    
    -- Payment status enum
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status') THEN
        CREATE TYPE public.payment_status AS ENUM (
            'requires_action', 'processing', 'succeeded', 'failed', 'refunded', 'canceled', 'pending'
        );
    END IF;
    
    -- Webhook status enum
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'webhook_status') THEN
        CREATE TYPE public.webhook_status AS ENUM (
            'pending', 'processed', 'failed', 'retrying'
        );
    END IF;
END $$;

-- =====================================================================================================
-- STEP 2: FIX AND OPTIMIZE EXISTING CORE TABLES (categories, kitab)
-- =====================================================================================================

-- Add missing columns to categories table
DO $$
BEGIN
    -- Add is_active column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'categories' AND column_name = 'is_active') THEN
        ALTER TABLE public.categories ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT true;
    END IF;
    
    -- Add updated_at column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'categories' AND column_name = 'updated_at') THEN
        ALTER TABLE public.categories ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
    END IF;
END $$;

-- Add missing columns to kitab table
DO $$
BEGIN
    -- Add is_active column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'kitab' AND column_name = 'is_active') THEN
        ALTER TABLE public.kitab ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT true;
    END IF;
    
    -- Add total_pages column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'kitab' AND column_name = 'total_pages') THEN
        ALTER TABLE public.kitab ADD COLUMN total_pages INTEGER NULL;
    END IF;
    
    -- Ensure updated_at column exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'kitab' AND column_name = 'updated_at') THEN
        ALTER TABLE public.kitab ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
    END IF;
END $$;

-- Add updated_at triggers to categories and kitab
DROP TRIGGER IF EXISTS t_categories_updated_at ON public.categories;
CREATE TRIGGER t_categories_updated_at 
    BEFORE UPDATE ON public.categories
    FOR EACH ROW EXECUTE FUNCTION public.tg__set_updated_at();

DROP TRIGGER IF EXISTS t_kitab_updated_at ON public.kitab;
CREATE TRIGGER t_kitab_updated_at 
    BEFORE UPDATE ON public.kitab
    FOR EACH ROW EXECUTE FUNCTION public.tg__set_updated_at();

-- =====================================================================================================
-- STEP 3: CREATE OPTIMIZED CANONICAL TABLES
-- =====================================================================================================

-- Create canonical subscriptions table (consolidating subscriptions & user_subscriptions)
CREATE TABLE IF NOT EXISTS public.subscriptions_new (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    plan_id TEXT NULL REFERENCES public.subscription_plans(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'expired', 'cancelled', 'trialing', 'past_due', 'paused')),
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    current_period_start TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    current_period_end TIMESTAMPTZ NOT NULL,
    canceled_at TIMESTAMPTZ NULL,
    auto_renew BOOLEAN NOT NULL DEFAULT true,
    provider TEXT NOT NULL DEFAULT 'manual' CHECK (provider IN ('stripe', 'toyyibpay', 'hitpay', 'app_store', 'play_store', 'manual')),
    provider_customer_id TEXT NULL,
    provider_subscription_id TEXT NULL,
    amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    currency TEXT NOT NULL DEFAULT 'MYR',
    metadata JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT valid_amount CHECK (amount >= 0),
    CONSTRAINT valid_currency CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT valid_period CHECK (current_period_end > current_period_start)
);

-- Create canonical payments table (consolidating transactions & payments)
CREATE TABLE IF NOT EXISTS public.payments_new (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    subscription_id UUID NULL REFERENCES public.subscriptions_new(id) ON DELETE SET NULL,
    amount_cents INTEGER NOT NULL CHECK (amount_cents >= 0),
    currency CHAR(3) NOT NULL DEFAULT 'MYR',
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('requires_action', 'processing', 'succeeded', 'failed', 'refunded', 'canceled', 'pending', 'completed')),
    provider TEXT NOT NULL DEFAULT 'manual' CHECK (provider IN ('stripe', 'toyyibpay', 'hitpay', 'app_store', 'play_store', 'manual')),
    provider_payment_id TEXT NULL,
    payment_intent_id TEXT NULL,
    reference_number TEXT NULL,
    receipt_url TEXT NULL,
    paid_at TIMESTAMPTZ NULL,
    description TEXT NULL,
    raw_payload JSONB NOT NULL DEFAULT '{}',
    metadata JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT valid_currency_format CHECK (currency ~ '^[A-Z]{3}$')
);

-- Create canonical reading_progress table (consolidating reading_progress & ebook_reading_progress)
CREATE TABLE IF NOT EXISTS public.reading_progress_new (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    kitab_id UUID NOT NULL REFERENCES public.kitab(id) ON DELETE CASCADE,
    
    -- Video progress tracking
    video_progress INTEGER DEFAULT 0, -- seconds watched
    video_duration INTEGER NULL, -- total video duration in seconds
    
    -- PDF/E-book progress tracking
    current_page INTEGER DEFAULT 1,
    total_pages INTEGER NULL,
    progress_percentage DECIMAL(5,2) DEFAULT 0.00 CHECK (progress_percentage BETWEEN 0 AND 100),
    
    -- General tracking
    last_accessed TIMESTAMPTZ DEFAULT NOW(),
    bookmarks JSONB DEFAULT '[]'::jsonb, -- Page bookmarks as JSON array
    notes JSONB DEFAULT '{}'::jsonb, -- Page notes as JSON object
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Constraints
    UNIQUE(user_id, kitab_id),
    CONSTRAINT valid_current_page CHECK (current_page > 0),
    CONSTRAINT valid_total_pages CHECK (total_pages IS NULL OR total_pages > 0),
    CONSTRAINT valid_video_progress CHECK (video_progress >= 0)
);

-- Create canonical webhook_events table (consolidating webhook_events, webhook_logs, etc)
CREATE TABLE IF NOT EXISTS public.webhook_events_new (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider TEXT NOT NULL,
    event_type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processed', 'failed', 'retrying')),
    provider_event_id TEXT NULL,
    bill_code TEXT NULL,
    transaction_id TEXT NULL,
    reference_number TEXT NULL,
    signature TEXT NULL,
    source_ip INET NULL,
    payload JSONB NOT NULL,
    processed_payload JSONB NULL, -- Processed/normalized payload
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMPTZ NULL,
    delivery_attempts INTEGER NOT NULL DEFAULT 0,
    error_message TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =====================================================================================================
-- STEP 4: CREATE OPTIMIZED INDEXES
-- =====================================================================================================

-- Categories indexes
CREATE INDEX IF NOT EXISTS idx_categories_is_active ON public.categories(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_categories_sort_order_active ON public.categories(sort_order) WHERE is_active = true;

-- Kitab indexes  
CREATE INDEX IF NOT EXISTS idx_kitab_is_active ON public.kitab(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_kitab_category_active ON public.kitab(category_id, is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_kitab_premium_active ON public.kitab(is_premium, is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_kitab_ebook_available ON public.kitab(is_ebook_available) WHERE is_ebook_available = true;

-- Subscriptions indexes
CREATE UNIQUE INDEX IF NOT EXISTS uq_subscriptions_provider_id 
    ON public.subscriptions_new(provider_subscription_id) 
    WHERE provider_subscription_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_active_subscription_per_user
    ON public.subscriptions_new(user_id, plan_id)
    WHERE status IN ('active', 'trialing');

CREATE INDEX IF NOT EXISTS idx_subscriptions_user_status ON public.subscriptions_new(user_id, status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON public.subscriptions_new(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_current_period_end ON public.subscriptions_new(current_period_end);

-- Payments indexes
CREATE UNIQUE INDEX IF NOT EXISTS uq_payments_provider_id 
    ON public.payments_new(provider_payment_id) 
    WHERE provider_payment_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_payments_user_created ON public.payments_new(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payments_subscription ON public.payments_new(subscription_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON public.payments_new(status);
CREATE INDEX IF NOT EXISTS idx_payments_provider ON public.payments_new(provider);

-- Reading progress indexes
CREATE INDEX IF NOT EXISTS idx_reading_progress_user ON public.reading_progress_new(user_id);
CREATE INDEX IF NOT EXISTS idx_reading_progress_kitab ON public.reading_progress_new(kitab_id);
CREATE INDEX IF NOT EXISTS idx_reading_progress_last_accessed ON public.reading_progress_new(last_accessed DESC);
CREATE INDEX IF NOT EXISTS idx_reading_progress_updated ON public.reading_progress_new(updated_at DESC);

-- Webhook events indexes
CREATE UNIQUE INDEX IF NOT EXISTS uq_webhook_provider_event_id 
    ON public.webhook_events_new(provider_event_id, provider) 
    WHERE provider_event_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_webhook_events_status_received ON public.webhook_events_new(status, received_at DESC);
CREATE INDEX IF NOT EXISTS idx_webhook_events_provider ON public.webhook_events_new(provider);
CREATE INDEX IF NOT EXISTS idx_webhook_events_bill_code ON public.webhook_events_new(bill_code);
CREATE INDEX IF NOT EXISTS idx_webhook_events_transaction_id ON public.webhook_events_new(transaction_id);

-- =====================================================================================================
-- STEP 5: ADD TRIGGERS TO NEW TABLES
-- =====================================================================================================

-- Subscriptions updated_at trigger
DROP TRIGGER IF EXISTS t_subscriptions_updated_at ON public.subscriptions_new;
CREATE TRIGGER t_subscriptions_updated_at 
    BEFORE UPDATE ON public.subscriptions_new
    FOR EACH ROW EXECUTE FUNCTION public.tg__set_updated_at();

-- Payments updated_at trigger
DROP TRIGGER IF EXISTS t_payments_updated_at ON public.payments_new;
CREATE TRIGGER t_payments_updated_at 
    BEFORE UPDATE ON public.payments_new
    FOR EACH ROW EXECUTE FUNCTION public.tg__set_updated_at();

-- Reading progress updated_at trigger
DROP TRIGGER IF EXISTS t_reading_progress_updated_at ON public.reading_progress_new;
CREATE TRIGGER t_reading_progress_updated_at 
    BEFORE UPDATE ON public.reading_progress_new
    FOR EACH ROW EXECUTE FUNCTION public.tg__set_updated_at();

-- Webhook events updated_at trigger
DROP TRIGGER IF EXISTS t_webhook_events_updated_at ON public.webhook_events_new;
CREATE TRIGGER t_webhook_events_updated_at 
    BEFORE UPDATE ON public.webhook_events_new
    FOR EACH ROW EXECUTE FUNCTION public.tg__set_updated_at();

-- =====================================================================================================
-- STEP 6: ENABLE ROW LEVEL SECURITY (RLS)
-- =====================================================================================================

-- Enable RLS on new tables
ALTER TABLE public.subscriptions_new ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments_new ENABLE ROW LEVEL SECURITY;  
ALTER TABLE public.reading_progress_new ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.webhook_events_new ENABLE ROW LEVEL SECURITY;

-- Update RLS on existing tables
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kitab ENABLE ROW LEVEL SECURITY;

-- =====================================================================================================
-- STEP 7: CREATE RLS POLICIES
-- =====================================================================================================

-- Categories policies
DROP POLICY IF EXISTS "Public can view active categories" ON public.categories;
CREATE POLICY "Public can view active categories" ON public.categories
    FOR SELECT USING (is_active = true);

DROP POLICY IF EXISTS "Service role full access categories" ON public.categories;
CREATE POLICY "Service role full access categories" ON public.categories
    FOR ALL USING (auth.role() = 'service_role');

-- Kitab policies
DROP POLICY IF EXISTS "Public can view active non-premium kitab" ON public.kitab;
CREATE POLICY "Public can view active non-premium kitab" ON public.kitab
    FOR SELECT USING (is_active = true AND NOT is_premium);

DROP POLICY IF EXISTS "Subscribers can view active premium kitab" ON public.kitab;
CREATE POLICY "Subscribers can view active premium kitab" ON public.kitab
    FOR SELECT USING (
        is_active = true AND 
        is_premium = true AND
        auth.uid() IS NOT NULL AND
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() 
            AND subscription_status = 'active'
        )
    );

DROP POLICY IF EXISTS "Service role full access kitab" ON public.kitab;
CREATE POLICY "Service role full access kitab" ON public.kitab
    FOR ALL USING (auth.role() = 'service_role');

-- Subscriptions policies
DROP POLICY IF EXISTS "Users can view own subscriptions" ON public.subscriptions_new;
CREATE POLICY "Users can view own subscriptions" ON public.subscriptions_new
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Service role full access subscriptions" ON public.subscriptions_new;
CREATE POLICY "Service role full access subscriptions" ON public.subscriptions_new
    FOR ALL USING (auth.role() = 'service_role');

-- Payments policies
DROP POLICY IF EXISTS "Users can view own payments" ON public.payments_new;
CREATE POLICY "Users can view own payments" ON public.payments_new
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Service role full access payments" ON public.payments_new;
CREATE POLICY "Service role full access payments" ON public.payments_new
    FOR ALL USING (auth.role() = 'service_role');

-- Reading progress policies
DROP POLICY IF EXISTS "Users can manage own reading progress" ON public.reading_progress_new;
CREATE POLICY "Users can manage own reading progress" ON public.reading_progress_new
    FOR ALL USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Service role full access reading progress" ON public.reading_progress_new;
CREATE POLICY "Service role full access reading progress" ON public.reading_progress_new
    FOR ALL USING (auth.role() = 'service_role');

-- Webhook events policies (service role only)
DROP POLICY IF EXISTS "Service role full access webhook events" ON public.webhook_events_new;
CREATE POLICY "Service role full access webhook events" ON public.webhook_events_new
    FOR ALL USING (auth.role() = 'service_role');

-- =====================================================================================================
-- STEP 8: GRANT NECESSARY PERMISSIONS
-- =====================================================================================================

-- Grant permissions to authenticated users
GRANT SELECT ON public.categories TO authenticated, anon;
GRANT SELECT ON public.kitab TO authenticated, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.subscriptions_new TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.payments_new TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.reading_progress_new TO authenticated;

-- Grant full permissions to service role
GRANT ALL ON public.categories TO service_role;
GRANT ALL ON public.kitab TO service_role;
GRANT ALL ON public.subscriptions_new TO service_role;
GRANT ALL ON public.payments_new TO service_role;
GRANT ALL ON public.reading_progress_new TO service_role;
GRANT ALL ON public.webhook_events_new TO service_role;

-- Grant sequence permissions
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated, service_role;

-- =====================================================================================================
-- STEP 9: CREATE HELPFUL FUNCTIONS
-- =====================================================================================================

-- Function to get user's active subscription
CREATE OR REPLACE FUNCTION public.get_user_active_subscription(user_uuid UUID)
RETURNS TABLE (
    id UUID,
    plan_id TEXT,
    status TEXT,
    current_period_end TIMESTAMPTZ,
    provider TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id,
        s.plan_id,
        s.status,
        s.current_period_end,
        s.provider
    FROM public.subscriptions_new s
    WHERE s.user_id = user_uuid 
    AND s.status IN ('active', 'trialing')
    AND s.current_period_end > NOW()
    ORDER BY s.current_period_end DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user has active subscription
CREATE OR REPLACE FUNCTION public.user_has_active_subscription(user_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.subscriptions_new
        WHERE user_id = user_uuid 
        AND status IN ('active', 'trialing')
        AND current_period_end > NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update reading progress with automatic percentage calculation
CREATE OR REPLACE FUNCTION public.update_reading_progress(
    p_kitab_id UUID,
    p_current_page INTEGER DEFAULT NULL,
    p_total_pages INTEGER DEFAULT NULL,
    p_video_progress INTEGER DEFAULT NULL,
    p_video_duration INTEGER DEFAULT NULL,
    p_bookmarks JSONB DEFAULT NULL,
    p_notes JSONB DEFAULT NULL
)
RETURNS public.reading_progress_new AS $$
DECLARE
    result public.reading_progress_new;
    calculated_progress DECIMAL(5,2) := 0;
BEGIN
    -- Calculate progress percentage based on available data
    IF p_total_pages IS NOT NULL AND p_total_pages > 0 AND p_current_page IS NOT NULL THEN
        calculated_progress = ROUND((p_current_page::DECIMAL / p_total_pages::DECIMAL) * 100, 2);
    ELSIF p_video_duration IS NOT NULL AND p_video_duration > 0 AND p_video_progress IS NOT NULL THEN
        calculated_progress = ROUND((p_video_progress::DECIMAL / p_video_duration::DECIMAL) * 100, 2);
    END IF;
    
    -- Insert or update reading progress
    INSERT INTO public.reading_progress_new (
        user_id, kitab_id, current_page, total_pages, 
        video_progress, video_duration, progress_percentage,
        bookmarks, notes, last_accessed, updated_at
    )
    VALUES (
        auth.uid(), p_kitab_id, 
        COALESCE(p_current_page, 1), p_total_pages,
        COALESCE(p_video_progress, 0), p_video_duration, calculated_progress,
        COALESCE(p_bookmarks, '[]'::jsonb),
        COALESCE(p_notes, '{}'::jsonb),
        NOW(), NOW()
    )
    ON CONFLICT (user_id, kitab_id) 
    DO UPDATE SET
        current_page = COALESCE(EXCLUDED.current_page, reading_progress_new.current_page),
        total_pages = COALESCE(EXCLUDED.total_pages, reading_progress_new.total_pages),
        video_progress = COALESCE(EXCLUDED.video_progress, reading_progress_new.video_progress),
        video_duration = COALESCE(EXCLUDED.video_duration, reading_progress_new.video_duration),
        progress_percentage = calculated_progress,
        bookmarks = COALESCE(EXCLUDED.bookmarks, reading_progress_new.bookmarks),
        notes = COALESCE(EXCLUDED.notes, reading_progress_new.notes),
        last_accessed = NOW(),
        updated_at = NOW()
    RETURNING * INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================================================
-- STEP 10: CREATE USEFUL VIEWS
-- =====================================================================================================

-- View for user's reading progress with kitab details
CREATE OR REPLACE VIEW public.user_reading_progress_view AS
SELECT 
    rp.id,
    rp.user_id,
    rp.kitab_id,
    rp.current_page,
    rp.total_pages,
    rp.video_progress,
    rp.video_duration,
    rp.progress_percentage,
    rp.last_accessed,
    rp.bookmarks,
    rp.notes,
    k.title as kitab_title,
    k.author as kitab_author,
    k.thumbnail_url,
    k.is_premium,
    c.name as category_name
FROM public.reading_progress_new rp
JOIN public.kitab k ON rp.kitab_id = k.id
LEFT JOIN public.categories c ON k.category_id = c.id
WHERE rp.user_id = auth.uid() AND k.is_active = true
ORDER BY rp.last_accessed DESC;

-- View for available kitab with user access info
CREATE OR REPLACE VIEW public.available_kitab_view AS
SELECT 
    k.id,
    k.title,
    k.author,
    k.description,
    k.category_id,
    k.thumbnail_url,
    k.is_premium,
    k.duration_minutes,
    k.total_pages,
    k.is_ebook_available,
    k.created_at,
    c.name as category_name,
    c.icon_url as category_icon,
    -- Check if current user has access
    CASE 
        WHEN NOT k.is_premium THEN true
        WHEN auth.uid() IS NOT NULL AND public.user_has_active_subscription(auth.uid()) THEN true
        ELSE false
    END as user_has_access,
    -- Get user's reading progress if exists
    rp.progress_percentage,
    rp.last_accessed as last_read_at
FROM public.kitab k
LEFT JOIN public.categories c ON k.category_id = c.id
LEFT JOIN public.reading_progress_new rp ON k.id = rp.kitab_id AND rp.user_id = auth.uid()
WHERE k.is_active = true AND (c.is_active = true OR c.is_active IS NULL)
ORDER BY k.sort_order, k.created_at DESC;

-- =====================================================================================================
-- FINAL NOTES AND VERIFICATION QUERIES
-- =====================================================================================================

-- Insert migration record
INSERT INTO public.schema_migrations (version, applied_at) 
VALUES ('011_comprehensive_schema_cleanup_and_optimization', NOW())
ON CONFLICT (version) DO UPDATE SET applied_at = NOW();

-- =====================================================================================================
-- VERIFICATION QUERIES (for manual testing)
-- =====================================================================================================
/*
-- Verify new tables created successfully
SELECT table_name, table_type 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name LIKE '%_new'
ORDER BY table_name;

-- Check missing columns added to existing tables
SELECT table_name, column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name IN ('categories', 'kitab')
AND column_name IN ('is_active', 'updated_at', 'total_pages')
ORDER BY table_name, column_name;

-- Verify indexes created
SELECT schemaname, tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
AND tablename IN ('categories', 'kitab', 'subscriptions_new', 'payments_new', 'reading_progress_new', 'webhook_events_new')
ORDER BY tablename, indexname;

-- Check RLS policies
SELECT schemaname, tablename, policyname, cmd, roles, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- Test helper functions
SELECT public.user_has_active_subscription('00000000-0000-0000-0000-000000000000');
SELECT * FROM public.get_user_active_subscription('00000000-0000-0000-0000-000000000000');
*/

-- =====================================================================================================
-- MIGRATION COMPLETE
-- =====================================================================================================

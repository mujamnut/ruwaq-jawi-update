-- Database Functions untuk Dashboard Analytics
-- Script ini perlu dijalankan dalam Supabase SQL Editor

-- 1. Function untuk User Statistics
CREATE OR REPLACE FUNCTION public.get_user_stats()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    total_users integer := 0;
    active_subscriptions integer := 0;
    inactive_users integer := 0;
    result json;
BEGIN
    -- Get total users
    SELECT COUNT(*) INTO total_users
    FROM profiles;
    
    -- Get active subscriptions
    SELECT COUNT(*) INTO active_subscriptions
    FROM subscriptions 
    WHERE status = 'active' 
    AND current_period_end > now();
    
    -- Get inactive users (users without recent activity)
    SELECT COUNT(*) INTO inactive_users
    FROM profiles 
    WHERE last_sign_in_at < (now() - interval '30 days') 
    OR last_sign_in_at IS NULL;
    
    -- Build result JSON
    result := json_build_object(
        'total_users', total_users,
        'active_subscriptions', active_subscriptions,
        'inactive_users', inactive_users
    );
    
    RETURN result;
EXCEPTION
    WHEN OTHERS THEN
        -- Return default values if there's an error
        RETURN json_build_object(
            'total_users', 0,
            'active_subscriptions', 0,
            'inactive_users', 0
        );
END;
$$;

-- 2. Function untuk Payment Statistics
CREATE OR REPLACE FUNCTION public.get_payment_stats()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    pending_payments integer := 0;
    successful_payments integer := 0;
    total_revenue numeric := 0.0;
    monthly_revenue numeric := 0.0;
    result json;
BEGIN
    -- Get pending payments
    SELECT COUNT(*) INTO pending_payments
    FROM payments 
    WHERE status = 'pending';
    
    -- Get successful payments
    SELECT COUNT(*) INTO successful_payments
    FROM payments 
    WHERE status = 'succeeded';
    
    -- Get total revenue (convert cents to ringgit)
    SELECT COALESCE(SUM(amount_cents::numeric / 100), 0) INTO total_revenue
    FROM payments 
    WHERE status = 'succeeded';
    
    -- Get monthly revenue (current month)
    SELECT COALESCE(SUM(amount_cents::numeric / 100), 0) INTO monthly_revenue
    FROM payments 
    WHERE status = 'succeeded' 
    AND DATE_TRUNC('month', paid_at) = DATE_TRUNC('month', now());
    
    -- Build result JSON
    result := json_build_object(
        'pending_payments', pending_payments,
        'successful_payments', successful_payments,
        'total_revenue', total_revenue,
        'monthly_revenue', monthly_revenue
    );
    
    RETURN result;
EXCEPTION
    WHEN OTHERS THEN
        -- Return default values if there's an error
        RETURN json_build_object(
            'pending_payments', 0,
            'successful_payments', 0,
            'total_revenue', 0.0,
            'monthly_revenue', 0.0
        );
END;
$$;

-- 3. Function untuk Growth Statistics
CREATE OR REPLACE FUNCTION public.get_growth_stats()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_month_users integer := 0;
    previous_month_users integer := 0;
    current_month_subscriptions integer := 0;
    previous_month_subscriptions integer := 0;
    current_month_revenue numeric := 0.0;
    previous_month_revenue numeric := 0.0;
    user_growth_percent numeric := 0.0;
    subscription_growth_percent numeric := 0.0;
    revenue_growth_percent numeric := 0.0;
    result json;
BEGIN
    -- Get current month users
    SELECT COUNT(*) INTO current_month_users
    FROM profiles 
    WHERE DATE_TRUNC('month', created_at) = DATE_TRUNC('month', now());
    
    -- Get previous month users
    SELECT COUNT(*) INTO previous_month_users
    FROM profiles 
    WHERE DATE_TRUNC('month', created_at) = DATE_TRUNC('month', now() - interval '1 month');
    
    -- Get current month subscriptions
    SELECT COUNT(*) INTO current_month_subscriptions
    FROM subscriptions 
    WHERE DATE_TRUNC('month', created_at) = DATE_TRUNC('month', now())
    AND status = 'active';
    
    -- Get previous month subscriptions
    SELECT COUNT(*) INTO previous_month_subscriptions
    FROM subscriptions 
    WHERE DATE_TRUNC('month', created_at) = DATE_TRUNC('month', now() - interval '1 month')
    AND status = 'active';
    
    -- Get current month revenue
    SELECT COALESCE(SUM(amount_cents::numeric / 100), 0) INTO current_month_revenue
    FROM payments 
    WHERE status = 'succeeded' 
    AND DATE_TRUNC('month', paid_at) = DATE_TRUNC('month', now());
    
    -- Get previous month revenue
    SELECT COALESCE(SUM(amount_cents::numeric / 100), 0) INTO previous_month_revenue
    FROM payments 
    WHERE status = 'succeeded' 
    AND DATE_TRUNC('month', paid_at) = DATE_TRUNC('month', now() - interval '1 month');
    
    -- Calculate growth percentages
    IF previous_month_users > 0 THEN
        user_growth_percent := ROUND(((current_month_users::numeric - previous_month_users::numeric) / previous_month_users::numeric) * 100, 1);
    ELSE
        user_growth_percent := CASE WHEN current_month_users > 0 THEN 100.0 ELSE 0.0 END;
    END IF;
    
    IF previous_month_subscriptions > 0 THEN
        subscription_growth_percent := ROUND(((current_month_subscriptions::numeric - previous_month_subscriptions::numeric) / previous_month_subscriptions::numeric) * 100, 1);
    ELSE
        subscription_growth_percent := CASE WHEN current_month_subscriptions > 0 THEN 100.0 ELSE 0.0 END;
    END IF;
    
    IF previous_month_revenue > 0 THEN
        revenue_growth_percent := ROUND(((current_month_revenue - previous_month_revenue) / previous_month_revenue) * 100, 1);
    ELSE
        revenue_growth_percent := CASE WHEN current_month_revenue > 0 THEN 100.0 ELSE 0.0 END;
    END IF;
    
    -- Build result JSON
    result := json_build_object(
        'current_month_users', current_month_users,
        'previous_month_users', previous_month_users,
        'current_month_subscriptions', current_month_subscriptions,
        'previous_month_subscriptions', previous_month_subscriptions,
        'current_month_revenue', current_month_revenue,
        'previous_month_revenue', previous_month_revenue,
        'user_growth_percent', user_growth_percent,
        'subscription_growth_percent', subscription_growth_percent,
        'revenue_growth_percent', revenue_growth_percent
    );
    
    RETURN result;
EXCEPTION
    WHEN OTHERS THEN
        -- Return default values if there's an error
        RETURN json_build_object(
            'current_month_users', 0,
            'previous_month_users', 0,
            'current_month_subscriptions', 0,
            'previous_month_subscriptions', 0,
            'current_month_revenue', 0.0,
            'previous_month_revenue', 0.0,
            'user_growth_percent', 0.0,
            'subscription_growth_percent', 0.0,
            'revenue_growth_percent', 0.0
        );
END;
$$;

-- 4. Bonus function untuk calculate total revenue (sudah dipanggil dalam kod)
CREATE OR REPLACE FUNCTION public.calculate_total_revenue()
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    total_revenue numeric := 0.0;
BEGIN
    SELECT COALESCE(SUM(amount_cents::numeric / 100), 0) INTO total_revenue
    FROM payments 
    WHERE status = 'succeeded';
    
    RETURN total_revenue;
EXCEPTION
    WHEN OTHERS THEN
        RETURN 0.0;
END;
$$;

-- Grant permissions untuk functions ini
GRANT EXECUTE ON FUNCTION public.get_user_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_payment_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_growth_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.calculate_total_revenue() TO authenticated;

-- Optional: Grant untuk anon role jika diperlukan (tidak disarankan untuk data sensitif)
-- GRANT EXECUTE ON FUNCTION public.get_user_stats() TO anon;
-- GRANT EXECUTE ON FUNCTION public.get_payment_stats() TO anon;
-- GRANT EXECUTE ON FUNCTION public.get_growth_stats() TO anon;

-- Test functions (boleh uncomment untuk testing)
-- SELECT public.get_user_stats();
-- SELECT public.get_payment_stats();
-- SELECT public.get_growth_stats();
-- SELECT public.calculate_total_revenue();

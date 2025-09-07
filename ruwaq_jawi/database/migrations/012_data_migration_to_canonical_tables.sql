-- =====================================================================================================
-- MIGRATION 012: DATA MIGRATION TO CANONICAL TABLES
-- =====================================================================================================
-- This migration safely migrates data from old/duplicate tables to the new canonical tables
-- Created by: 011_comprehensive_schema_cleanup_and_optimization.sql
-- 
-- IMPORTANT: Run this AFTER running migration 011
-- 
-- This migration will:
-- 1. Migrate data from old subscription/payment tables to new canonical ones
-- 2. Merge reading progress data from multiple sources
-- 3. Consolidate webhook events data
-- 4. Handle data deduplication and conflicts safely
-- =====================================================================================================

-- =====================================================================================================
-- STEP 1: VERIFY PREREQUISITES AND SETUP
-- =====================================================================================================

-- Check if new canonical tables exist (should be created by migration 011)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'subscriptions_new') THEN
        RAISE EXCEPTION 'Migration 011 must be run first - subscriptions_new table not found';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'payments_new') THEN
        RAISE EXCEPTION 'Migration 011 must be run first - payments_new table not found';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'reading_progress_new') THEN
        RAISE EXCEPTION 'Migration 011 must be run first - reading_progress_new table not found';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'webhook_events_new') THEN
        RAISE EXCEPTION 'Migration 011 must be run first - webhook_events_new table not found';
    END IF;
END $$;

-- Create temporary logging table for migration tracking
CREATE TABLE IF NOT EXISTS migration_log (
    id SERIAL PRIMARY KEY,
    step TEXT NOT NULL,
    table_name TEXT,
    rows_processed INTEGER DEFAULT 0,
    rows_success INTEGER DEFAULT 0,
    rows_failed INTEGER DEFAULT 0,
    error_message TEXT,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

-- Log start of migration
INSERT INTO migration_log (step, table_name) 
VALUES ('START_DATA_MIGRATION', 'ALL');

-- =====================================================================================================
-- STEP 2: MIGRATE SUBSCRIPTION DATA
-- =====================================================================================================

-- Migrate from existing subscriptions table (if it has different structure than user_subscriptions)
INSERT INTO migration_log (step, table_name, started_at) 
VALUES ('MIGRATE_SUBSCRIPTIONS', 'subscriptions', NOW());

DO $$
DECLARE
    processed_count INTEGER := 0;
    success_count INTEGER := 0;
    error_count INTEGER := 0;
    rec RECORD;
BEGIN
    -- Check if old subscriptions table exists and has data
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'subscriptions') THEN
        
        -- Migrate data from old subscriptions table
        FOR rec IN 
            SELECT 
                id,
                user_id,
                CASE 
                    WHEN plan_type = '1month' THEN 'monthly_basic'
                    WHEN plan_type = '3month' THEN 'quarterly_premium'
                    WHEN plan_type = '6month' THEN 'biannual_premium'
                    WHEN plan_type = '12month' THEN 'yearly_premium'
                    ELSE plan_type
                END as plan_id,
                status,
                start_date as started_at,
                start_date as current_period_start,
                end_date as current_period_end,
                CASE WHEN status = 'cancelled' THEN end_date ELSE NULL END as canceled_at,
                true as auto_renew,
                COALESCE(payment_method, 'manual') as provider,
                NULL as provider_customer_id,
                NULL as provider_subscription_id,
                amount,
                currency,
                '{}' as metadata,
                created_at,
                NOW() as updated_at
            FROM public.subscriptions
        LOOP
            BEGIN
                processed_count := processed_count + 1;
                
                INSERT INTO public.subscriptions_new (
                    id, user_id, plan_id, status, started_at, current_period_start,
                    current_period_end, canceled_at, auto_renew, provider,
                    provider_customer_id, provider_subscription_id, amount, currency,
                    metadata, created_at, updated_at
                ) VALUES (
                    rec.id, rec.user_id, rec.plan_id, rec.status, rec.started_at, rec.current_period_start,
                    rec.current_period_end, rec.canceled_at, rec.auto_renew, rec.provider,
                    rec.provider_customer_id, rec.provider_subscription_id, rec.amount, rec.currency,
                    rec.metadata::jsonb, rec.created_at, rec.updated_at
                ) ON CONFLICT (id) DO NOTHING;
                
                success_count := success_count + 1;
                
            EXCEPTION WHEN OTHERS THEN
                error_count := error_count + 1;
                RAISE NOTICE 'Error migrating subscription %: %', rec.id, SQLERRM;
            END;
        END LOOP;
    END IF;
    
    -- Update migration log
    UPDATE migration_log 
    SET rows_processed = processed_count,
        rows_success = success_count,
        rows_failed = error_count,
        completed_at = NOW()
    WHERE step = 'MIGRATE_SUBSCRIPTIONS' AND table_name = 'subscriptions' 
    AND completed_at IS NULL;
END $$;

-- Migrate from user_subscriptions table (if exists)
INSERT INTO migration_log (step, table_name, started_at) 
VALUES ('MIGRATE_USER_SUBSCRIPTIONS', 'user_subscriptions', NOW());

DO $$
DECLARE
    processed_count INTEGER := 0;
    success_count INTEGER := 0;
    error_count INTEGER := 0;
    rec RECORD;
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_subscriptions') THEN
        
        FOR rec IN 
            SELECT 
                id,
                user_id,
                subscription_plan_id as plan_id,
                status,
                COALESCE(start_date, created_at) as started_at,
                COALESCE(start_date, created_at) as current_period_start,
                end_date as current_period_end,
                CASE WHEN status IN ('canceled', 'cancelled') THEN end_date ELSE NULL END as canceled_at,
                true as auto_renew,
                'manual' as provider,
                NULL as provider_customer_id,
                payment_id as provider_subscription_id,
                amount,
                currency,
                '{}' as metadata,
                created_at,
                updated_at
            FROM public.user_subscriptions
            WHERE id NOT IN (SELECT id FROM public.subscriptions_new) -- Avoid duplicates
        LOOP
            BEGIN
                processed_count := processed_count + 1;
                
                INSERT INTO public.subscriptions_new (
                    id, user_id, plan_id, status, started_at, current_period_start,
                    current_period_end, canceled_at, auto_renew, provider,
                    provider_customer_id, provider_subscription_id, amount, currency,
                    metadata, created_at, updated_at
                ) VALUES (
                    rec.id, rec.user_id, rec.plan_id, rec.status, rec.started_at, rec.current_period_start,
                    rec.current_period_end, rec.canceled_at, rec.auto_renew, rec.provider,
                    rec.provider_customer_id, rec.provider_subscription_id, rec.amount, rec.currency,
                    rec.metadata::jsonb, rec.created_at, rec.updated_at
                ) ON CONFLICT (id) DO NOTHING;
                
                success_count := success_count + 1;
                
            EXCEPTION WHEN OTHERS THEN
                error_count := error_count + 1;
                RAISE NOTICE 'Error migrating user_subscription %: %', rec.id, SQLERRM;
            END;
        END LOOP;
    END IF;
    
    UPDATE migration_log 
    SET rows_processed = processed_count,
        rows_success = success_count,
        rows_failed = error_count,
        completed_at = NOW()
    WHERE step = 'MIGRATE_USER_SUBSCRIPTIONS' AND table_name = 'user_subscriptions'
    AND completed_at IS NULL;
END $$;

-- =====================================================================================================
-- STEP 3: MIGRATE PAYMENT DATA
-- =====================================================================================================

-- Migrate from transactions table
INSERT INTO migration_log (step, table_name, started_at) 
VALUES ('MIGRATE_TRANSACTIONS', 'transactions', NOW());

DO $$
DECLARE
    processed_count INTEGER := 0;
    success_count INTEGER := 0;
    error_count INTEGER := 0;
    rec RECORD;
    subscription_id_ref UUID;
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'transactions') THEN
        
        FOR rec IN 
            SELECT 
                id,
                user_id,
                subscription_id,
                amount,
                currency,
                payment_method,
                gateway_transaction_id,
                status,
                metadata,
                created_at
            FROM public.transactions
        LOOP
            BEGIN
                processed_count := processed_count + 1;
                
                -- Try to find matching subscription in new table
                SELECT id INTO subscription_id_ref 
                FROM public.subscriptions_new 
                WHERE id = rec.subscription_id 
                   OR (user_id = rec.user_id AND provider_subscription_id = rec.gateway_transaction_id)
                LIMIT 1;
                
                INSERT INTO public.payments_new (
                    id, user_id, subscription_id, amount_cents, currency, status,
                    provider, provider_payment_id, reference_number, 
                    paid_at, raw_payload, created_at, updated_at
                ) VALUES (
                    rec.id, rec.user_id, subscription_id_ref, 
                    ROUND(rec.amount * 100), rec.currency,
                    CASE rec.status 
                        WHEN 'completed' THEN 'succeeded'
                        WHEN 'failed' THEN 'failed'
                        WHEN 'refunded' THEN 'refunded'
                        ELSE 'pending'
                    END,
                    COALESCE(rec.payment_method, 'manual'),
                    rec.gateway_transaction_id,
                    rec.gateway_transaction_id,
                    CASE WHEN rec.status = 'completed' THEN rec.created_at ELSE NULL END,
                    COALESCE(rec.metadata, '{}'),
                    rec.created_at, NOW()
                ) ON CONFLICT (id) DO NOTHING;
                
                success_count := success_count + 1;
                
            EXCEPTION WHEN OTHERS THEN
                error_count := error_count + 1;
                RAISE NOTICE 'Error migrating transaction %: %', rec.id, SQLERRM;
            END;
        END LOOP;
    END IF;
    
    UPDATE migration_log 
    SET rows_processed = processed_count,
        rows_success = success_count,
        rows_failed = error_count,
        completed_at = NOW()
    WHERE step = 'MIGRATE_TRANSACTIONS' AND table_name = 'transactions'
    AND completed_at IS NULL;
END $$;

-- Migrate from payments table (if different from transactions)
INSERT INTO migration_log (step, table_name, started_at) 
VALUES ('MIGRATE_PAYMENTS', 'payments', NOW());

DO $$
DECLARE
    processed_count INTEGER := 0;
    success_count INTEGER := 0;
    error_count INTEGER := 0;
    rec RECORD;
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'payments') THEN
        
        FOR rec IN 
            SELECT 
                id,
                user_id,
                payment_id,
                reference_number,
                amount,
                currency,
                status,
                payment_method,
                paid_at,
                metadata,
                created_at
            FROM public.payments
            WHERE id NOT IN (SELECT id FROM public.payments_new) -- Avoid duplicates
        LOOP
            BEGIN
                processed_count := processed_count + 1;
                
                INSERT INTO public.payments_new (
                    id, user_id, subscription_id, amount_cents, currency, status,
                    provider, provider_payment_id, reference_number, 
                    paid_at, raw_payload, created_at, updated_at
                ) VALUES (
                    rec.id, rec.user_id, NULL,
                    ROUND(rec.amount * 100), rec.currency, rec.status,
                    COALESCE(rec.payment_method, 'manual'),
                    rec.payment_id, rec.reference_number,
                    rec.paid_at, COALESCE(rec.metadata, '{}'),
                    rec.created_at, NOW()
                ) ON CONFLICT (id) DO NOTHING;
                
                success_count := success_count + 1;
                
            EXCEPTION WHEN OTHERS THEN
                error_count := error_count + 1;
                RAISE NOTICE 'Error migrating payment %: %', rec.id, SQLERRM;
            END;
        END LOOP;
    END IF;
    
    UPDATE migration_log 
    SET rows_processed = processed_count,
        rows_success = success_count,
        rows_failed = error_count,
        completed_at = NOW()
    WHERE step = 'MIGRATE_PAYMENTS' AND table_name = 'payments'
    AND completed_at IS NULL;
END $$;

-- =====================================================================================================
-- STEP 4: MIGRATE READING PROGRESS DATA
-- =====================================================================================================

-- Migrate from reading_progress table
INSERT INTO migration_log (step, table_name, started_at) 
VALUES ('MIGRATE_READING_PROGRESS', 'reading_progress', NOW());

DO $$
DECLARE
    processed_count INTEGER := 0;
    success_count INTEGER := 0;
    error_count INTEGER := 0;
    rec RECORD;
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'reading_progress') THEN
        
        FOR rec IN 
            SELECT 
                id,
                user_id,
                kitab_id,
                video_progress,
                pdf_page,
                last_accessed,
                NOW() as created_at,
                NOW() as updated_at
            FROM public.reading_progress
        LOOP
            BEGIN
                processed_count := processed_count + 1;
                
                INSERT INTO public.reading_progress_new (
                    user_id, kitab_id, video_progress, current_page,
                    last_accessed, created_at, updated_at
                ) VALUES (
                    rec.user_id, rec.kitab_id, 
                    COALESCE(rec.video_progress, 0),
                    COALESCE(rec.pdf_page, 1),
                    rec.last_accessed, rec.created_at, rec.updated_at
                ) ON CONFLICT (user_id, kitab_id) DO UPDATE SET
                    video_progress = GREATEST(reading_progress_new.video_progress, EXCLUDED.video_progress),
                    current_page = GREATEST(reading_progress_new.current_page, EXCLUDED.current_page),
                    last_accessed = GREATEST(reading_progress_new.last_accessed, EXCLUDED.last_accessed),
                    updated_at = NOW();
                
                success_count := success_count + 1;
                
            EXCEPTION WHEN OTHERS THEN
                error_count := error_count + 1;
                RAISE NOTICE 'Error migrating reading_progress for user % kitab %: %', rec.user_id, rec.kitab_id, SQLERRM;
            END;
        END LOOP;
    END IF;
    
    UPDATE migration_log 
    SET rows_processed = processed_count,
        rows_success = success_count,
        rows_failed = error_count,
        completed_at = NOW()
    WHERE step = 'MIGRATE_READING_PROGRESS' AND table_name = 'reading_progress'
    AND completed_at IS NULL;
END $$;

-- Migrate from ebook_reading_progress table
INSERT INTO migration_log (step, table_name, started_at) 
VALUES ('MIGRATE_EBOOK_READING_PROGRESS', 'ebook_reading_progress', NOW());

DO $$
DECLARE
    processed_count INTEGER := 0;
    success_count INTEGER := 0;
    error_count INTEGER := 0;
    rec RECORD;
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'ebook_reading_progress') THEN
        
        FOR rec IN 
            SELECT 
                user_id,
                kitab_id,
                current_page,
                total_pages,
                progress_percentage,
                last_read_at,
                bookmarks,
                notes,
                created_at,
                updated_at
            FROM public.ebook_reading_progress
        LOOP
            BEGIN
                processed_count := processed_count + 1;
                
                INSERT INTO public.reading_progress_new (
                    user_id, kitab_id, current_page, total_pages, progress_percentage,
                    last_accessed, bookmarks, notes, created_at, updated_at
                ) VALUES (
                    rec.user_id, rec.kitab_id, rec.current_page, rec.total_pages, rec.progress_percentage,
                    rec.last_read_at, rec.bookmarks, rec.notes, rec.created_at, rec.updated_at
                ) ON CONFLICT (user_id, kitab_id) DO UPDATE SET
                    current_page = CASE 
                        WHEN EXCLUDED.updated_at > reading_progress_new.updated_at 
                        THEN EXCLUDED.current_page 
                        ELSE reading_progress_new.current_page 
                    END,
                    total_pages = COALESCE(EXCLUDED.total_pages, reading_progress_new.total_pages),
                    progress_percentage = CASE 
                        WHEN EXCLUDED.updated_at > reading_progress_new.updated_at 
                        THEN EXCLUDED.progress_percentage 
                        ELSE reading_progress_new.progress_percentage 
                    END,
                    last_accessed = GREATEST(reading_progress_new.last_accessed, EXCLUDED.last_accessed),
                    bookmarks = CASE 
                        WHEN EXCLUDED.updated_at > reading_progress_new.updated_at 
                        THEN EXCLUDED.bookmarks 
                        ELSE reading_progress_new.bookmarks 
                    END,
                    notes = CASE 
                        WHEN EXCLUDED.updated_at > reading_progress_new.updated_at 
                        THEN EXCLUDED.notes 
                        ELSE reading_progress_new.notes 
                    END,
                    updated_at = GREATEST(reading_progress_new.updated_at, EXCLUDED.updated_at);
                
                success_count := success_count + 1;
                
            EXCEPTION WHEN OTHERS THEN
                error_count := error_count + 1;
                RAISE NOTICE 'Error migrating ebook_reading_progress for user % kitab %: %', rec.user_id, rec.kitab_id, SQLERRM;
            END;
        END LOOP;
    END IF;
    
    UPDATE migration_log 
    SET rows_processed = processed_count,
        rows_success = success_count,
        rows_failed = error_count,
        completed_at = NOW()
    WHERE step = 'MIGRATE_EBOOK_READING_PROGRESS' AND table_name = 'ebook_reading_progress'
    AND completed_at IS NULL;
END $$;

-- =====================================================================================================
-- STEP 5: MIGRATE WEBHOOK EVENTS DATA
-- =====================================================================================================

-- Migrate from webhook_events table
INSERT INTO migration_log (step, table_name, started_at) 
VALUES ('MIGRATE_WEBHOOK_EVENTS', 'webhook_events', NOW());

DO $$
DECLARE
    processed_count INTEGER := 0;
    success_count INTEGER := 0;
    error_count INTEGER := 0;
    rec RECORD;
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'webhook_events') THEN
        
        FOR rec IN 
            SELECT 
                id,
                provider,
                event_type,
                bill_code,
                transaction_id,
                status,
                status_id,
                raw_payload,
                received_at,
                created_at
            FROM public.webhook_events
        LOOP
            BEGIN
                processed_count := processed_count + 1;
                
                INSERT INTO public.webhook_events_new (
                    id, provider, event_type, status, provider_event_id,
                    bill_code, transaction_id, payload, received_at, created_at, updated_at
                ) VALUES (
                    rec.id, rec.provider, rec.event_type, 
                    CASE rec.status 
                        WHEN 'processed' THEN 'processed'
                        WHEN 'failed' THEN 'failed' 
                        ELSE 'pending' 
                    END,
                    rec.status_id, rec.bill_code, rec.transaction_id,
                    COALESCE(rec.raw_payload, '{}'),
                    rec.received_at, rec.created_at, NOW()
                ) ON CONFLICT (id) DO NOTHING;
                
                success_count := success_count + 1;
                
            EXCEPTION WHEN OTHERS THEN
                error_count := error_count + 1;
                RAISE NOTICE 'Error migrating webhook_event %: %', rec.id, SQLERRM;
            END;
        END LOOP;
    END IF;
    
    UPDATE migration_log 
    SET rows_processed = processed_count,
        rows_success = success_count,
        rows_failed = error_count,
        completed_at = NOW()
    WHERE step = 'MIGRATE_WEBHOOK_EVENTS' AND table_name = 'webhook_events'
    AND completed_at IS NULL;
END $$;

-- Migrate from webhook_logs table
INSERT INTO migration_log (step, table_name, started_at) 
VALUES ('MIGRATE_WEBHOOK_LOGS', 'webhook_logs', NOW());

DO $$
DECLARE
    processed_count INTEGER := 0;
    success_count INTEGER := 0;
    error_count INTEGER := 0;
    rec RECORD;
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'webhook_logs') THEN
        
        FOR rec IN 
            SELECT 
                id,
                provider,
                event_type,
                payload,
                status,
                reference_number,
                created_at
            FROM public.webhook_logs
            WHERE id NOT IN (SELECT id FROM public.webhook_events_new) -- Avoid duplicates
        LOOP
            BEGIN
                processed_count := processed_count + 1;
                
                INSERT INTO public.webhook_events_new (
                    id, provider, event_type, status, reference_number,
                    payload, received_at, created_at, updated_at
                ) VALUES (
                    rec.id, rec.provider, 
                    CONCAT('log.', rec.event_type), -- Prefix to distinguish from webhook_events
                    COALESCE(rec.status, 'processed'),
                    rec.reference_number, rec.payload,
                    rec.created_at, rec.created_at, NOW()
                ) ON CONFLICT (id) DO NOTHING;
                
                success_count := success_count + 1;
                
            EXCEPTION WHEN OTHERS THEN
                error_count := error_count + 1;
                RAISE NOTICE 'Error migrating webhook_log %: %', rec.id, SQLERRM;
            END;
        END LOOP;
    END IF;
    
    UPDATE migration_log 
    SET rows_processed = processed_count,
        rows_success = success_count,
        rows_failed = error_count,
        completed_at = NOW()
    WHERE step = 'MIGRATE_WEBHOOK_LOGS' AND table_name = 'webhook_logs'
    AND completed_at IS NULL;
END $$;

-- =====================================================================================================
-- STEP 6: HANDLE ADDITIONAL MIGRATION DATA
-- =====================================================================================================

-- Migrate direct_activations and pending_payments as special payment records
INSERT INTO migration_log (step, table_name, started_at) 
VALUES ('MIGRATE_DIRECT_ACTIVATIONS', 'direct_activations', NOW());

DO $$
DECLARE
    processed_count INTEGER := 0;
    success_count INTEGER := 0;
    error_count INTEGER := 0;
    rec RECORD;
    subscription_id_ref UUID;
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'direct_activations') THEN
        
        FOR rec IN 
            SELECT 
                id,
                user_id,
                bill_id,
                transaction_id,
                plan_id,
                amount,
                reason,
                activated_at,
                created_at
            FROM public.direct_activations
        LOOP
            BEGIN
                processed_count := processed_count + 1;
                
                -- Find related subscription
                SELECT id INTO subscription_id_ref 
                FROM public.subscriptions_new 
                WHERE user_id = rec.user_id AND plan_id = rec.plan_id
                ORDER BY created_at DESC LIMIT 1;
                
                INSERT INTO public.payments_new (
                    user_id, subscription_id, amount_cents, currency, status,
                    provider, provider_payment_id, reference_number, 
                    paid_at, description, metadata, created_at, updated_at
                ) VALUES (
                    rec.user_id, subscription_id_ref,
                    ROUND(rec.amount * 100), 'MYR', 'succeeded',
                    'manual', rec.transaction_id, rec.bill_id,
                    rec.activated_at, 'Direct activation: ' || rec.reason,
                    jsonb_build_object('direct_activation', true, 'original_reason', rec.reason),
                    rec.created_at, NOW()
                );
                
                success_count := success_count + 1;
                
            EXCEPTION WHEN OTHERS THEN
                error_count := error_count + 1;
                RAISE NOTICE 'Error migrating direct_activation %: %', rec.id, SQLERRM;
            END;
        END LOOP;
    END IF;
    
    UPDATE migration_log 
    SET rows_processed = processed_count,
        rows_success = success_count,
        rows_failed = error_count,
        completed_at = NOW()
    WHERE step = 'MIGRATE_DIRECT_ACTIVATIONS' AND table_name = 'direct_activations'
    AND completed_at IS NULL;
END $$;

-- =====================================================================================================
-- STEP 7: VERIFICATION AND CLEANUP
-- =====================================================================================================

-- Create verification report
INSERT INTO migration_log (step, table_name, started_at) 
VALUES ('VERIFICATION', 'ALL', NOW());

DO $$
DECLARE
    old_subs_count INTEGER := 0;
    new_subs_count INTEGER := 0;
    old_payments_count INTEGER := 0;
    new_payments_count INTEGER := 0;
    old_progress_count INTEGER := 0;
    new_progress_count INTEGER := 0;
    old_webhooks_count INTEGER := 0;
    new_webhooks_count INTEGER := 0;
BEGIN
    -- Count records in old vs new tables
    
    -- Subscriptions
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'subscriptions') THEN
        SELECT COUNT(*) INTO old_subs_count FROM public.subscriptions;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_subscriptions') THEN
        SELECT COUNT(*) INTO old_subs_count FROM public.user_subscriptions WHERE old_subs_count = 0;
    END IF;
    SELECT COUNT(*) INTO new_subs_count FROM public.subscriptions_new;
    
    -- Payments
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'transactions') THEN
        SELECT COUNT(*) INTO old_payments_count FROM public.transactions;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'payments') THEN
        SELECT COUNT(*) INTO old_payments_count FROM public.payments WHERE old_payments_count = 0;
    END IF;
    SELECT COUNT(*) INTO new_payments_count FROM public.payments_new;
    
    -- Reading progress
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'reading_progress') THEN
        SELECT COUNT(*) INTO old_progress_count FROM public.reading_progress;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'ebook_reading_progress') THEN
        SELECT COUNT(*) INTO old_progress_count FROM public.ebook_reading_progress WHERE old_progress_count = 0;
    END IF;
    SELECT COUNT(*) INTO new_progress_count FROM public.reading_progress_new;
    
    -- Webhooks
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'webhook_events') THEN
        SELECT COUNT(*) INTO old_webhooks_count FROM public.webhook_events;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'webhook_logs') THEN
        SELECT COUNT(*) INTO old_webhooks_count FROM public.webhook_logs WHERE old_webhooks_count = 0;
    END IF;
    SELECT COUNT(*) INTO new_webhooks_count FROM public.webhook_events_new;
    
    -- Log verification results
    RAISE NOTICE 'MIGRATION VERIFICATION REPORT:';
    RAISE NOTICE 'Subscriptions: % old -> % new', old_subs_count, new_subs_count;
    RAISE NOTICE 'Payments: % old -> % new', old_payments_count, new_payments_count;
    RAISE NOTICE 'Reading Progress: % old -> % new', old_progress_count, new_progress_count;
    RAISE NOTICE 'Webhooks: % old -> % new', old_webhooks_count, new_webhooks_count;
    
    UPDATE migration_log 
    SET rows_processed = old_subs_count + old_payments_count + old_progress_count + old_webhooks_count,
        rows_success = new_subs_count + new_payments_count + new_progress_count + new_webhooks_count,
        completed_at = NOW()
    WHERE step = 'VERIFICATION' AND table_name = 'ALL'
    AND completed_at IS NULL;
END $$;

-- Log completion of migration
UPDATE migration_log 
SET completed_at = NOW()
WHERE step = 'START_DATA_MIGRATION' AND table_name = 'ALL'
AND completed_at IS NULL;

-- Insert migration record
INSERT INTO public.schema_migrations (version, applied_at) 
VALUES ('012_data_migration_to_canonical_tables', NOW())
ON CONFLICT (version) DO UPDATE SET applied_at = NOW();

-- =====================================================================================================
-- FINAL MIGRATION LOG REPORT
-- =====================================================================================================

-- Display final migration report
SELECT 
    step,
    table_name,
    rows_processed,
    rows_success,
    rows_failed,
    error_message,
    started_at,
    completed_at,
    EXTRACT(EPOCH FROM (completed_at - started_at)) as duration_seconds
FROM migration_log
WHERE started_at >= (SELECT started_at FROM migration_log WHERE step = 'START_DATA_MIGRATION' ORDER BY started_at DESC LIMIT 1)
ORDER BY started_at;

-- =====================================================================================================
-- MIGRATION COMPLETE
-- =====================================================================================================

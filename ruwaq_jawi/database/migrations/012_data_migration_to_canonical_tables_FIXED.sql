-- =====================================================================================================
-- MIGRATION 012: DATA MIGRATION TO CANONICAL TABLES (FIXED VERSION)
-- =====================================================================================================
-- This migration safely migrates data from old/duplicate tables to the new canonical tables
-- Created by: 011_comprehensive_schema_cleanup_and_optimization.sql
-- 
-- IMPORTANT: Run this AFTER running migration 011
-- 
-- FIXES:
-- - Added proper column existence checks for all tables
-- - Dynamic column selection based on what exists in source tables
-- - Safer data migration with better error handling
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
VALUES ('START_DATA_MIGRATION_FIXED', 'ALL');

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
            EXECUTE format('
            SELECT 
                id,
                user_id,
                CASE 
                    WHEN %1$s THEN
                        CASE %2$s
                            WHEN ''1month'' THEN ''monthly_basic''
                            WHEN ''3month'' THEN ''quarterly_premium''
                            WHEN ''6month'' THEN ''biannual_premium''
                            WHEN ''12month'' THEN ''yearly_premium''
                            ELSE %2$s
                        END
                    ELSE ''manual''
                END as plan_id,
                %3$s as status,
                %4$s as started_at,
                %4$s as current_period_start,
                %5$s as current_period_end,
                CASE WHEN %3$s = ''cancelled'' THEN %5$s ELSE NULL END as canceled_at,
                true as auto_renew,
                COALESCE(%6$s, ''manual'') as provider,
                NULL as provider_customer_id,
                NULL as provider_subscription_id,
                %7$s as amount,
                %8$s as currency,
                ''{}'' as metadata,
                %9$s as created_at,
                NOW() as updated_at
            FROM public.subscriptions',
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'subscriptions' AND column_name = 'plan_type') THEN 'true' ELSE 'false' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'subscriptions' AND column_name = 'plan_type') THEN 'plan_type' ELSE '''manual''' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'subscriptions' AND column_name = 'status') THEN 'status' ELSE '''active''' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'subscriptions' AND column_name = 'start_date') THEN 'start_date' ELSE 'created_at' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'subscriptions' AND column_name = 'end_date') THEN 'end_date' ELSE 'created_at + interval ''30 days''' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'subscriptions' AND column_name = 'payment_method') THEN 'payment_method' ELSE '''manual''' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'subscriptions' AND column_name = 'amount') THEN 'amount' ELSE '0' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'subscriptions' AND column_name = 'currency') THEN 'currency' ELSE '''MYR''' END,
            'created_at'
            )
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
            EXECUTE format('
            SELECT 
                id,
                user_id,
                %1$s as plan_id,
                %2$s as status,
                COALESCE(%3$s, %4$s) as started_at,
                COALESCE(%3$s, %4$s) as current_period_start,
                %5$s as current_period_end,
                CASE WHEN %2$s IN (''canceled'', ''cancelled'') THEN %5$s ELSE NULL END as canceled_at,
                true as auto_renew,
                ''manual'' as provider,
                NULL as provider_customer_id,
                %6$s as provider_subscription_id,
                %7$s as amount,
                %8$s as currency,
                ''{}'' as metadata,
                %4$s as created_at,
                %9$s as updated_at
            FROM public.user_subscriptions
            WHERE id NOT IN (SELECT id FROM public.subscriptions_new)', -- Avoid duplicates
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_subscriptions' AND column_name = 'subscription_plan_id') THEN 'subscription_plan_id' ELSE '''manual''' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_subscriptions' AND column_name = 'status') THEN 'status' ELSE '''active''' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_subscriptions' AND column_name = 'start_date') THEN 'start_date' ELSE 'NULL' END,
            'created_at',
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_subscriptions' AND column_name = 'end_date') THEN 'end_date' ELSE 'created_at + interval ''30 days''' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_subscriptions' AND column_name = 'payment_id') THEN 'payment_id' ELSE 'NULL' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_subscriptions' AND column_name = 'amount') THEN 'amount' ELSE '0' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_subscriptions' AND column_name = 'currency') THEN 'currency' ELSE '''MYR''' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_subscriptions' AND column_name = 'updated_at') THEN 'updated_at' ELSE 'created_at' END
            )
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
            EXECUTE format('
            SELECT 
                id,
                user_id,
                %1$s as subscription_id,
                %2$s as amount,
                %3$s as currency,
                %4$s as payment_method,
                %5$s as gateway_transaction_id,
                %6$s as status,
                %7$s as metadata,
                created_at
            FROM public.transactions',
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'transactions' AND column_name = 'subscription_id') THEN 'subscription_id' ELSE 'NULL' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'transactions' AND column_name = 'amount') THEN 'amount' ELSE '0' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'transactions' AND column_name = 'currency') THEN 'currency' ELSE '''MYR''' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'transactions' AND column_name = 'payment_method') THEN 'payment_method' ELSE '''manual''' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'transactions' AND column_name = 'gateway_transaction_id') THEN 'gateway_transaction_id' ELSE 'NULL' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'transactions' AND column_name = 'status') THEN 'status' ELSE '''completed''' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'transactions' AND column_name = 'metadata') THEN 'metadata' ELSE '''{}''' END
            )
        LOOP
            BEGIN
                processed_count := processed_count + 1;
                
                -- Try to find matching subscription in new table
                subscription_id_ref := NULL;
                IF rec.subscription_id IS NOT NULL THEN
                    SELECT id INTO subscription_id_ref 
                    FROM public.subscriptions_new 
                    WHERE id = rec.subscription_id 
                       OR (user_id = rec.user_id AND provider_subscription_id = rec.gateway_transaction_id)
                    LIMIT 1;
                END IF;
                
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
                    COALESCE(rec.metadata::jsonb, '{}'),
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
            EXECUTE format('
            SELECT 
                id,
                user_id,
                %1$s as payment_id,
                %2$s as reference_number,
                %3$s as amount,
                %4$s as currency,
                %5$s as status,
                %6$s as payment_method,
                %7$s as paid_at,
                %8$s as metadata,
                created_at
            FROM public.payments
            WHERE id NOT IN (SELECT id FROM public.payments_new)', -- Avoid duplicates
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'payments' AND column_name = 'payment_id') THEN 'payment_id' ELSE 'NULL' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'payments' AND column_name = 'reference_number') THEN 'reference_number' ELSE 'NULL' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'payments' AND column_name = 'amount') THEN 'amount' ELSE '0' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'payments' AND column_name = 'currency') THEN 'currency' ELSE '''MYR''' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'payments' AND column_name = 'status') THEN 'status' ELSE '''succeeded''' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'payments' AND column_name = 'payment_method') THEN 'payment_method' ELSE '''manual''' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'payments' AND column_name = 'paid_at') THEN 'paid_at' ELSE 'NULL' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'payments' AND column_name = 'metadata') THEN 'metadata' ELSE '''{}''' END
            )
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
                    rec.paid_at, COALESCE(rec.metadata::jsonb, '{}'),
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
            EXECUTE format('
            SELECT 
                id,
                user_id,
                kitab_id,
                %1$s as video_progress,
                %2$s as pdf_page,
                %3$s as last_accessed,
                NOW() as created_at,
                NOW() as updated_at
            FROM public.reading_progress',
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reading_progress' AND column_name = 'video_progress') THEN 'video_progress' ELSE '0' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reading_progress' AND column_name = 'pdf_page') THEN 'pdf_page' ELSE '1' END,
            CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reading_progress' AND column_name = 'last_accessed') THEN 'last_accessed' ELSE 'NOW()' END
            )
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
-- STEP 5: MIGRATE WEBHOOK EVENTS DATA (FIXED)
-- =====================================================================================================

-- Migrate from webhook_events table (with dynamic column checking)
INSERT INTO migration_log (step, table_name, started_at) 
VALUES ('MIGRATE_WEBHOOK_EVENTS', 'webhook_events', NOW());

DO $$
DECLARE
    processed_count INTEGER := 0;
    success_count INTEGER := 0;
    error_count INTEGER := 0;
    rec RECORD;
    sql_query TEXT;
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'webhook_events') THEN
        
        -- Build dynamic query based on available columns
        sql_query := 'SELECT 
                id,
                ' || CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'webhook_events' AND column_name = 'provider') THEN 'provider' ELSE '''unknown''' END || ' as provider,
                ' || CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'webhook_events' AND column_name = 'event_type') THEN 'event_type' ELSE '''webhook''' END || ' as event_type,
                ' || CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'webhook_events' AND column_name = 'bill_code') THEN 'bill_code' ELSE 'NULL' END || ' as bill_code,
                ' || CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'webhook_events' AND column_name = 'transaction_id') THEN 'transaction_id' ELSE 'NULL' END || ' as transaction_id,
                ' || CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'webhook_events' AND column_name = 'status') THEN 'status' ELSE '''pending''' END || ' as status,
                ' || CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'webhook_events' AND column_name = 'status_id') THEN 'status_id' ELSE 'NULL' END || ' as status_id,
                ' || CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'webhook_events' AND column_name = 'raw_payload') THEN 'raw_payload' ELSE '''{}''' END || ' as raw_payload,
                ' || CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'webhook_events' AND column_name = 'received_at') THEN 'received_at' ELSE 'NOW()' END || ' as received_at,
                ' || CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'webhook_events' AND column_name = 'created_at') THEN 'created_at' ELSE 'NOW()' END || ' as created_at
            FROM public.webhook_events';
        
        FOR rec IN EXECUTE sql_query
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
                    COALESCE(rec.raw_payload::jsonb, '{}'),
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
WHERE step = 'START_DATA_MIGRATION_FIXED' AND table_name = 'ALL'
AND completed_at IS NULL;

-- Insert migration record
INSERT INTO public.schema_migrations (version, applied_at) 
VALUES ('012_data_migration_to_canonical_tables_FIXED', NOW())
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
WHERE started_at >= (SELECT started_at FROM migration_log WHERE step = 'START_DATA_MIGRATION_FIXED' ORDER BY started_at DESC LIMIT 1)
ORDER BY started_at;

-- =====================================================================================================
-- MIGRATION COMPLETE
-- =====================================================================================================

-- Migration Script: Legacy user_notifications to Enhanced System
-- This script migrates existing notifications from user_notifications table to the new enhanced system
-- Author: Assistant
-- Date: 2025-09-22

DO $$
DECLARE
    legacy_record RECORD;
    new_notification_id UUID;
    metadata_json JSONB;
    target_type TEXT;
    target_criteria JSONB;
    notification_type TEXT;
    current_user_id UUID;
    read_status BOOLEAN;
    read_timestamp TIMESTAMPTZ;
BEGIN
    RAISE NOTICE '🚀 Starting migration of legacy notifications to enhanced system...';

    -- Loop through all legacy notifications
    FOR legacy_record IN
        SELECT * FROM user_notifications
        ORDER BY delivered_at DESC
    LOOP
        BEGIN
            -- Parse metadata
            metadata_json := COALESCE(legacy_record.metadata, '{}'::jsonb);

            -- Determine notification type and target
            IF legacy_record.user_id IS NULL THEN
                -- Global/broadcast notification
                target_type := 'all';
                notification_type := 'broadcast';
                target_criteria := jsonb_build_object(
                    'target_roles', COALESCE(metadata_json->'target_roles', '["student", "admin"]'::jsonb),
                    'migrated_from', 'user_notifications',
                    'original_global', true
                );
            ELSE
                -- Personal notification
                target_type := 'user';
                notification_type := 'personal';
                target_criteria := jsonb_build_object(
                    'user_id', legacy_record.user_id,
                    'migrated_from', 'user_notifications',
                    'original_personal', true
                );
            END IF;

            -- Extract title from metadata or create from message
            DECLARE
                notification_title TEXT;
                notification_message TEXT;
            BEGIN
                notification_title := COALESCE(
                    metadata_json->>'title',
                    CASE
                        WHEN metadata_json->>'type' = 'content_published' THEN
                            COALESCE(metadata_json->>'icon', '📖') || ' ' ||
                            COALESCE(metadata_json->>'content_type', 'Kandungan') || ' Baharu!'
                        WHEN metadata_json->>'type' = 'payment_success' THEN '🎉 Pembayaran Berjaya!'
                        WHEN metadata_json->>'type' = 'admin_announcement' THEN '📢 Pengumuman Admin'
                        ELSE 'Notifikasi'
                    END
                );

                -- Use message as body, or extract from metadata
                notification_message := COALESCE(
                    legacy_record.message,
                    metadata_json->>'body',
                    'Notification message'
                );
            END;

            -- Insert into enhanced notifications table
            INSERT INTO notifications (
                id,
                type,
                title,
                message,
                target_type,
                target_criteria,
                metadata,
                created_at,
                expires_at,
                is_active
            ) VALUES (
                legacy_record.id, -- Keep same ID for easier tracking
                notification_type,
                notification_title,
                notification_message,
                target_type,
                target_criteria,
                metadata_json || jsonb_build_object(
                    'migrated_from', 'user_notifications',
                    'original_delivered_at', legacy_record.delivered_at,
                    'migration_date', NOW()
                ),
                legacy_record.delivered_at, -- Use original delivery time as created_at
                COALESCE(legacy_record.expires_at, legacy_record.delivered_at + INTERVAL '30 days'),
                true
            );

            -- For personal notifications, create read record if needed
            IF notification_type = 'personal' AND legacy_record.user_id IS NOT NULL THEN
                -- Check if user has read this notification (from metadata)
                read_status := FALSE;
                read_timestamp := NULL;

                IF metadata_json->>'status' = 'read' OR metadata_json->>'read_at' IS NOT NULL THEN
                    read_status := TRUE;
                    read_timestamp := COALESCE(
                        (metadata_json->>'read_at')::TIMESTAMPTZ,
                        legacy_record.delivered_at + INTERVAL '1 hour' -- Approximate read time
                    );
                END IF;

                -- Insert read record if notification was read
                IF read_status THEN
                    INSERT INTO notification_reads (
                        notification_id,
                        user_id,
                        is_read,
                        read_at,
                        created_at
                    ) VALUES (
                        legacy_record.id,
                        legacy_record.user_id,
                        true,
                        read_timestamp,
                        read_timestamp
                    );
                END IF;
            END IF;

            -- For broadcast notifications, handle read_by metadata
            IF notification_type = 'broadcast' AND metadata_json ? 'read_by' THEN
                -- Create read records for users who have read this broadcast
                DECLARE
                    reader_id TEXT;
                BEGIN
                    FOR reader_id IN
                        SELECT jsonb_array_elements_text(metadata_json->'read_by')
                    LOOP
                        -- Insert read record for each user who read this broadcast
                        INSERT INTO notification_reads (
                            notification_id,
                            user_id,
                            is_read,
                            read_at,
                            created_at
                        ) VALUES (
                            legacy_record.id,
                            reader_id::UUID,
                            true,
                            legacy_record.delivered_at + INTERVAL '1 hour', -- Approximate read time
                            legacy_record.delivered_at + INTERVAL '1 hour'
                        );
                    END LOOP;
                END;
            END IF;

            RAISE NOTICE '✅ Migrated notification: % (% - %)',
                legacy_record.id, notification_type, notification_title;

        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '❌ Failed to migrate notification %: %', legacy_record.id, SQLERRM;
                CONTINUE;
        END;
    END LOOP;

    -- Summary statistics
    DECLARE
        legacy_count INTEGER;
        enhanced_count INTEGER;
        read_records_count INTEGER;
    BEGIN
        SELECT COUNT(*) INTO legacy_count FROM user_notifications;
        SELECT COUNT(*) INTO enhanced_count FROM notifications WHERE metadata->>'migrated_from' = 'user_notifications';
        SELECT COUNT(*) INTO read_records_count FROM notification_reads
            WHERE notification_id IN (
                SELECT id FROM notifications WHERE metadata->>'migrated_from' = 'user_notifications'
            );

        RAISE NOTICE '📊 Migration Summary:';
        RAISE NOTICE '   Legacy notifications: %', legacy_count;
        RAISE NOTICE '   Migrated to enhanced: %', enhanced_count;
        RAISE NOTICE '   Read records created: %', read_records_count;
        RAISE NOTICE '🎉 Migration completed successfully!';
    END;

END $$;
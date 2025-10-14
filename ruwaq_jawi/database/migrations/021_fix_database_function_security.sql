-- Fix database function security issues
-- This migration adds search_path configuration to all functions that need it

-- Security Functions (high priority)
ALTER FUNCTION public.handle_admin_signup(json, json) SET search_path = public;
ALTER FUNCTION public.is_admin_user(uuid) SET search_path = public;
ALTER FUNCTION private.is_admin(uuid) SET search_path = public, private;

-- Payment and Subscription Functions
ALTER FUNCTION public.auto_create_payment_record(uuid, uuid, numeric, text, text, text, text, text) SET search_path = public;
ALTER FUNCTION public.handle_smart_subscription_purchase(uuid, text, numeric, text) SET search_path = public;
ALTER FUNCTION public.get_user_active_subscription(uuid) SET search_path = public;
ALTER FUNCTION public.user_has_active_subscription(uuid) SET search_path = public;
ALTER FUNCTION public.check_user_subscription_status(uuid) SET search_path = public;
ALTER FUNCTION public.get_user_subscription_status(uuid) SET search_path = public;
ALTER FUNCTION private.has_active_subscription(uuid) SET search_path = public, private;
ALTER FUNCTION private.can_access_kitab(uuid, uuid) SET search_path = public, private;
ALTER FUNCTION public.update_profile_subscription_status(uuid, text, timestamp with time zone, timestamp with time zone, boolean) SET search_path = public;
ALTER FUNCTION public.sync_profile_subscription_status(uuid) SET search_path = public;
ALTER FUNCTION public.auto_update_expired_subscriptions() SET search_path = public;
ALTER FUNCTION public.update_expired_subscriptions() SET search_path = public;
ALTER FUNCTION public.check_expiring_subscriptions() SET search_path = public;
ALTER FUNCTION public.get_subscription_stats() SET search_path = public;
ALTER FUNCTION public.cleanup_duplicate_subscriptions() SET search_path = public;
ALTER FUNCTION public.calculate_prorated_value(numeric, timestamp with time zone, timestamp with time zone) SET search_path = public;
ALTER FUNCTION public.get_subscription_recommendation(uuid) SET search_path = public;
ALTER FUNCTION public.extend_subscription(uuid, text, numeric, text) SET search_path = public;

-- Notification Functions
ALTER FUNCTION public.get_user_notifications(uuid, integer, integer) SET search_path = public;
ALTER FUNCTION public.get_admin_notifications(uuid, integer, integer) SET search_path = public;
ALTER FUNCTION public.create_personal_notification(uuid, text, text, text, jsonb, text) SET search_path = public;
ALTER FUNCTION public.create_broadcast_notification(text, text, text, jsonb, text) SET search_path = public;
ALTER FUNCTION public.mark_notification_as_read(uuid, uuid) SET search_path = public;
ALTER FUNCTION public.mark_all_notifications_as_read(uuid) SET search_path = public;
ALTER FUNCTION public.mark_notification_read(uuid, uuid) SET search_path = public;
ALTER FUNCTION public.delete_notification(uuid, uuid) SET search_path = public;
ALTER FUNCTION public.get_unread_notification_count(uuid) SET search_path = public;
ALTER FUNCTION public.broadcast_notification_to_all(text, text, text, jsonb, text) SET search_path = public;
ALTER FUNCTION public.update_notifications_updated_at() SET search_path = public;
ALTER FUNCTION public.send_admin_announcement(text, text, jsonb, text) SET search_path = public;
ALTER FUNCTION public.send_admin_announcement_simple(text, text) SET search_path = public;
ALTER FUNCTION public.send_payment_success_notification(uuid, uuid, text) SET search_path = public;
ALTER FUNCTION public.send_subscription_expiring_notification(uuid) SET search_path = public;
ALTER FUNCTION public.send_maintenance_notification(text, text) SET search_path = public;
ALTER FUNCTION public.send_maintenance_alert(text, text) SET search_path = public;
ALTER FUNCTION public.trigger_purchase_notification(uuid, uuid) SET search_path = public;
ALTER FUNCTION public.trigger_subscription_expiry_check() SET search_path = public;
ALTER FUNCTION public.trigger_inactive_user_notification(uuid) SET search_path = public;
ALTER FUNCTION public.cleanup_expired_notifications() SET search_path = public;
ALTER FUNCTION public.migrate_legacy_notifications() SET search_path = public;
ALTER FUNCTION public.broadcast_notification_to_all(text, text, text, jsonb, text) SET search_path = public;

-- User and Profile Functions
ALTER FUNCTION public.get_all_profiles_with_email() SET search_path = public;
ALTER FUNCTION public.update_user_last_seen(uuid) SET search_path = public;
ALTER FUNCTION public.update_user_interactions_updated_at() SET search_path = public;
ALTER FUNCTION public.update_interaction_updated_at(uuid, uuid, text) SET search_path = public;

-- Content and Kitab Functions
ALTER FUNCTION public.get_category_content_counts() SET search_path = public;
ALTER FUNCTION public.update_ebook_stats(uuid) SET search_path = public;
ALTER FUNCTION public.update_ebook_rating_stats(uuid, numeric) SET search_path = public;
ALTER FUNCTION public.update_ebook_availability(uuid, boolean) SET search_path = public;
ALTER FUNCTION public.get_kitab_videos_count(uuid) SET search_path = public;
ALTER FUNCTION public.get_kitab_total_duration(uuid) SET search_path = public;
ALTER FUNCTION public.update_kitab_video_stats(uuid, text) SET search_path = public;
ALTER FUNCTION public.update_video_kitab_stats(uuid) SET search_path = public;
ALTER FUNCTION public.update_video_episode_interactions_updated_at() SET search_path = public;

-- Preview and Content Functions
ALTER FUNCTION public.add_preview_content(uuid, text, text, text, text, jsonb) SET search_path = public;
ALTER FUNCTION public.update_preview_content_updated_at() SET search_path = public;
ALTER FUNCTION public.validate_preview_content_fk() SET search_path = public;

-- YouTube Sync Functions
ALTER FUNCTION public.auto_enable_youtube_sync(uuid) SET search_path = public;
ALTER FUNCTION public.log_youtube_sync(uuid, text, text, timestamp with time zone) SET search_path = public;
ALTER FUNCTION public.get_playlists_for_sync() SET search_path = public;
ALTER FUNCTION public.update_kitab_after_sync(uuid, jsonb) SET search_path = public;
ALTER FUNCTION public.auto_generate_thumbnail_url(text) SET search_path = public;

-- Utility Functions
ALTER FUNCTION public.set_updated_at() SET search_path = public;
ALTER FUNCTION public.tg__set_updated_at() SET search_path = public;
ALTER FUNCTION public.handle_updated_at() SET search_path = public;
ALTER FUNCTION public.update_reading_progress_last_accessed(uuid, uuid) SET search_path = public;

-- Dashboard and Analytics Functions
ALTER FUNCTION public.get_dashboard_stats() SET search_path = public;

-- Index creation for better security monitoring
CREATE INDEX IF NOT EXISTS idx_payments_security_audit ON payments(created_at, amount, status);
CREATE INDEX IF NOT EXISTS idx_webhook_events_security_audit ON webhook_events(created_at, event_type, source_ip);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_security_audit ON user_subscriptions(created_at, updated_at, status);

-- Security audit trigger function
CREATE OR REPLACE FUNCTION public.log_security_event()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO webhook_events (event_type, source_ip, event_data, created_at)
    VALUES (
        TG_TABLE_NAME || '_SECURITY_EVENT',
        COALESCE(current_setting('request.headers.ip', true), 'unknown'),
        jsonb_build_object(
            'operation', TG_OP,
            'table', TG_TABLE_NAME,
            'user_id', COALESCE(current_setting('request.jwt.claim.sub', true), 'anonymous'),
            'timestamp', NOW()
        ),
        NOW()
    );
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Add security audit triggers to sensitive tables (only if they don't exist)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'payments_security_audit') THEN
        CREATE TRIGGER payments_security_audit
            AFTER INSERT OR UPDATE OR DELETE ON payments
            FOR EACH ROW EXECUTE FUNCTION public.log_security_event();
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'user_subscriptions_security_audit') THEN
        CREATE TRIGGER user_subscriptions_security_audit
            AFTER INSERT OR UPDATE OR DELETE ON user_subscriptions
            FOR EACH ROW EXECUTE FUNCTION public.log_security_event();
    END IF;
END $$;

-- Grant proper permissions
GRANT EXECUTE ON FUNCTION public.log_security_event() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_security_event() TO service_role;

-- Add comment for documentation
COMMENT ON MIGRATION IS 'Security hardening: Set search_path for all functions and add security auditing';
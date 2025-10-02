-- NUCLEAR OPTION: Drop ALL triggers on user_interactions tables and recreate clean ones

-- ==================== STEP 1: Get list of all triggers ====================
-- Run this first to see what triggers exist
DO $$
DECLARE
    trigger_record RECORD;
BEGIN
    RAISE NOTICE '=== EXISTING TRIGGERS ===';
    FOR trigger_record IN
        SELECT trigger_name, event_object_table
        FROM information_schema.triggers
        WHERE event_object_schema = 'public'
        AND event_object_table IN (
            'video_kitab_user_interactions',
            'ebook_user_interactions',
            'video_episode_user_interactions'
        )
    LOOP
        RAISE NOTICE 'DROP TRIGGER % ON %.%;',
            trigger_record.trigger_name,
            'public',
            trigger_record.event_object_table;
    END LOOP;
END $$;

-- ==================== STEP 2: DROP ALL TRIGGERS ====================
-- Drop every single trigger on these tables
DO $$
DECLARE
    trigger_record RECORD;
    drop_command TEXT;
BEGIN
    FOR trigger_record IN
        SELECT trigger_name, event_object_table
        FROM information_schema.triggers
        WHERE event_object_schema = 'public'
        AND event_object_table IN (
            'video_kitab_user_interactions',
            'ebook_user_interactions',
            'video_episode_user_interactions'
        )
    LOOP
        drop_command := format('DROP TRIGGER IF EXISTS %I ON public.%I CASCADE',
            trigger_record.trigger_name,
            trigger_record.event_object_table
        );
        RAISE NOTICE 'Executing: %', drop_command;
        EXECUTE drop_command;
    END LOOP;

    RAISE NOTICE 'All triggers dropped successfully';
END $$;

-- ==================== STEP 3: Clean up orphaned trigger functions ====================
-- Drop trigger functions that might be orphaned
DROP FUNCTION IF EXISTS public.update_last_accessed() CASCADE;
DROP FUNCTION IF EXISTS public.update_interaction_timestamp() CASCADE;
DROP FUNCTION IF EXISTS public.update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS public.track_ebook_views() CASCADE;
DROP FUNCTION IF EXISTS public.track_video_views() CASCADE;
DROP FUNCTION IF EXISTS public.increment_views_count() CASCADE;

-- ==================== STEP 4: Create ONE simple trigger function ====================
-- This function ONLY updates updated_at column
CREATE OR REPLACE FUNCTION public.update_interaction_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ==================== STEP 5: Add back simple triggers ====================
-- Add ONE trigger per table for updated_at only
CREATE TRIGGER trigger_update_updated_at
  BEFORE UPDATE ON public.video_kitab_user_interactions
  FOR EACH ROW
  EXECUTE FUNCTION public.update_interaction_updated_at();

CREATE TRIGGER trigger_update_updated_at
  BEFORE UPDATE ON public.ebook_user_interactions
  FOR EACH ROW
  EXECUTE FUNCTION public.update_interaction_updated_at();

CREATE TRIGGER trigger_update_updated_at
  BEFORE UPDATE ON public.video_episode_user_interactions
  FOR EACH ROW
  EXECUTE FUNCTION public.update_interaction_updated_at();

-- ==================== VERIFICATION ====================
-- Check what triggers remain
SELECT
    trigger_name,
    event_object_table,
    action_timing,
    event_manipulation
FROM information_schema.triggers
WHERE event_object_schema = 'public'
AND event_object_table IN (
    'video_kitab_user_interactions',
    'ebook_user_interactions',
    'video_episode_user_interactions'
)
ORDER BY event_object_table, trigger_name;

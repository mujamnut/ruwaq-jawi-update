-- Fix all user_interactions tables: add all missing columns and fix/remove broken triggers

-- ==================== VIDEO KITAB USER INTERACTIONS ====================

-- Add missing columns to video_kitab_user_interactions
ALTER TABLE public.video_kitab_user_interactions
ADD COLUMN IF NOT EXISTS last_accessed TIMESTAMPTZ DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS views_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_watched_position INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_watch_time INTEGER DEFAULT 0;

-- Drop ALL existing triggers on video_kitab_user_interactions
DROP TRIGGER IF EXISTS update_video_kitab_last_accessed ON public.video_kitab_user_interactions;
DROP TRIGGER IF EXISTS update_video_kitab_updated_at ON public.video_kitab_user_interactions;
DROP TRIGGER IF EXISTS set_video_kitab_last_accessed ON public.video_kitab_user_interactions;

-- ==================== EBOOK USER INTERACTIONS ====================

-- Add missing columns to ebook_user_interactions
ALTER TABLE public.ebook_user_interactions
ADD COLUMN IF NOT EXISTS last_accessed TIMESTAMPTZ DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS views_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_read_page INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_read_time INTEGER DEFAULT 0;

-- Drop ALL existing triggers on ebook_user_interactions
DROP TRIGGER IF EXISTS update_ebook_last_accessed ON public.ebook_user_interactions;
DROP TRIGGER IF EXISTS update_ebook_updated_at ON public.ebook_user_interactions;
DROP TRIGGER IF EXISTS set_ebook_last_accessed ON public.ebook_user_interactions;

-- ==================== VIDEO EPISODE USER INTERACTIONS ====================

-- Add missing columns to video_episode_user_interactions
ALTER TABLE public.video_episode_user_interactions
ADD COLUMN IF NOT EXISTS last_accessed TIMESTAMPTZ DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS views_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_watched_position INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_watch_time INTEGER DEFAULT 0;

-- Drop ALL existing triggers on video_episode_user_interactions
DROP TRIGGER IF EXISTS update_video_episode_last_accessed ON public.video_episode_user_interactions;
DROP TRIGGER IF EXISTS update_video_episode_updated_at ON public.video_episode_user_interactions;
DROP TRIGGER IF EXISTS set_video_episode_last_accessed ON public.video_episode_user_interactions;

-- ==================== CREATE NEW SIMPLE TRIGGER FUNCTION ====================

-- Simple trigger function that only updates updated_at
CREATE OR REPLACE FUNCTION public.update_interaction_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create simple triggers for updated_at only
CREATE TRIGGER update_video_kitab_timestamp
  BEFORE UPDATE ON public.video_kitab_user_interactions
  FOR EACH ROW
  EXECUTE FUNCTION public.update_interaction_timestamp();

CREATE TRIGGER update_ebook_timestamp
  BEFORE UPDATE ON public.ebook_user_interactions
  FOR EACH ROW
  EXECUTE FUNCTION public.update_interaction_timestamp();

CREATE TRIGGER update_video_episode_timestamp
  BEFORE UPDATE ON public.video_episode_user_interactions
  FOR EACH ROW
  EXECUTE FUNCTION public.update_interaction_timestamp();

-- ==================== INDEXES ====================

-- Add indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_video_kitab_interactions_user_saved
  ON public.video_kitab_user_interactions(user_id, is_saved) WHERE is_saved = true;

CREATE INDEX IF NOT EXISTS idx_video_kitab_interactions_last_accessed
  ON public.video_kitab_user_interactions(user_id, last_accessed DESC);

CREATE INDEX IF NOT EXISTS idx_ebook_interactions_user_saved
  ON public.ebook_user_interactions(user_id, is_saved) WHERE is_saved = true;

CREATE INDEX IF NOT EXISTS idx_ebook_interactions_last_accessed
  ON public.ebook_user_interactions(user_id, last_accessed DESC);

CREATE INDEX IF NOT EXISTS idx_video_episode_interactions_user_saved
  ON public.video_episode_user_interactions(user_id, is_saved) WHERE is_saved = true;

CREATE INDEX IF NOT EXISTS idx_video_episode_interactions_last_accessed
  ON public.video_episode_user_interactions(user_id, last_accessed DESC);

-- ==================== COMMENTS ====================

COMMENT ON COLUMN public.video_kitab_user_interactions.last_accessed IS 'Last time user accessed this video kitab';
COMMENT ON COLUMN public.video_kitab_user_interactions.views_count IS 'Total number of times user viewed this video kitab';
COMMENT ON COLUMN public.video_kitab_user_interactions.last_watched_position IS 'Last watched position in seconds';
COMMENT ON COLUMN public.video_kitab_user_interactions.total_watch_time IS 'Total watch time in seconds';

COMMENT ON COLUMN public.ebook_user_interactions.last_accessed IS 'Last time user accessed this ebook';
COMMENT ON COLUMN public.ebook_user_interactions.views_count IS 'Total number of times user viewed this ebook';
COMMENT ON COLUMN public.ebook_user_interactions.last_read_page IS 'Last read page number';
COMMENT ON COLUMN public.ebook_user_interactions.total_read_time IS 'Total read time in seconds';

COMMENT ON COLUMN public.video_episode_user_interactions.last_accessed IS 'Last time user accessed this video episode';
COMMENT ON COLUMN public.video_episode_user_interactions.views_count IS 'Total number of times user viewed this video episode';
COMMENT ON COLUMN public.video_episode_user_interactions.last_watched_position IS 'Last watched position in seconds';
COMMENT ON COLUMN public.video_episode_user_interactions.total_watch_time IS 'Total watch time in seconds';

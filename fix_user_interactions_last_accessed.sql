-- Fix user_interactions tables: add missing last_accessed column and fix triggers

-- Add last_accessed column to video_kitab_user_interactions
ALTER TABLE public.video_kitab_user_interactions
ADD COLUMN IF NOT EXISTS last_accessed TIMESTAMPTZ DEFAULT NOW();

-- Add last_accessed column to ebook_user_interactions
ALTER TABLE public.ebook_user_interactions
ADD COLUMN IF NOT EXISTS last_accessed TIMESTAMPTZ DEFAULT NOW();

-- Add last_accessed column to video_episode_user_interactions
ALTER TABLE public.video_episode_user_interactions
ADD COLUMN IF NOT EXISTS last_accessed TIMESTAMPTZ DEFAULT NOW();

-- Create or replace trigger function to update last_accessed
CREATE OR REPLACE FUNCTION public.update_last_accessed()
RETURNS TRIGGER AS $$
BEGIN
  NEW.last_accessed := NOW();
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS update_video_kitab_last_accessed ON public.video_kitab_user_interactions;
DROP TRIGGER IF EXISTS update_ebook_last_accessed ON public.ebook_user_interactions;
DROP TRIGGER IF EXISTS update_video_episode_last_accessed ON public.video_episode_user_interactions;

-- Create triggers to update last_accessed on UPDATE
CREATE TRIGGER update_video_kitab_last_accessed
  BEFORE UPDATE ON public.video_kitab_user_interactions
  FOR EACH ROW
  EXECUTE FUNCTION public.update_last_accessed();

CREATE TRIGGER update_ebook_last_accessed
  BEFORE UPDATE ON public.ebook_user_interactions
  FOR EACH ROW
  EXECUTE FUNCTION public.update_last_accessed();

CREATE TRIGGER update_video_episode_last_accessed
  BEFORE UPDATE ON public.video_episode_user_interactions
  FOR EACH ROW
  EXECUTE FUNCTION public.update_last_accessed();

-- Add indexes for last_accessed queries
CREATE INDEX IF NOT EXISTS idx_video_kitab_interactions_last_accessed
  ON public.video_kitab_user_interactions(user_id, last_accessed DESC);

CREATE INDEX IF NOT EXISTS idx_ebook_interactions_last_accessed
  ON public.ebook_user_interactions(user_id, last_accessed DESC);

CREATE INDEX IF NOT EXISTS idx_video_episode_interactions_last_accessed
  ON public.video_episode_user_interactions(user_id, last_accessed DESC);

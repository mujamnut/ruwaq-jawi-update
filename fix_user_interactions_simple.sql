-- Simple fix: Just remove all broken triggers from user_interactions tables

-- Drop ALL triggers on video_kitab_user_interactions
DROP TRIGGER IF EXISTS update_video_kitab_last_accessed ON public.video_kitab_user_interactions;
DROP TRIGGER IF EXISTS update_video_kitab_updated_at ON public.video_kitab_user_interactions;
DROP TRIGGER IF EXISTS set_video_kitab_last_accessed ON public.video_kitab_user_interactions;
DROP TRIGGER IF EXISTS update_video_kitab_views ON public.video_kitab_user_interactions;
DROP TRIGGER IF EXISTS track_video_kitab_access ON public.video_kitab_user_interactions;

-- Drop ALL triggers on ebook_user_interactions
DROP TRIGGER IF EXISTS update_ebook_last_accessed ON public.ebook_user_interactions;
DROP TRIGGER IF EXISTS update_ebook_updated_at ON public.ebook_user_interactions;
DROP TRIGGER IF EXISTS set_ebook_last_accessed ON public.ebook_user_interactions;
DROP TRIGGER IF EXISTS update_ebook_views ON public.ebook_user_interactions;
DROP TRIGGER IF EXISTS track_ebook_access ON public.ebook_user_interactions;

-- Drop ALL triggers on video_episode_user_interactions
DROP TRIGGER IF EXISTS update_video_episode_last_accessed ON public.video_episode_user_interactions;
DROP TRIGGER IF EXISTS update_video_episode_updated_at ON public.video_episode_user_interactions;
DROP TRIGGER IF EXISTS set_video_episode_last_accessed ON public.video_episode_user_interactions;
DROP TRIGGER IF EXISTS update_video_episode_views ON public.video_episode_user_interactions;
DROP TRIGGER IF EXISTS track_video_episode_access ON public.video_episode_user_interactions;

-- Create one simple trigger function for updated_at only
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add simple triggers that only update updated_at (no other columns)
CREATE TRIGGER set_updated_at_video_kitab
  BEFORE UPDATE ON public.video_kitab_user_interactions
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER set_updated_at_ebook
  BEFORE UPDATE ON public.ebook_user_interactions
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER set_updated_at_video_episode
  BEFORE UPDATE ON public.video_episode_user_interactions
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Just add the views_count column that the trigger expects
ALTER TABLE public.ebook_user_interactions
ADD COLUMN IF NOT EXISTS views_count INTEGER DEFAULT 0;

ALTER TABLE public.video_kitab_user_interactions
ADD COLUMN IF NOT EXISTS views_count INTEGER DEFAULT 0;

ALTER TABLE public.video_episode_user_interactions
ADD COLUMN IF NOT EXISTS views_count INTEGER DEFAULT 0;

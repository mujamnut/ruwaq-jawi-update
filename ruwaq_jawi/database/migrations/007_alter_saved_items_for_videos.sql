-- Alter saved_items to support videos
-- 1) Add columns for videos and item type
ALTER TABLE saved_items
  ADD COLUMN IF NOT EXISTS item_type TEXT NOT NULL DEFAULT 'kitab',
  ADD COLUMN IF NOT EXISTS video_id TEXT NULL,
  ADD COLUMN IF NOT EXISTS video_title TEXT NULL,
  ADD COLUMN IF NOT EXISTS video_url TEXT NULL,
  ALTER COLUMN kitab_id DROP NOT NULL;

-- 2) Drop old unique constraint (if it exists)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'saved_items_user_id_kitab_id_key'
  ) THEN
    ALTER TABLE saved_items DROP CONSTRAINT saved_items_user_id_kitab_id_key;
  END IF;
END $$;

-- 3) Create partial unique indexes for kitab and video types
CREATE UNIQUE INDEX IF NOT EXISTS uq_saved_items_user_kitab
ON saved_items(user_id, kitab_id)
WHERE item_type = 'kitab' AND kitab_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_saved_items_user_video
ON saved_items(user_id, video_id)
WHERE item_type = 'video' AND video_id IS NOT NULL;

-- 4) Helpful indexes
CREATE INDEX IF NOT EXISTS idx_saved_items_item_type ON saved_items(item_type);
CREATE INDEX IF NOT EXISTS idx_saved_items_video_id ON saved_items(video_id);

-- Add missing foreign key constraint for video_kitab.category_id
-- This fixes the "more than one relationship was found" error when joining video_kitab with categories

-- Add the missing foreign key constraint
ALTER TABLE video_kitab
ADD CONSTRAINT video_kitab_category_id_fkey
FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL;

-- Verify the constraint was added
SELECT
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name = 'video_kitab';
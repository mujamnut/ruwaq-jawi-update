-- Create function to get category content counts for reports
CREATE OR REPLACE FUNCTION get_category_content_counts()
RETURNS TABLE(
  category_id UUID,
  category_name TEXT,
  ebook_count BIGINT,
  video_kitab_count BIGINT,
  total_count BIGINT
)
LANGUAGE SQL
AS $$
  SELECT
    c.id as category_id,
    c.name as category_name,
    COALESCE(e.ebook_count, 0) as ebook_count,
    COALESCE(v.video_kitab_count, 0) as video_kitab_count,
    COALESCE(e.ebook_count, 0) + COALESCE(v.video_kitab_count, 0) as total_count
  FROM categories c
  LEFT JOIN (
    SELECT category_id, COUNT(*) as ebook_count
    FROM ebooks
    WHERE is_active = true
    GROUP BY category_id
  ) e ON c.id = e.category_id
  LEFT JOIN (
    SELECT category_id, COUNT(*) as video_kitab_count
    FROM video_kitab
    WHERE is_active = true
    GROUP BY category_id
  ) v ON c.id = v.category_id
  WHERE c.is_active = true
  ORDER BY total_count DESC, c.name ASC;
$$;
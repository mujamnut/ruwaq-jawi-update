-- Create preview_content_with_details view
-- This view joins preview_content with actual content tables to provide full preview information

CREATE OR REPLACE VIEW preview_content_with_details AS
SELECT
    pc.id,
    pc.content_type,
    pc.content_id,
    pc.preview_type,
    pc.preview_duration_seconds,
    pc.preview_pages,
    pc.preview_description,
    pc.sort_order,
    pc.is_active,
    pc.created_at,
    pc.updated_at,

    -- Content details based on content type
    CASE
        WHEN pc.content_type = 'video_episode' THEN ve.title
        WHEN pc.content_type = 'ebook' THEN e.title
        WHEN pc.content_type = 'video_kitab' THEN vk.title
    END as content_title,

    CASE
        WHEN pc.content_type = 'video_episode' THEN ve.thumbnail_url
        WHEN pc.content_type = 'ebook' THEN e.thumbnail_url
        WHEN pc.content_type = 'video_kitab' THEN vk.thumbnail_url
    END as content_thumbnail_url,

    -- Category information
    CASE
        WHEN pc.content_type = 'video_episode' THEN vk_cat.name
        WHEN pc.content_type = 'ebook' THEN e_cat.name
        WHEN pc.content_type = 'video_kitab' THEN vk_direct_cat.name
    END as category_name

FROM preview_content pc

-- Join with video_episodes for video_episode content type
LEFT JOIN video_episodes ve ON pc.content_type = 'video_episode' AND pc.content_id = ve.id
LEFT JOIN video_kitab vk_for_episode ON ve.video_kitab_id = vk_for_episode.id
LEFT JOIN categories vk_cat ON vk_for_episode.category_id = vk_cat.id

-- Join with ebooks for ebook content type
LEFT JOIN ebooks e ON pc.content_type = 'ebook' AND pc.content_id = e.id
LEFT JOIN categories e_cat ON e.category_id = e_cat.id

-- Join with video_kitab for video_kitab content type
LEFT JOIN video_kitab vk ON pc.content_type = 'video_kitab' AND pc.content_id = vk.id
LEFT JOIN categories vk_direct_cat ON vk.category_id = vk_direct_cat.id;

-- Grant permissions
GRANT SELECT ON preview_content_with_details TO authenticated;
GRANT SELECT ON preview_content_with_details TO service_role;
-- Step 1: Check all existing triggers on user_interactions tables
SELECT
    trigger_name,
    event_object_table as table_name,
    action_statement,
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

-- Step 2: Get all trigger function definitions
SELECT
    n.nspname as schema_name,
    p.proname as function_name,
    pg_get_functiondef(p.oid) as function_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
AND p.proname LIKE '%interaction%'
OR p.proname LIKE '%last_accessed%'
OR p.proname LIKE '%views%'
OR p.proname LIKE '%updated_at%'
ORDER BY p.proname;

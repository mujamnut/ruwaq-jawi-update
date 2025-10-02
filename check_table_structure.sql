-- Check complete table structure for ebook_user_interactions
SELECT
    column_name,
    data_type,
    column_default,
    is_nullable,
    is_generated,
    generation_expression
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'ebook_user_interactions'
ORDER BY ordinal_position;

-- Check if there are any generated columns or computed columns
SELECT
    attname AS column_name,
    attgenerated AS generated_type,
    pg_get_expr(adbin, adrelid) AS default_expression
FROM pg_attribute a
LEFT JOIN pg_attrdef ad ON a.attrelid = ad.adrelid AND a.attnum = ad.adnum
WHERE a.attrelid = 'public.ebook_user_interactions'::regclass
AND a.attnum > 0
AND NOT a.attisdropped
ORDER BY a.attnum;

-- Check for any rules on the table
SELECT
    rulename,
    definition
FROM pg_rules
WHERE schemaname = 'public'
AND tablename = 'ebook_user_interactions';

# 🚀 RUWAQ JAWI DATABASE CLEANUP & OPTIMIZATION
## Panduan Manual Execution melalui Supabase SQL Editor

---

## 📋 OVERVIEW

Saya telah create 3 migration files untuk cleanup dan optimize database structure:

1. **`011_comprehensive_schema_cleanup_and_optimization.sql`** - Schema optimization & new canonical tables
2. **`012_data_migration_to_canonical_tables.sql`** - Data migration from old to new tables  
3. **`013_final_table_cleanup_and_rename.sql`** - Final cleanup & table renaming

---

## ⚠️ IMPORTANT NOTES

**BACKUP FIRST**: Ambil full database backup sebelum run migrations ni!

**RUN IN ORDER**: Kena run mengikut sequence - 011 → 012 → 013

**VERIFY EACH STEP**: Check results selepas setiap migration sebelum proceed

---

## 🔧 EXECUTION STEPS

### STEP 1: Apply Schema Optimization (Migration 011)

1. **Buka Supabase Dashboard** → SQL Editor
2. **Copy & paste** content dari file `011_comprehensive_schema_cleanup_and_optimization.sql`
3. **Execute** the SQL
4. **Verify** output - semua steps should complete successfully

**Expected Results:**
- ✅ New columns added to `categories` and `kitab` tables
- ✅ New canonical tables created: `subscriptions_new`, `payments_new`, etc.
- ✅ Optimized indexes created
- ✅ Updated RLS policies
- ✅ Helper functions created

### STEP 2: Data Migration (Migration 012)

1. **Copy & paste** content dari file `012_data_migration_to_canonical_tables.sql`  
2. **Execute** the SQL
3. **Check migration log table** for results:
   ```sql
   SELECT * FROM migration_log ORDER BY started_at DESC;
   ```

**Expected Results:**
- ✅ Data migrated from old subscription tables
- ✅ Payment data consolidated
- ✅ Reading progress merged  
- ✅ Webhook events migrated
- ✅ Verification report shows row counts

### STEP 3: Final Cleanup (Migration 013)

1. **Copy & paste** content dari file `013_final_table_cleanup_and_rename.sql`
2. **Execute** the SQL  
3. **Check cleanup log**:
   ```sql
   SELECT * FROM final_cleanup_log ORDER BY started_at DESC;
   ```

**Expected Results:**
- ✅ Old tables renamed to `*_legacy`
- ✅ New canonical tables renamed to final names
- ✅ Views and functions updated
- ✅ Final verification passed

---

## 🔍 VERIFICATION QUERIES

Run these queries to verify migration success:

### Check Table Structure
```sql
-- List all tables
SELECT table_name, table_type 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- Check for new columns
SELECT table_name, column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name IN ('categories', 'kitab')
AND column_name IN ('is_active', 'updated_at', 'total_pages')
ORDER BY table_name, column_name;
```

### Check Data Counts
```sql
-- Verify data in canonical tables
SELECT 'subscriptions' as table_name, COUNT(*) as count FROM public.subscriptions
UNION ALL
SELECT 'payments', COUNT(*) FROM public.payments  
UNION ALL
SELECT 'reading_progress', COUNT(*) FROM public.reading_progress
UNION ALL
SELECT 'webhook_events', COUNT(*) FROM public.webhook_events
UNION ALL
SELECT 'categories', COUNT(*) FROM public.categories
UNION ALL
SELECT 'kitab', COUNT(*) FROM public.kitab;
```

### Check Indexes
```sql
-- List indexes
SELECT schemaname, tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
AND tablename IN ('categories', 'kitab', 'subscriptions', 'payments', 'reading_progress', 'webhook_events')
ORDER BY tablename, indexname;
```

### Check RLS Policies  
```sql
-- Check RLS policies
SELECT schemaname, tablename, policyname, cmd, roles
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

---

## 🎯 BENEFITS AFTER MIGRATION

### ✅ **Cleaned Structure**
- **Single source of truth** for each entity type
- **No more duplicate tables** (subscriptions vs user_subscriptions)
- **Consistent naming** and column structures

### ✅ **Better Performance**  
- **Optimized indexes** for common queries
- **Proper foreign key relationships**
- **Efficient RLS policies**

### ✅ **Flutter App Compatibility**
- **Missing columns added** (is_active, updated_at, total_pages)
- **Dart models now match** database schema exactly
- **No more model mapping errors**

### ✅ **Enhanced Features**
- **Combined progress tracking** (video + PDF in one table)
- **Improved subscription management** 
- **Better webhook handling**
- **Automated updated_at triggers**

---

## 🔄 ROLLBACK PLAN

If anything goes wrong:

1. **Legacy tables preserved** as `*_legacy` 
2. **Can restore** by renaming back:
   ```sql
   -- Example rollback (if needed)
   ALTER TABLE subscriptions RENAME TO subscriptions_broken;
   ALTER TABLE subscriptions_legacy RENAME TO subscriptions;
   ```
3. **Full backup available** untuk complete restore

---

## 📊 TABLES BEFORE & AFTER

### BEFORE (Messy)
```
❌ subscriptions + user_subscriptions (duplicate)
❌ transactions + payments (duplicate)  
❌ reading_progress + ebook_reading_progress (duplicate)
❌ webhook_events + webhook_logs (duplicate)
❌ categories (missing is_active, updated_at)
❌ kitab (missing is_active, total_pages, updated_at)
❌ direct_activations, pending_payments (extra)
```

### AFTER (Clean)
```  
✅ subscriptions (canonical, consolidated)
✅ payments (canonical, consolidated)
✅ reading_progress (canonical, consolidated)
✅ webhook_events (canonical, consolidated)  
✅ categories (with is_active, updated_at)
✅ kitab (with is_active, total_pages, updated_at)
✅ *_legacy tables (preserved as backup)
```

---

## 🚨 TROUBLESHOOTING

### If Migration 011 fails:
- Check for missing `subscription_plans` table
- Verify `auth.users` table exists
- Check PostgreSQL version compatibility

### If Migration 012 fails:
- Verify Migration 011 completed successfully
- Check data types match between old and new tables
- Review migration_log for specific errors

### If Migration 013 fails:
- Check previous migrations completed
- Verify no active connections to tables being renamed
- Review final_cleanup_log for issues

### Need to check current state:
```sql
-- See which migrations completed
SELECT * FROM schema_migrations ORDER BY applied_at DESC;

-- Check table existence  
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('subscriptions', 'subscriptions_new', 'subscriptions_legacy')
ORDER BY table_name;
```

---

## 📞 SUPPORT

Kalau ada issues atau questions:

1. **Check the log tables** first (migration_log, final_cleanup_log)
2. **Run verification queries** above
3. **Check Supabase logs** for detailed error messages
4. **Take note of specific error message** untuk debugging

---

## ✅ SUCCESS CHECKLIST

After running all migrations, check:

- [ ] All 3 migrations in `schema_migrations` table
- [ ] No tables named `*_new` remaining  
- [ ] Legacy tables named `*_legacy` exist
- [ ] New columns exist in categories/kitab
- [ ] Data counts look reasonable
- [ ] Views and functions working
- [ ] App can connect and query successfully

---

**SELAMAT! Database awak dah optimized! 🎉**

Next step: Update Flutter app models to use new schema structure.

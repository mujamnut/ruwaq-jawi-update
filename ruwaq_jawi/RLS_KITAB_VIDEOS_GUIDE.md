# Row Level Security (RLS) Guide untuk Table `kitab_videos`

## 📋 Overview

Dokumentasi ini menyediakan SQL script untuk implement Row Level Security (RLS) pada table `kitab_videos` supaya **ADMIN BOLEH KAWAL SEMUA** access, manakala users lain hanya boleh access content yang sepatutnya.

## 🎯 Matlamat

- ✅ **Admin full control**: Boleh create/read/update/delete semua episodes
- ✅ **Student access control**: Hanya boleh view published episodes 
- ✅ **Premium content protection**: Episode premium hanya untuk subscribers
- ✅ **Preview episode access**: Preview boleh dilihat semua orang
- ✅ **Security by default**: Block unauthorized access

## 📁 Files Disediakan

### 1. `KITAB_VIDEOS_RLS_POLICIES.sql` (LENGKAP)
- **Size:** ~300 baris
- **Features:** Full RLS implementation dengan premium logic
- **Includes:** Helper functions, complex policies, optimization tips
- **Best for:** Production environment dengan complete feature set

### 2. `QUICK_ADMIN_RLS_KITAB_VIDEOS.sql` (RINGKAS)
- **Size:** ~80 baris  
- **Features:** Basic admin control dengan simple policies
- **Includes:** Essential RLS sahaja
- **Best for:** Quick setup atau testing

## 🚀 Quick Setup (Recommended untuk mula)

1. **Copy `QUICK_ADMIN_RLS_KITAB_VIDEOS.sql`**
2. **Paste dalam Supabase SQL Editor**
3. **PENTING:** Sesuaikan function `private.is_admin()` dengan struktur database anda
4. **Run SQL script**

```sql
-- SESUAIKAN FUNCTION INI:
CREATE OR REPLACE FUNCTION private.is_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Option 1: Check raw_app_meta_data
  RETURN (
    SELECT (raw_app_meta_data->>'role') = 'admin'
    FROM auth.users
    WHERE id = auth.uid()
  );
  
  -- Option 2: Check dari user_profiles table
  -- RETURN EXISTS (
  --   SELECT 1 FROM public.user_profiles 
  --   WHERE id = auth.uid() AND role = 'admin'
  -- );
END;
$$;
```

## 🔧 Configuration Required

### 1. Admin Check Logic
Sesuaikan `private.is_admin()` function dengan salah satu cara:

**Option A: Guna `raw_app_meta_data` (Recommended)**
```sql
-- Set admin role dalam auth metadata
UPDATE auth.users 
SET raw_app_meta_data = '{"role": "admin"}'
WHERE email = 'admin@yourapp.com';
```

**Option B: Guna table `user_profiles`**
```sql
-- Structure table user_profiles
CREATE TABLE IF NOT EXISTS user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  role TEXT DEFAULT 'student',
  is_active BOOLEAN DEFAULT true
);
```

### 2. Premium Access Logic (For full version)
Kalau guna version lengkap, sesuaikan table subscription:

```sql
CREATE TABLE IF NOT EXISTS user_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  is_active BOOLEAN DEFAULT true,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

## 📊 Policies Yang Dibuat

### QUICK VERSION:
1. **`Admin full control kitab_videos`** - Admin boleh semua operations
2. **`Public can view active episodes`** - Users boleh view active episodes sahaja

### FULL VERSION:
1. **`Admin full access to kitab_videos`** - Admin full CRUD
2. **`Students can view published episodes`** - Students view dengan premium logic
3. **`Preview episodes visible to all`** - Preview episodes untuk semua
4. **`Admin can insert episodes`** - Insert restricted to admin
5. **`Admin can update episodes`** - Update restricted to admin  
6. **`Admin can delete episodes`** - Delete restricted to admin
7. **`Admin can view inactive episodes`** - Admin boleh view draft/inactive

## 🧪 Testing & Verification

### 1. Check RLS Status
```sql
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'kitab_videos';
```

### 2. List Active Policies
```sql
SELECT policyname, cmd, roles
FROM pg_policies 
WHERE tablename = 'kitab_videos';
```

### 3. Test Access Levels

**As Admin:**
```sql
-- Should see all episodes
SELECT COUNT(*) FROM kitab_videos;

-- Should be able to insert
INSERT INTO kitab_videos (title, kitab_id, ...) VALUES (...);
```

**As Normal User:**
```sql  
-- Should only see active episodes
SELECT COUNT(*) FROM kitab_videos;

-- Should get permission denied
INSERT INTO kitab_videos (title, kitab_id, ...) VALUES (...);
```

**As Anonymous:**
```sql
-- Should only see preview episodes (full version)
SELECT COUNT(*) FROM kitab_videos WHERE is_preview = true;
```

## ⚡ Performance Optimization

Tambah indexes untuk optimal performance:

```sql
CREATE INDEX IF NOT EXISTS idx_kitab_videos_active 
ON kitab_videos (is_active);

CREATE INDEX IF NOT EXISTS idx_kitab_videos_preview 
ON kitab_videos (is_preview);

CREATE INDEX IF NOT EXISTS idx_kitab_videos_kitab_id 
ON kitab_videos (kitab_id);

-- Index untuk admin checks
CREATE INDEX IF NOT EXISTS idx_user_profiles_role 
ON user_profiles (id, role) WHERE role = 'admin';
```

## 🔒 Security Best Practices

### 1. Helper Functions dalam Schema `private`
- Semua helper functions dalam schema `private`
- `SECURITY DEFINER` untuk bypass RLS dalam functions
- Never expose `private` schema dalam API settings

### 2. Use `SELECT` wrapper untuk functions
```sql
-- Good: Cached per statement
USING ((SELECT private.is_admin()))

-- Avoid: Called for each row
USING (private.is_admin())
```

### 3. Grant Minimal Permissions
- Grant permissions specific kepada roles
- Review permissions berkala
- Monitor access logs

## 🐛 Common Issues & Solutions

### Issue 1: RLS Policy Violations
**Error:** `new row violates row-level security policy`
**Solution:** Check admin function logic dan ensure user ada proper role

### Issue 2: Performance Slow
**Problem:** Queries lambat selepas enable RLS
**Solution:** Add proper indexes dan optimize policies

### Issue 3: Admin Cannot Access
**Problem:** Admin user cannot perform operations
**Solution:** Verify `private.is_admin()` function return `true` untuk admin user

### Issue 4: Anonymous Users See Nothing
**Problem:** Anonymous users cannot see preview content
**Solution:** Check policies ada include `anon` role dan preview logic betul

## 📈 Monitoring & Maintenance

### 1. Regular Policy Review
- Review policies monthly untuk security
- Check jika ada unused policies
- Update logic mengikut business changes

### 2. Performance Monitoring
```sql
-- Check policy execution stats
SELECT * FROM pg_stat_user_tables WHERE relname = 'kitab_videos';

-- Monitor slow queries
SELECT query, calls, mean_time FROM pg_stat_statements 
WHERE query LIKE '%kitab_videos%' 
ORDER BY mean_time DESC;
```

### 3. Access Logging
- Enable Supabase audit logs
- Monitor failed access attempts
- Track admin operations

## 🆙 Migration Path

### From No RLS → Quick Setup
1. Run `QUICK_ADMIN_RLS_KITAB_VIDEOS.sql`
2. Test admin access
3. Verify user restrictions

### From Quick → Full Setup
1. Backup existing policies
2. Run `KITAB_VIDEOS_RLS_POLICIES.sql` 
3. Configure premium logic
4. Test all use cases

### Rollback Plan
```sql
-- Emergency: Disable RLS
ALTER TABLE public.kitab_videos DISABLE ROW LEVEL SECURITY;

-- Remove all policies
DROP POLICY IF EXISTS "policy_name" ON public.kitab_videos;
```

## 📞 Support

Kalau ada issues:
1. Check function `private.is_admin()` configuration
2. Verify user roles dalam database
3. Test dengan different user accounts
4. Check Supabase logs untuk errors

---

**💡 Tips:** Mula dengan Quick setup dulu untuk test, then upgrade ke Full version kalau perlukan premium features dan complex access control.

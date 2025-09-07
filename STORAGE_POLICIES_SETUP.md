# Manual Storage Policies Setup for E-Book System

Since storage RLS policies require superuser permissions, they must be set up manually in the Supabase Dashboard.

## Steps to Setup Storage Policies

### 1. Navigate to Supabase Dashboard
- Go to your Supabase project dashboard
- Navigate to **Storage** → **Policies**

### 2. Create the following policies for bucket `ebook-pdfs`:

#### Policy 1: "Users can view accessible PDFs" (SELECT)
- **Operation**: SELECT
- **Target roles**: authenticated
- **USING expression**:
```sql
bucket_id = 'ebook-pdfs' AND (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  OR EXISTS (SELECT 1 FROM kitab k WHERE k.pdf_storage_path = name AND k.is_premium = false)
  OR (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND subscription_status = 'active')
      AND EXISTS (SELECT 1 FROM kitab k WHERE k.pdf_storage_path = name AND k.is_premium = true))
)
```

#### Policy 2: "Only admins can upload PDFs" (INSERT)
- **Operation**: INSERT
- **Target roles**: authenticated
- **WITH CHECK expression**:
```sql
bucket_id = 'ebook-pdfs' AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
```

#### Policy 3: "Only admins can update PDFs" (UPDATE)
- **Operation**: UPDATE
- **Target roles**: authenticated
- **USING expression**:
```sql
bucket_id = 'ebook-pdfs' AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
```

#### Policy 4: "Only admins can delete PDFs" (DELETE)
- **Operation**: DELETE
- **Target roles**: authenticated
- **USING expression**:
```sql
bucket_id = 'ebook-pdfs' AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
```

## Access Control Logic

### Free E-Books
- All authenticated users can access
- No subscription required

### Premium E-Books
- Only users with active subscription can access
- Admins can access all content

### Admin Operations
- Only admin users can upload, update, or delete PDF files
- Regular users have read-only access based on their subscription status

## Testing Access Control

After setting up the policies, test with different user types:

1. **Admin user**: Should have full access to all operations
2. **Subscribed user**: Should access both free and premium PDFs
3. **Free user**: Should only access free PDFs
4. **Unauthenticated**: Should have no access

## Troubleshooting

If policies don't work as expected:
1. Check that the `profiles` table exists and has correct columns
2. Verify `kitab` table has `pdf_storage_path` and `is_premium` columns
3. Ensure users have correct `role` and `has_active_subscription` values
4. Test policies in Supabase SQL editor before applying

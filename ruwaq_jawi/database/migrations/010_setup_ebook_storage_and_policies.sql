-- Migration 010: Setup E-book Storage and Policies
-- This migration creates storage bucket for PDFs and updates kitab table for e-book support

-- =============================================
-- 1. CREATE STORAGE BUCKET FOR PDF FILES
-- =============================================

-- Insert storage bucket for PDF files
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'ebook-pdfs',
  'ebook-pdfs',
  false, -- Private bucket, access controlled by RLS
  52428800, -- 50MB file size limit
  ARRAY['application/pdf']::text[]
);

-- =============================================
-- 2. UPDATE KITAB TABLE FOR E-BOOK SUPPORT
-- =============================================

-- Add columns for PDF storage if they don't exist
DO $$ 
BEGIN
    -- Add pdf_storage_path column for Supabase storage path
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'kitab' AND column_name = 'pdf_storage_path') THEN
        ALTER TABLE kitab ADD COLUMN pdf_storage_path TEXT;
    END IF;
    
    -- Add pdf_file_size column to track file size
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'kitab' AND column_name = 'pdf_file_size') THEN
        ALTER TABLE kitab ADD COLUMN pdf_file_size BIGINT;
    END IF;
    
    -- Add pdf_upload_date column to track when PDF was uploaded
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'kitab' AND column_name = 'pdf_upload_date') THEN
        ALTER TABLE kitab ADD COLUMN pdf_upload_date TIMESTAMPTZ;
    END IF;
    
    -- Add is_ebook_available column for quick filtering
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'kitab' AND column_name = 'is_ebook_available') THEN
        ALTER TABLE kitab ADD COLUMN is_ebook_available BOOLEAN DEFAULT FALSE;
    END IF;
END $$;

-- =============================================
-- 3. CREATE E-BOOK READING PROGRESS TABLE
-- =============================================

CREATE TABLE IF NOT EXISTS ebook_reading_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    kitab_id UUID NOT NULL REFERENCES kitab(id) ON DELETE CASCADE,
    current_page INTEGER DEFAULT 1,
    total_pages INTEGER,
    progress_percentage DECIMAL(5,2) DEFAULT 0.00,
    last_read_at TIMESTAMPTZ DEFAULT NOW(),
    bookmarks JSONB DEFAULT '[]'::jsonb, -- Store page bookmarks as JSON array
    notes JSONB DEFAULT '{}'::jsonb, -- Store page notes as JSON object
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT unique_user_kitab_progress UNIQUE(user_id, kitab_id),
    CONSTRAINT valid_progress_percentage CHECK (progress_percentage >= 0 AND progress_percentage <= 100),
    CONSTRAINT valid_current_page CHECK (current_page > 0),
    CONSTRAINT valid_total_pages CHECK (total_pages IS NULL OR total_pages > 0)
);

-- =============================================
-- 4. STORAGE BUCKET POLICIES (Manual Setup Required)
-- =============================================

-- Note: Storage RLS policies require superuser permissions and must be set up 
-- manually in Supabase Dashboard under Storage > Policies
-- 
-- Manual policies to create in Supabase Dashboard:
--
-- 1. "Users can view accessible PDFs" - SELECT policy:
--    Target roles: authenticated
--    USING expression:
--    bucket_id = 'ebook-pdfs' AND (
--      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
--      OR EXISTS (SELECT 1 FROM kitab k WHERE k.pdf_storage_path = name AND k.is_premium = false)
--      OR (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND subscription_status = 'active')
--          AND EXISTS (SELECT 1 FROM kitab k WHERE k.pdf_storage_path = name AND k.is_premium = true))
--    )
--
-- 2. "Only admins can upload PDFs" - INSERT policy:
--    Target roles: authenticated  
--    WITH CHECK expression:
--    bucket_id = 'ebook-pdfs' AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
--
-- 3. "Only admins can update PDFs" - UPDATE policy:
--    Target roles: authenticated
--    USING expression:
--    bucket_id = 'ebook-pdfs' AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
--
-- 4. "Only admins can delete PDFs" - DELETE policy:
--    Target roles: authenticated
--    USING expression:
--    bucket_id = 'ebook-pdfs' AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')

-- =============================================
-- 5. CREATE RLS POLICIES FOR READING PROGRESS
-- =============================================

-- Enable RLS on ebook_reading_progress
ALTER TABLE ebook_reading_progress ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only access their own reading progress
CREATE POLICY "Users can manage their own reading progress" ON ebook_reading_progress
FOR ALL USING (
    auth.uid() = user_id
);

-- Policy: Admins can view all reading progress for analytics
CREATE POLICY "Admins can view all reading progress" ON ebook_reading_progress
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE id = auth.uid() AND role = 'admin'
    )
);

-- =============================================
-- 6. CREATE HELPFUL FUNCTIONS
-- =============================================

-- Function to update is_ebook_available when PDF is uploaded
CREATE OR REPLACE FUNCTION update_ebook_availability()
RETURNS TRIGGER AS $$
BEGIN
    -- Update is_ebook_available based on pdf_storage_path
    NEW.is_ebook_available = (NEW.pdf_storage_path IS NOT NULL AND NEW.pdf_storage_path != '');
    
    -- Set pdf_upload_date if PDF path is being set for first time
    IF OLD.pdf_storage_path IS NULL AND NEW.pdf_storage_path IS NOT NULL THEN
        NEW.pdf_upload_date = NOW();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic ebook availability update
DROP TRIGGER IF EXISTS trigger_update_ebook_availability ON kitab;
CREATE TRIGGER trigger_update_ebook_availability
    BEFORE UPDATE ON kitab
    FOR EACH ROW
    EXECUTE FUNCTION update_ebook_availability();

-- Function to update reading progress
CREATE OR REPLACE FUNCTION update_reading_progress(
    p_kitab_id UUID,
    p_current_page INTEGER,
    p_total_pages INTEGER DEFAULT NULL,
    p_bookmarks JSONB DEFAULT NULL,
    p_notes JSONB DEFAULT NULL
)
RETURNS ebook_reading_progress AS $$
DECLARE
    result ebook_reading_progress;
    calculated_progress DECIMAL(5,2);
BEGIN
    -- Calculate progress percentage
    IF p_total_pages IS NOT NULL AND p_total_pages > 0 THEN
        calculated_progress = ROUND((p_current_page::DECIMAL / p_total_pages::DECIMAL) * 100, 2);
    ELSE
        calculated_progress = 0;
    END IF;
    
    -- Insert or update reading progress
    INSERT INTO ebook_reading_progress (
        user_id, kitab_id, current_page, total_pages, 
        progress_percentage, bookmarks, notes, last_read_at, updated_at
    )
    VALUES (
        auth.uid(), p_kitab_id, p_current_page, p_total_pages,
        calculated_progress, 
        COALESCE(p_bookmarks, '[]'::jsonb),
        COALESCE(p_notes, '{}'::jsonb),
        NOW(), NOW()
    )
    ON CONFLICT (user_id, kitab_id) 
    DO UPDATE SET
        current_page = p_current_page,
        total_pages = COALESCE(p_total_pages, ebook_reading_progress.total_pages),
        progress_percentage = calculated_progress,
        bookmarks = COALESCE(p_bookmarks, ebook_reading_progress.bookmarks),
        notes = COALESCE(p_notes, ebook_reading_progress.notes),
        last_read_at = NOW(),
        updated_at = NOW()
    RETURNING * INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 7. CREATE INDEXES FOR PERFORMANCE
-- =============================================

-- Index for e-book filtering
CREATE INDEX IF NOT EXISTS idx_kitab_ebook_available ON kitab(is_ebook_available) WHERE is_ebook_available = true;

-- Index for PDF storage path lookups
CREATE INDEX IF NOT EXISTS idx_kitab_pdf_storage_path ON kitab(pdf_storage_path) WHERE pdf_storage_path IS NOT NULL;

-- Indexes for reading progress
CREATE INDEX IF NOT EXISTS idx_ebook_progress_user_id ON ebook_reading_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_ebook_progress_kitab_id ON ebook_reading_progress(kitab_id);
CREATE INDEX IF NOT EXISTS idx_ebook_progress_last_read ON ebook_reading_progress(last_read_at DESC);

-- =============================================
-- 8. CREATE VIEWS FOR EASY QUERYING
-- =============================================

-- View for available e-books with user access
CREATE OR REPLACE VIEW available_ebooks AS
SELECT 
    k.id,
    k.title,
    k.author,
    k.description,
    k.category_id,
    k.is_premium,
    k.pdf_storage_path,
    k.pdf_file_size,
    k.pdf_upload_date,
    k.created_at,
    c.name as category_name,
    -- Check if current user has access
    CASE 
        WHEN NOT k.is_premium THEN true
        WHEN EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() 
            AND (role = 'admin' OR subscription_status = 'active')
        ) THEN true
        ELSE false
    END as user_has_access
FROM kitab k
LEFT JOIN categories c ON k.category_id = c.id
WHERE k.is_ebook_available = true
ORDER BY k.created_at DESC;

-- View for user reading progress with kitab details
CREATE OR REPLACE VIEW user_reading_progress AS
SELECT 
    erp.id,
    erp.user_id,
    erp.kitab_id,
    erp.current_page,
    erp.total_pages,
    erp.progress_percentage,
    erp.last_read_at,
    erp.bookmarks,
    erp.notes,
    k.title as kitab_title,
    k.author as kitab_author,
    k.pdf_storage_path,
    c.name as category_name
FROM ebook_reading_progress erp
JOIN kitab k ON erp.kitab_id = k.id
LEFT JOIN categories c ON k.category_id = c.id
WHERE erp.user_id = auth.uid()
ORDER BY erp.last_read_at DESC;

-- =============================================
-- MIGRATION COMPLETE
-- =============================================

-- Update migration tracking
INSERT INTO schema_migrations (version, applied_at) 
VALUES ('010_setup_ebook_storage_and_policies', NOW())
ON CONFLICT (version) DO UPDATE SET applied_at = NOW();

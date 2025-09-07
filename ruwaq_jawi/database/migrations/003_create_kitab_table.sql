-- Create kitab table (main content table)
CREATE TABLE kitab (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  author TEXT,
  description TEXT,
  category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
  pdf_url TEXT,
  youtube_video_id TEXT, -- YouTube video ID (e.g., 'dQw4w9WgXcQ')
  youtube_video_url TEXT, -- Full YouTube URL for backup
  thumbnail_url TEXT, -- YouTube thumbnail or custom thumbnail
  is_premium BOOLEAN DEFAULT true,
  duration_minutes INTEGER, -- Video duration in minutes
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create trigger for updated_at
CREATE TRIGGER update_kitab_updated_at 
    BEFORE UPDATE ON kitab 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Create indexes for better performance
CREATE INDEX idx_kitab_category_id ON kitab(category_id);
CREATE INDEX idx_kitab_is_premium ON kitab(is_premium);
CREATE INDEX idx_kitab_sort_order ON kitab(sort_order);
CREATE INDEX idx_kitab_title ON kitab(title);
CREATE INDEX idx_kitab_author ON kitab(author);

-- Enable Row Level Security
ALTER TABLE kitab ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Anyone can view non-premium kitab
CREATE POLICY "Anyone can view non-premium kitab" ON kitab
    FOR SELECT USING (NOT is_premium);

-- Authenticated users with active subscription can view premium kitab
CREATE POLICY "Subscribers can view premium kitab" ON kitab
    FOR SELECT USING (
        is_premium AND 
        auth.uid() IS NOT NULL AND
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() 
            AND subscription_status = 'active'
        )
    );

-- Admins can view all kitab
CREATE POLICY "Admins can view all kitab" ON kitab
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Only admins can insert, update, delete kitab
CREATE POLICY "Admins can insert kitab" ON kitab
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY "Admins can update kitab" ON kitab
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY "Admins can delete kitab" ON kitab
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

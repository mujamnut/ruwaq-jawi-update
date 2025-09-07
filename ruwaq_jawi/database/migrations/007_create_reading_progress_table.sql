-- Create reading_progress table (user progress tracking)
CREATE TABLE reading_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  kitab_id UUID REFERENCES kitab(id) ON DELETE CASCADE,
  video_progress INTEGER DEFAULT 0, -- seconds watched
  pdf_page INTEGER DEFAULT 1,
  last_accessed TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, kitab_id)
);

-- Create indexes
CREATE INDEX idx_reading_progress_user_id ON reading_progress(user_id);
CREATE INDEX idx_reading_progress_kitab_id ON reading_progress(kitab_id);
CREATE INDEX idx_reading_progress_last_accessed ON reading_progress(last_accessed);

-- Enable Row Level Security
ALTER TABLE reading_progress ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view their own reading progress
CREATE POLICY "Users can view own reading progress" ON reading_progress
    FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own reading progress
CREATE POLICY "Users can insert own reading progress" ON reading_progress
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own reading progress
CREATE POLICY "Users can update own reading progress" ON reading_progress
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can delete their own reading progress
CREATE POLICY "Users can delete own reading progress" ON reading_progress
    FOR DELETE USING (auth.uid() = user_id);

-- Admins can view all reading progress
CREATE POLICY "Admins can view all reading progress" ON reading_progress
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Function to update last_accessed on progress update
CREATE OR REPLACE FUNCTION update_reading_progress_last_accessed()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_accessed = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update last_accessed
CREATE TRIGGER update_reading_progress_last_accessed_trigger
    BEFORE UPDATE ON reading_progress
    FOR EACH ROW EXECUTE FUNCTION update_reading_progress_last_accessed();

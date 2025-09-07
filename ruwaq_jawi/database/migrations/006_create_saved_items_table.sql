-- Create saved_items table (user bookmarks)
CREATE TABLE saved_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  kitab_id UUID REFERENCES kitab(id) ON DELETE CASCADE,
  folder_name TEXT DEFAULT 'Default',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, kitab_id)
);

-- Create indexes
CREATE INDEX idx_saved_items_user_id ON saved_items(user_id);
CREATE INDEX idx_saved_items_kitab_id ON saved_items(kitab_id);
CREATE INDEX idx_saved_items_folder_name ON saved_items(folder_name);

-- Enable Row Level Security
ALTER TABLE saved_items ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view their own saved items
CREATE POLICY "Users can view own saved items" ON saved_items
    FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own saved items
CREATE POLICY "Users can insert own saved items" ON saved_items
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own saved items
CREATE POLICY "Users can update own saved items" ON saved_items
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can delete their own saved items
CREATE POLICY "Users can delete own saved items" ON saved_items
    FOR DELETE USING (auth.uid() = user_id);

-- Admins can view all saved items
CREATE POLICY "Admins can view all saved items" ON saved_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

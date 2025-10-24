-- Migration: Add user popup tracking table
-- Description: Table to track when popup ads were shown to users for subscription promotion

-- Create user_popup_tracking table
CREATE TABLE IF NOT EXISTS user_popup_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    popup_type TEXT NOT NULL DEFAULT 'subscription_promo',
    last_shown_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    show_count INTEGER DEFAULT 1,
    dismissed_permanently BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Create unique constraint to prevent duplicate tracking per user per popup type
    UNIQUE(user_id, popup_type)
);

-- Create index for efficient querying
CREATE INDEX IF NOT EXISTS idx_user_popup_tracking_user_id ON user_popup_tracking(user_id);
CREATE INDEX IF NOT EXISTS idx_user_popup_tracking_popup_type ON user_popup_tracking(popup_type);
CREATE INDEX IF NOT EXISTS idx_user_popup_tracking_last_shown ON user_popup_tracking(last_shown_at);

-- Enable RLS
ALTER TABLE user_popup_tracking ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view their own popup tracking" ON user_popup_tracking
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own popup tracking" ON user_popup_tracking
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own popup tracking" ON user_popup_tracking
    FOR UPDATE USING (auth.uid() = user_id);

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_user_popup_tracking_updated_at
    BEFORE UPDATE ON user_popup_tracking
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Comment on table and columns
COMMENT ON TABLE user_popup_tracking IS 'Tracks when popup advertisements were shown to users';
COMMENT ON COLUMN user_popup_tracking.popup_type IS 'Type of popup shown (e.g., subscription_promo)';
COMMENT ON COLUMN user_popup_tracking.last_shown_at IS 'When the popup was last shown to the user';
COMMENT ON COLUMN user_popup_tracking.show_count IS 'Number of times this popup has been shown';
COMMENT ON COLUMN user_popup_tracking.dismissed_permanently IS 'Whether user chose to never see this popup again';
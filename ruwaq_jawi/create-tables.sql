-- Create webhook_events table for audit trail
CREATE TABLE IF NOT EXISTS webhook_events (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    provider TEXT NOT NULL,
    event_type TEXT NOT NULL,
    bill_code TEXT,
    transaction_id TEXT,
    status TEXT,
    status_id TEXT,
    raw_payload JSONB,
    received_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_webhook_events_bill_code ON webhook_events(bill_code);
CREATE INDEX IF NOT EXISTS idx_webhook_events_transaction_id ON webhook_events(transaction_id);
CREATE INDEX IF NOT EXISTS idx_webhook_events_received_at ON webhook_events(received_at DESC);

-- Create direct_activations table for audit trail of manual activations
CREATE TABLE IF NOT EXISTS direct_activations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    bill_id TEXT NOT NULL,
    transaction_id TEXT NOT NULL,
    plan_id TEXT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    reason TEXT NOT NULL,
    activated_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_direct_activations_user_id ON direct_activations(user_id);
CREATE INDEX IF NOT EXISTS idx_direct_activations_bill_id ON direct_activations(bill_id);
CREATE INDEX IF NOT EXISTS idx_direct_activations_activated_at ON direct_activations(activated_at DESC);

-- Add foreign key constraint if profiles table exists
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'profiles') THEN
        ALTER TABLE direct_activations 
        ADD CONSTRAINT fk_direct_activations_user_id 
        FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Create or update the pending_payments table with proper constraints if it doesn't exist
CREATE TABLE IF NOT EXISTS pending_payments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    bill_id TEXT NOT NULL,
    user_id UUID NOT NULL,
    plan_id TEXT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Add unique constraint to prevent duplicate payments
    UNIQUE(bill_id, user_id)
);

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_pending_payments_bill_id ON pending_payments(bill_id);
CREATE INDEX IF NOT EXISTS idx_pending_payments_user_id ON pending_payments(user_id);
CREATE INDEX IF NOT EXISTS idx_pending_payments_status ON pending_payments(status);

-- Add comments for documentation
COMMENT ON TABLE webhook_events IS 'Audit trail for all webhook events received from payment providers';
COMMENT ON TABLE direct_activations IS 'Audit trail for manual subscription activations when API verification fails';
COMMENT ON TABLE pending_payments IS 'Track pending payments that need verification';

-- Example queries for monitoring
/*
-- Check recent webhook events
SELECT provider, event_type, bill_code, status, status_id, received_at 
FROM webhook_events 
ORDER BY received_at DESC 
LIMIT 10;

-- Check recent direct activations
SELECT user_id, bill_id, plan_id, amount, reason, activated_at 
FROM direct_activations 
ORDER BY activated_at DESC 
LIMIT 10;

-- Check pending payments
SELECT bill_id, user_id, plan_id, amount, status, created_at 
FROM pending_payments 
WHERE status = 'pending' 
ORDER BY created_at DESC;
*/

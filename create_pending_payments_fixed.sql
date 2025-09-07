-- ✅ FIXED: Create pending_payments table dengan correct data types
-- Kerana subscription_plans.id adalah TEXT, bukan UUID

-- Drop table jika ada (untuk testing)
DROP TABLE IF EXISTS pending_payments;

-- Create table dengan correct types
CREATE TABLE pending_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bill_id TEXT NOT NULL UNIQUE,
  user_id UUID NOT NULL,
  plan_id TEXT NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'expired')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add foreign key constraints manually (selepas table created)
ALTER TABLE pending_payments 
ADD CONSTRAINT fk_pending_payments_user_id 
FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE pending_payments 
ADD CONSTRAINT fk_pending_payments_plan_id 
FOREIGN KEY (plan_id) REFERENCES subscription_plans(id) ON DELETE CASCADE;

-- Create indexes untuk performance
CREATE INDEX idx_pending_payments_bill_id ON pending_payments(bill_id);
CREATE INDEX idx_pending_payments_user_id ON pending_payments(user_id);
CREATE INDEX idx_pending_payments_status ON pending_payments(status);
CREATE INDEX idx_pending_payments_created_at ON pending_payments(created_at);

-- Enable RLS
ALTER TABLE pending_payments ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view their own pending payments" ON pending_payments
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own pending payments" ON pending_payments
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own pending payments" ON pending_payments
  FOR UPDATE USING (auth.uid() = user_id);

-- Service role can do everything
CREATE POLICY "Service role can manage all pending payments" ON pending_payments
  FOR ALL USING (auth.role() = 'service_role');

-- Add table comment
COMMENT ON TABLE pending_payments IS 'Table untuk track pembayaran ToyyibPay yang belum selesai';

-- Test insert (optional - untuk verify table working)
-- INSERT INTO pending_payments (bill_id, user_id, plan_id, amount) 
-- VALUES ('TEST_BILL_123', 'YOUR_USER_UUID_HERE', 'monthly_premium', 15.00);

-- Verify table created successfully
SELECT 'pending_payments table created successfully!' as status;

-- 🚀 SIMPLE VERSION: Create pending_payments table tanpa foreign key constraints
-- Guna ini jika Option 1 masih ada masalah

-- Drop table jika ada
DROP TABLE IF EXISTS pending_payments;

-- Create table yang simple
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

-- Create indexes
CREATE INDEX idx_pending_payments_bill_id ON pending_payments(bill_id);
CREATE INDEX idx_pending_payments_user_id ON pending_payments(user_id);
CREATE INDEX idx_pending_payments_status ON pending_payments(status);
CREATE INDEX idx_pending_payments_created_at ON pending_payments(created_at);

-- Enable RLS
ALTER TABLE pending_payments ENABLE ROW LEVEL SECURITY;

-- Simple RLS policies
CREATE POLICY "pending_payments_select_policy" ON pending_payments
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "pending_payments_insert_policy" ON pending_payments
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "pending_payments_update_policy" ON pending_payments
  FOR UPDATE USING (auth.uid() = user_id);

-- Service role full access
CREATE POLICY "service_role_all_access" ON pending_payments
  FOR ALL USING (auth.role() = 'service_role');

-- Table comment
COMMENT ON TABLE pending_payments IS 'Payment tracking table for ToyyibPay transactions';

-- Success message
SELECT 'pending_payments table created successfully (simple version)!' as result;

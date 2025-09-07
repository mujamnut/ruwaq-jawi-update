// Deploy script untuk Payment System tanpa webhook
// Kerana ToyyibPay hanya ada Secret Key dan Category Code

const { createClient } = require('@supabase/supabase-js');

// Setup Supabase client
const supabaseUrl = 'https://ckgxglvozrsognqqkpkk.supabase.co';
const supabaseServiceKey = 'YOUR_SERVICE_ROLE_KEY'; // Ganti dengan service role key anda
const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function deployPendingPaymentsTable() {
  console.log('📦 Creating pending_payments table...');
  
  const createTableSQL = `
    -- Create pending_payments table untuk track payment yang belum selesai
    CREATE TABLE IF NOT EXISTS pending_payments (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      bill_id TEXT NOT NULL UNIQUE,
      user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
      plan_id UUID NOT NULL REFERENCES subscription_plans(id) ON DELETE CASCADE,
      amount DECIMAL(10,2) NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'expired')),
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    -- Create indexes untuk performance
    CREATE INDEX IF NOT EXISTS idx_pending_payments_bill_id ON pending_payments(bill_id);
    CREATE INDEX IF NOT EXISTS idx_pending_payments_user_id ON pending_payments(user_id);
    CREATE INDEX IF NOT EXISTS idx_pending_payments_status ON pending_payments(status);
    CREATE INDEX IF NOT EXISTS idx_pending_payments_created_at ON pending_payments(created_at);

    -- Enable RLS
    ALTER TABLE pending_payments ENABLE ROW LEVEL SECURITY;

    -- RLS Policies
    DROP POLICY IF EXISTS "Users can view their own pending payments" ON pending_payments;
    CREATE POLICY "Users can view their own pending payments" ON pending_payments
      FOR SELECT USING (auth.uid() = user_id);

    DROP POLICY IF EXISTS "Users can insert their own pending payments" ON pending_payments;
    CREATE POLICY "Users can insert their own pending payments" ON pending_payments
      FOR INSERT WITH CHECK (auth.uid() = user_id);

    DROP POLICY IF EXISTS "Users can update their own pending payments" ON pending_payments;
    CREATE POLICY "Users can update their own pending payments" ON pending_payments
      FOR UPDATE USING (auth.uid() = user_id);

    -- Service role can do everything
    DROP POLICY IF EXISTS "Service role can manage all pending payments" ON pending_payments;
    CREATE POLICY "Service role can manage all pending payments" ON pending_payments
      FOR ALL USING (auth.role() = 'service_role');

    -- Add comment
    COMMENT ON TABLE pending_payments IS 'Table untuk track pembayaran yang belum selesai dari ToyyibPay';
  `;

  try {
    const { error } = await supabase.rpc('exec_sql', { sql: createTableSQL });
    
    if (error) {
      console.log('❌ Error creating table:', error);
    } else {
      console.log('✅ pending_payments table created successfully');
    }
  } catch (e) {
    console.log('❌ Exception creating table:', e);
  }
}

async function testToyyibPayIntegration() {
  console.log('🧪 Testing ToyyibPay integration...');
  
  // Ganti dengan credentials anda
  const TOYYIBPAY_SECRET_KEY = 'YOUR_TOYYIBPAY_SECRET_KEY';
  const TEST_BILL_ID = 'TEST_BILL_ID'; // Guna bill ID yang wujud untuk testing
  
  try {
    const response = await fetch('https://dev.toyyibpay.com/index.php/api/getBillTransactions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        userSecretKey: TOYYIBPAY_SECRET_KEY,
        billId: TEST_BILL_ID
      })
    });

    if (response.ok) {
      const data = await response.json();
      console.log('✅ ToyyibPay API working!');
      console.log('📄 Sample response:', JSON.stringify(data, null, 2));
    } else {
      console.log(`❌ ToyyibPay API Error: ${response.status}`);
      const errorText = await response.text();
      console.log('Error details:', errorText);
    }
  } catch (e) {
    console.log('❌ Error testing ToyyibPay:', e);
  }
}

async function createTestPendingPayment() {
  console.log('🧪 Creating test pending payment...');
  
  try {
    // Get first user untuk testing
    const { data: users, error: userError } = await supabase
      .from('profiles')
      .select('id, full_name')
      .limit(1);

    if (userError || !users || users.length === 0) {
      console.log('❌ No users found for testing');
      return;
    }

    const testUser = users[0];
    
    // Get first plan untuk testing
    const { data: plans, error: planError } = await supabase
      .from('subscription_plans')
      .select('id, name, price')
      .limit(1);

    if (planError || !plans || plans.length === 0) {
      console.log('❌ No plans found for testing');
      return;
    }

    const testPlan = plans[0];
    
    // Create test pending payment
    const { data, error } = await supabase
      .from('pending_payments')
      .insert({
        bill_id: `TEST_${Date.now()}`,
        user_id: testUser.id,
        plan_id: testPlan.id,
        amount: testPlan.price,
        status: 'pending'
      })
      .select()
      .single();

    if (error) {
      console.log('❌ Error creating test payment:', error);
    } else {
      console.log('✅ Test pending payment created:');
      console.log(`   - Bill ID: ${data.bill_id}`);
      console.log(`   - User: ${testUser.full_name}`);
      console.log(`   - Plan: ${testPlan.name}`);
      console.log(`   - Amount: RM${testPlan.price}`);
    }
  } catch (e) {
    console.log('❌ Error creating test payment:', e);
  }
}

async function showInstructions() {
  console.log(`
🚀 PAYMENT SYSTEM DEPLOYMENT COMPLETED!

Sekarang anda boleh gunakan sistem ini dengan cara berikut:

1. 📝 SET TOYYIBPAY CREDENTIALS:
   - Pergi ke Supabase Dashboard > Project Settings > Edge Function Secrets
   - Add secret: TOYYIBPAY_SECRET_KEY = your_secret_key_here
   - Add secret: TOYYIBPAY_CATEGORY_CODE = your_category_code_here

2. 🔄 DEPLOY EDGE FUNCTION:
   - Upload file 'supabase/functions/verify-payment/index.ts' ke Supabase
   - Atau guna Supabase CLI: supabase functions deploy verify-payment --no-verify-jwt

3. 💳 PAYMENT FLOW YANG BARU:
   a) User pilih plan dan create payment link ToyyibPay
   b) User redirect ke ToyyibPay untuk bayar
   c) Selepas payment, user balik ke app anda
   d) App panggil verifyPaymentStatus() untuk check payment
   e) Jika payment success, subscription akan auto activate

4. 🧪 TESTING:
   - Guna function verifyPaymentStatus() dalam app
   - Atau panggil edge function terus:
     POST https://ckgxglvozrsognqqkpkk.supabase.co/functions/v1/verify-payment
     Body: {"billId": "YOUR_BILL_ID", "userId": "USER_ID", "planId": "PLAN_ID"}

5. 📊 MONITORING:
   - Check table 'pending_payments' untuk payment yang belum selesai
   - Check table 'user_subscriptions' untuk subscription yang aktif
   - Check table 'payments' untuk payment history

EXAMPLE USAGE DALAM APP:
```dart
// Selepas user balik dari ToyyibPay
final success = await subscriptionProvider.verifyPaymentStatus(
  billId: "BILL_ID_FROM_TOYYIBPAY", 
  planId: "monthly_premium"
);

if (success) {
  // Subscription activated!
  Navigator.pushReplacementNamed(context, '/subscription-success');
} else {
  // Payment still pending atau failed
  showDialog(...);
}
```

❗ PENTING: Jangan lupa set ToyyibPay credentials dalam Supabase secrets!
  `);
}

async function main() {
  console.log('🚀 Deploying Payment System without Webhook...\n');
  
  await deployPendingPaymentsTable();
  console.log('');
  
  await createTestPendingPayment();
  console.log('');
  
  // Uncomment untuk test ToyyibPay API (ganti dengan credentials betul)
  // await testToyyibPayIntegration();
  // console.log('');
  
  await showInstructions();
}

main().catch(console.error);

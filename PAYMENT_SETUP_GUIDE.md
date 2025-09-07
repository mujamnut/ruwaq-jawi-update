# 🚀 Payment System Setup Guide (Tanpa Webhook)

Kerana ToyyibPay dashboard anda hanya ada **Secret Key** dan **Category Code** sahaja, kami akan gunakan **polling method** untuk memeriksa status pembayaran.

## 📋 Langkah-langkah Setup

### 1. 📝 Set Supabase Edge Function Secrets

Pergi ke [Supabase Dashboard](https://supabase.com/dashboard/projects) > Pilih project anda > Settings > Edge Functions > Environment Variables

Tambah secrets berikut:
```
TOYYIBPAY_SECRET_KEY = your_secret_key_here
TOYYIBPAY_CATEGORY_CODE = your_category_code_here
```

### 2. 🗄️ Deploy Database Migration

Copy dan run SQL ini dalam [Supabase SQL Editor](https://supabase.com/dashboard/project/ckgxglvozrsognqqkpkk/sql):

```sql
-- Create pending_payments table untuk track payment yang belum selesai
CREATE TABLE IF NOT EXISTS pending_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bill_id TEXT NOT NULL UNIQUE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_id TEXT NOT NULL REFERENCES subscription_plans(id) ON DELETE CASCADE,
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
```

### 3. 🔄 Deploy Edge Function

1. Pergi ke [Supabase Dashboard](https://supabase.com/dashboard/projects) > Pilih project anda > Edge Functions
2. Click **Create a new function**
3. Name: `verify-payment`
4. Copy paste kod dari file `supabase/functions/verify-payment/index.ts`
5. **PENTING**: Uncheck "Require JWT verification" kerana function ini akan dipanggil dari client app
6. Click **Deploy function**

### 4. 💳 Update Payment Flow

Sekarang payment flow akan jadi macam ini:

```dart
// 1. Sebelum redirect ke ToyyibPay
final billId = "BILL_ID_DARI_TOYYIBPAY";
await subscriptionProvider.storePendingPayment(
  billId: billId,
  planId: selectedPlanId,
  amount: planAmount,
);

// 2. Redirect user ke ToyyibPay...

// 3. Selepas user balik dari ToyyibPay
final success = await subscriptionProvider.verifyPaymentStatus(
  billId: billId,
  planId: selectedPlanId,
);

if (success) {
  // 🎉 Payment success! Subscription activated
  Navigator.pushReplacementNamed(context, '/subscription-success');
} else {
  // ⏳ Payment masih pending atau gagal
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Pembayaran Belum Selesai'),
      content: Text('Pembayaran anda masih dalam proses. Sila cuba lagi sebentar.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('OK'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            // Try verify again
            await subscriptionProvider.verifyPaymentStatus(
              billId: billId,
              planId: selectedPlanId,
            );
          },
          child: Text('Cuba Lagi'),
        ),
      ],
    ),
  );
}
```

## 🧪 Testing Payment System

### Test 1: Manual Activation
```dart
// Untuk testing, anda boleh manually activate subscription
final subscriptionService = SubscriptionService(SupabaseService.client);
await subscriptionService.manuallyActivateSubscription(
  userId: 'USER_ID',
  planId: 'monthly_premium',
  amount: 15.0,
);
```

### Test 2: Edge Function Test
Gunakan API testing tool macam Postman:

**Endpoint:** `POST https://ckgxglvozrsognqqkpkk.supabase.co/functions/v1/verify-payment`

**Headers:**
```
Content-Type: application/json
Authorization: Bearer YOUR_USER_JWT_TOKEN
```

**Body:**
```json
{
  "billId": "TEST_BILL_ID",
  "userId": "USER_UUID", 
  "planId": "PLAN_UUID"
}
```

### Test 3: Check Pending Payments
```dart
final pendingPayments = await subscriptionProvider.getPendingPayments();
print('Pending payments: $pendingPayments');
```

## 📊 Monitoring Dashboard

Anda boleh monitor payment status melalui Supabase Dashboard:

1. **pending_payments table** - Payment yang belum selesai
2. **user_subscriptions table** - Subscription yang aktif
3. **payments table** - Payment history
4. **Edge Function logs** - Logs untuk verify-payment function

## 🔧 Troubleshooting

### Jika Payment Tidak Activate:

1. **Check ToyyibPay API response:**
   - Masuk ke Edge Function logs
   - Tengok response dari ToyyibPay API
   - Pastikan status code `1` untuk success

2. **Check Bill ID:**
   - Pastikan Bill ID yang dihantar sama dengan yang ToyyibPay bagi
   - Check dalam `pending_payments` table

3. **Manual verification:**
   - Guna manual test script untuk check payment status
   - Call edge function terus dengan Bill ID yang betul

### Error Common:

- **401 Unauthorized**: Set JWT token dalam Authorization header
- **ToyyibPay API Error**: Check Secret Key dan Bill ID
- **Plan not found**: Pastikan Plan ID wujud dalam `subscription_plans` table

## 🚀 Production Deployment

Untuk production:

1. Tukar ToyyibPay URL dari `dev.toyyibpay.com` ke `toyyibpay.com`
2. Guna production Secret Key dan Category Code
3. Set proper error handling dan retry mechanism
4. Add logging untuk audit trail

---

**Next Steps:**
1. Set Supabase secrets untuk ToyyibPay credentials
2. Deploy edge function `verify-payment`
3. Test payment flow end-to-end
4. Monitor logs dan database untuk ensure everything works

Anda sudah ready untuk test payment system yang baru! 🎉

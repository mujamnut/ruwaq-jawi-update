# 🔧 Subscription Payment Fix - Panduan Lengkap

## ❌ Masalah Asal:
- User buat payment tapi subscription tak aktif
- Profile `subscription_status` kekal "inactive"
- Tiada record dalam `user_subscriptions` table

## ✅ Masalah Telah Diperbaiki:

### 1. **Manual Activation Berfungsi**
Test manual menunjukkan sistem boleh aktivate subscription dengan betul:
- ✅ `user_subscriptions` table updated
- ✅ `profiles.subscription_status` = "active"
- ✅ Subscription aktif hingga end date yang betul

### 2. **Edge Function Sedia Ada Okay**
Edge function `payment-webhook` yang sedia ada sudah ada logic yang betul dan boleh update database.

## 🚨 Masalah Utama Yang Perlu Diselesaikan:

**Webhook dari ToyyibPay tidak sampai ke edge function sebab JWT verification.**

## 🛠️ Langkah Penyelesaian:

### **LANGKAH 1: Update Client Code**

Ganti file `subscription_service.dart` dengan `subscription_service_new.dart`:

```bash
# Backup file lama
mv lib/core/services/subscription_service.dart lib/core/services/subscription_service_old.dart

# Guna service baru
mv lib/core/services/subscription_service_new.dart lib/core/services/subscription_service.dart
```

### **LANGKAH 2: Test ToyyibPay Webhook**

ToyyibPay webhook URL sepatutnya point ke:
```
https://ckgxglvozrsognqqkpkk.functions.supabase.co/payment-webhook
```

### **LANGKAH 3: Debug Webhook Issues**

Jika webhook masih tidak berfungsi, check:

1. **ToyyibPay webhook configuration:**
   - URL betul ke edge function
   - HTTP method = POST
   - Content-Type = application/x-www-form-urlencoded

2. **Supabase Edge Function:**
   - Environment variables (`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`) set dengan betul
   - Function tidak crash (check logs)

3. **Order ID format:**
   - Pastikan format: `{userId}_{planId}`
   - Contoh: `a37deced-84a8-4033-b678-abe67ba6cd7f_monthly_premium`

### **LANGKAH 4: Manual Testing**

Untuk test tanpa payment gateway, guna edge function `manual-subscription`:

```javascript
// Call dalam browser console atau Postman
fetch('https://ckgxglvozrsognqqkpkk.functions.supabase.co/manual-subscription', {
  method: 'POST',\n  headers: {\n    'Content-Type': 'application/json',\n    'apikey': 'YOUR_ANON_KEY',\n    'authorization': 'Bearer YOUR_ANON_KEY'\n  },\n  body: JSON.stringify({\n    action: 'activate_subscription',\n    userId: 'USER_ID_HERE',\n    planId: 'monthly_premium'\n  })\n})\n.then(res => res.json())\n.then(data => console.log(data));\n```

### **LANGKAH 5: Check Subscription Status**

```javascript\nfetch('https://ckgxglvozrsognqqkpkk.functions.supabase.co/manual-subscription', {\n  method: 'POST',\n  headers: {\n    'Content-Type': 'application/json',\n    'apikey': 'YOUR_ANON_KEY',\n    'authorization': 'Bearer YOUR_ANON_KEY'\n  },\n  body: JSON.stringify({\n    action: 'check_subscription',\n    userId: 'USER_ID_HERE'\n  })\n})\n.then(res => res.json())\n.then(data => console.log(data));\n```\n\n## 📊 Files Yang Telah Dibuat/Updated:\n\n1. **`subscription_service_new.dart`** - Service yang guna `user_subscriptions` table sahaja\n2. **`subscription_service_fixed.dart`** - Service dengan dual table support\n3. **`toyyibpay_webhook_fixed.ts`** - Fixed webhook handler\n4. **`manual_test_subscription.js`** - Test script untuk webhook\n5. **`test_subscription_sync.dart`** - Debug script untuk subscription\n6. **Edge Function: `manual-subscription`** - Manual activation/testing\n7. **Edge Function: `webhook-simple`** - Simplified webhook handler\n\n## 🔍 Debugging Commands:\n\n```sql\n-- Check profile status\nSELECT id, full_name, subscription_status, updated_at FROM profiles WHERE full_name = 'mujam';\n\n-- Check user subscriptions\nSELECT * FROM user_subscriptions WHERE user_id = 'a37deced-84a8-4033-b678-abe67ba6cd7f';\n\n-- Check webhook logs\nSELECT * FROM webhook_logs ORDER BY created_at DESC LIMIT 5;\n\n-- Check payments\nSELECT * FROM payments ORDER BY created_at DESC LIMIT 5;\n```\n\n## ✅ Status Terkini:\n\n- ✅ **Manual activation**: BERFUNGSI\n- ✅ **Database updates**: BERFUNGSI\n- ✅ **Profile status**: BOLEH UPDATE\n- ❓ **ToyyibPay webhook**: PERLU VERIFICATION\n\n## 🚀 Next Steps:\n\n1. **Test dengan payment sebenar** menggunakan edge function `payment-webhook`\n2. **Monitor webhook logs** untuk melihat sama ada webhook sampai\n3. **Update client code** untuk guna service baru\n4. **Jika webhook masih issue**, consider disable JWT verification untuk webhook endpoint\n\n---\n\n**✨ KESIMPULAN: Sistem subscription sudah betul dan boleh activate user dengan sempurna. Masalah utama adalah webhook configuration atau JWT verification yang menghalang ToyyibPay webhook dari berjalan.**

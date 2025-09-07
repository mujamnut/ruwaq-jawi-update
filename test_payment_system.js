// Test script untuk payment verification system
// Guna untuk test ToyyibPay API integration

const fetch = require('node-fetch'); // npm install node-fetch

// CONFIGURATION - Ganti dengan values sebenar anda
const CONFIG = {
  SUPABASE_URL: 'https://ckgxglvozrsognqqkpkk.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNrZ3hnbHZvenJzb2ducXFrcGtrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYyOTIwMDYsImV4cCI6MjA3MTg2ODAwNn0.AnTcS1uSC83m7pYT9UxAb_enhcEGCIor49AhuyCTkiQ',
  TOYYIBPAY_SECRET_KEY: 'j82mer37-15g3-zezd-nmq3-hcha3n8gt3xz',
  TOYYIBPAY_CATEGORY_CODE: 'rfihs2ao',

  TEST_BILL_ID: '56hoy14p', // Guna Bill ID yang wujud
  TEST_USER_ID: '6cfe0f2d-7432-429c-8f0d-15ba5a70b8bb',
  TEST_PLAN_ID: 'monthly_basic',
};

async function testToyyibPayAPI() {
  console.log('🧪 Testing ToyyibPay API...');
  
  try {
    const response = await fetch('https://dev.toyyibpay.com/index.php/api/getBillTransactions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        userSecretKey: CONFIG.TOYYIBPAY_SECRET_KEY,
        billId: CONFIG.TEST_BILL_ID
      })
    });

    console.log(`📡 Response Status: ${response.status}`);
    
    if (response.ok) {
      const data = await response.json();
      console.log('✅ ToyyibPay API working!');
      console.log('📄 Response data:');
      console.log(JSON.stringify(data, null, 2));
      
      // Parse status
      if (Array.isArray(data) && data.length > 0) {
        const transaction = data[0];
        console.log('\n📊 Payment Status Analysis:');
        console.log(`   Status Code: ${transaction.billpaymentStatus}`);
        console.log(`   Status Meaning: ${getStatusMeaning(transaction.billpaymentStatus)}`);
        console.log(`   Amount: RM${transaction.billAmount}`);
        console.log(`   Paid Amount: RM${transaction.billpaidAmount || '0'}`);
        console.log(`   Payment Date: ${transaction.billpaymentDate || 'Not paid'}`);
      }
      
      return true;
    } else {
      const errorText = await response.text();
      console.log('❌ ToyyibPay API Error:');
      console.log(errorText);
      return false;
    }
  } catch (e) {
    console.log('❌ Error testing ToyyibPay API:', e.message);
    return false;
  }
}

async function testEdgeFunction() {
  console.log('\n🧪 Testing Edge Function...');
  
  try {
    const response = await fetch(`${CONFIG.SUPABASE_URL}/functions/v1/verify-payment`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${CONFIG.SUPABASE_ANON_KEY}`,
      },
      body: JSON.stringify({
        billId: CONFIG.TEST_BILL_ID,
        userId: CONFIG.TEST_USER_ID,
        planId: CONFIG.TEST_PLAN_ID,
      })
    });

    console.log(`📡 Edge Function Response Status: ${response.status}`);
    
    const data = await response.json();
    console.log('📄 Edge Function Response:');
    console.log(JSON.stringify(data, null, 2));
    
    if (data.success) {
      console.log('✅ Edge Function working! Payment verification successful.');
    } else {
      console.log('⚠️ Edge Function working but payment not completed yet.');
    }
    
    return true;
  } catch (e) {
    console.log('❌ Error testing Edge Function:', e.message);
    return false;
  }
}

function getStatusMeaning(status) {
  switch (String(status)) {
    case '0': return 'Pending (Belum dibayar)';
    case '1': return 'Success (Berjaya dibayar)';
    case '2': return 'Failed (Gagal dibayar)';
    case '3': return 'Failed (Gagal dibayar)';
    default: return `Unknown status: ${status}`;
  }
}

async function showUsageInstructions() {
  console.log(`
📚 CARA GUNA PAYMENT SYSTEM:

1. 🔧 UPDATE CONFIGURATION:
   - Ganti semua values dalam CONFIG object dengan values sebenar anda
   - Pastikan TEST_BILL_ID adalah Bill ID yang betul dari ToyyibPay

2. 💳 DALAM APP ANDA:
   
   a) Sebelum redirect ke ToyyibPay:
   ```dart
   await subscriptionProvider.storePendingPayment(
     billId: billId,
     planId: planId, 
     amount: amount
   );
   ```
   
   b) Selepas user balik dari ToyyibPay:
   ```dart
   final success = await subscriptionProvider.verifyPaymentStatus(
     billId: billId,
     planId: planId
   );
   ```

3. 🎯 TESTING STEPS:
   - Run script ini untuk test ToyyibPay API
   - Test edge function dengan credentials betul
   - Test payment flow dalam app

4. 📊 MONITORING:
   - Check Supabase Dashboard untuk logs
   - Monitor pending_payments table
   - Check user_subscriptions table untuk active subscriptions

5. 🚀 PRODUCTION:
   - Tukar URL dari dev.toyyibpay.com ke toyyibpay.com
   - Guna production credentials
   - Set proper error handling
  `);
}

async function main() {
  console.log('🚀 Testing Payment System Components...\n');
  
  // Validate configuration
  const missingConfigs = Object.entries(CONFIG)
    .filter(([key, value]) => value.includes('_HERE'))
    .map(([key]) => key);
    
  if (missingConfigs.length > 0) {
    console.log('⚠️ WARNING: Please update these configuration values:');
    missingConfigs.forEach(config => console.log(`   - ${config}`));
    console.log('\n');
  }
  
  // Test ToyyibPay API
  const toyyibPayWorking = await testToyyibPayAPI();
  
  // Test Edge Function (only if ToyyibPay working)
  if (toyyibPayWorking && !missingConfigs.includes('TEST_USER_ID')) {
    await testEdgeFunction();
  } else {
    console.log('⏭️ Skipping Edge Function test - need valid ToyyibPay response or user credentials');
  }
  
  // Show usage instructions
  await showUsageInstructions();
}

// Run the test
main().catch(console.error);

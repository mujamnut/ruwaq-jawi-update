// Manual test untuk activate subscription
// Guna untuk debug dan test webhook function

const SUPABASE_URL = 'https://ckgxglvozrsognqqkpkk.supabase.co';
const WEBHOOK_URL = 'https://ckgxglvozrsognqqkpkk.functions.supabase.co/webhook-simple';

// Test webhook dengan manual call
async function testWebhook() {
  console.log('🧪 Testing webhook manually...');
  
  // Test data - ganti dengan user ID sebenar anda
  const testUserId = 'a37deced-84a8-4033-b678-abe67ba6cd7f'; // mujam user
  const testPlanId = 'monthly_premium';
  const testAmount = '39.90';
  const testOrderId = `${testUserId}_${testPlanId}`;
  
  // Create form data for ToyyibPay webhook format
  const formData = new FormData();
  formData.append('status', '1'); // 1 = success in ToyyibPay
  formData.append('billcode', 'TEST_' + Date.now());
  formData.append('order_id', testOrderId);
  formData.append('msg', 'Test payment success');
  formData.append('amount', testAmount);
  
  console.log(`📋 Test data:`);
  console.log(`   User ID: ${testUserId}`);
  console.log(`   Plan ID: ${testPlanId}`);
  console.log(`   Order ID: ${testOrderId}`);
  console.log(`   Amount: ${testAmount}`);
  
  try {\n    const response = await fetch(WEBHOOK_URL, {\n      method: 'POST',\n      body: formData\n    });\n    \n    const result = await response.text();\n    \n    console.log(`📈 Response status: ${response.status}`);\n    console.log(`📄 Response body: ${result}`);\n    \n    if (response.ok) {\n      console.log('✅ Webhook test completed successfully!');\n      console.log('💡 Now check your Supabase database:');\n      console.log('   1. Check user_subscriptions table');\n      console.log('   2. Check profiles table subscription_status');\n      console.log('   3. Check payments table');\n      console.log('   4. Check webhook_logs table');\n    } else {\n      console.log('❌ Webhook test failed');\n    }\n    \n  } catch (error) {\n    console.error('💥 Error calling webhook:', error);\n  }\n}\n\n// Run the test\ntestWebhook();\n\n/*\nUSAGE:\n\n1. Update testUserId dengan user ID sebenar dari database anda\n2. Run script ini dalam browser console atau Node.js\n3. Check Supabase database untuk verify subscription activated\n4. Jika successful, webhook anda dah okay\n5. Jika gagal, check edge function logs\n\nTO RUN:\n- Browser: Copy paste dalam browser console\n- Node.js: node manual_test_subscription.js\n- Deno: deno run --allow-net manual_test_subscription.js\n*/

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log(`📥 Payment redirect - Method: ${req.method}`)
    console.log(`📥 URL: ${req.url}`)

    // Parse URL parameters
    const url = new URL(req.url)
    const status = url.searchParams.get('status')
    const statusId = url.searchParams.get('status_id')
    const billCode = url.searchParams.get('billcode')
    const orderId = url.searchParams.get('order_id')
    const transactionId = url.searchParams.get('transaction_id')
    const msg = url.searchParams.get('msg')

    console.log('📋 Redirect parameters:', {
      status,
      statusId,
      billCode,
      orderId,
      transactionId,
      msg
    })

    // Extract planId from orderId (format: userId_planId)
    let planId = 'monthly_premium' // Default
    let userId = null

    if (orderId) {
      const parts = orderId.split('_')
      if (parts.length >= 2) {
        userId = parts[0]
        let extractedPlanId = parts.slice(1).join('_') // Handle case where planId contains underscores
        
        // Handle truncated plan IDs from ToyyibPay
        const planMapping = {
          'monthly_premi': 'monthly_premium',
          'monthly_prem': 'monthly_premium',
          'quarterly_pr': 'quarterly_premium',
          'quarterly_p': 'quarterly_premium',
          'semiannual_p': 'semiannual_premium',
          'semiannual': 'semiannual_premium',
          'annual_premi': 'annual_premium',
          'annual_prem': 'annual_premium'
        }
        
        planId = planMapping[extractedPlanId] || extractedPlanId || 'monthly_premium'
      }
    }

    console.log(`👤 Extracted - User ID: ${userId}, Plan ID: ${planId}`)

    // If payment successful and we have required data, activate immediately
    if (status?.toLowerCase() === 'success' && statusId === '1' && billCode && transactionId) {
      console.log('🎉 Payment successful! Activating subscription...')

      try {
        // Initialize Supabase client
        const supabaseUrl = Deno.env.get('SUPABASE_URL')!
        const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
        const supabase = createClient(supabaseUrl, supabaseKey)

        // Find user from pending payments if userId not found in orderId
        if (!userId) {
          console.log('🔍 Looking up user from pending payments...')
          const { data: pendingPayment } = await supabase
            .from('pending_payments')
            .select('user_id')
            .eq('bill_id', billCode)
            .single()

          if (pendingPayment) {
            userId = pendingPayment.user_id
            console.log(`👤 Found user ID: ${userId}`)
          }
        }

        if (userId) {
          // Get plan details
          const { data: planData } = await supabase
            .from('subscription_plans')
            .select('*')
            .eq('id', planId)
            .single()

          const now = new Date().toISOString()
          const durationDays = planData?.duration_days || 30
          const endDate = new Date(Date.now() + (durationDays * 24 * 60 * 60 * 1000)).toISOString()
          const amount = planData?.price || 6.90

          // Get user profile for name
          let userName = null
          try {
            const { data: profileData } = await supabase
              .from('profiles')
              .select('full_name')
              .eq('id', userId)
              .single()
            userName = profileData?.full_name
          } catch (e) {
            console.log('⚠️ Could not get user name:', e)
          }

          // 1. Activate subscription
          await supabase
            .from('user_subscriptions')
            .upsert({
              user_id: userId,
              user_name: userName,
              subscription_plan_id: planId,
              status: 'active',
              start_date: now,
              end_date: endDate,
              payment_id: transactionId,
              amount: amount,
              currency: 'MYR',
              updated_at: now
            })

          // 2. Update profile status
          await supabase
            .from('profiles')
            .update({
              subscription_status: 'active',
              updated_at: now
            })
            .eq('id', userId)

          // 3. Create payment record
          await supabase
            .from('payments')
            .insert({
              user_id: userId,
              payment_id: transactionId,
              reference_number: `${userId}_${planId}`,
              amount: amount,
              currency: 'MYR',
              status: 'completed',
              payment_method: 'toyyibpay_redirect',
              paid_at: now,
              metadata: {
                plan_id: planId,
                plan_name: planData?.name || planId,
                user_name: userName,
                bill_code: billCode,
                redirect_activation: true
              },
              created_at: now
            })

          // 4. Update pending payment status
          await supabase
            .from('pending_payments')
            .update({
              status: 'completed',
              updated_at: now
            })
            .eq('bill_id', billCode)

          console.log('🎉 Subscription activated successfully from redirect!')
        }

      } catch (error) {
        console.error('❌ Error processing payment redirect:', error)
      }
    }

    // Return HTML page with success message and auto redirect to app
    const htmlResponse = `
    <!DOCTYPE html>
    <html>
    <head>
        <title>Payment ${status === 'success' ? 'Successful' : 'Processing'}</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body { 
                font-family: Arial, sans-serif; 
                text-align: center; 
                padding: 40px;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                margin: 0;
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
            }
            .container {
                background: rgba(255,255,255,0.1);
                padding: 40px;
                border-radius: 20px;
                backdrop-filter: blur(10px);
                box-shadow: 0 8px 32px rgba(0,0,0,0.1);
                max-width: 400px;
            }
            .success { color: #4CAF50; }
            .pending { color: #FF9800; }
            .failed { color: #f44336; }
            .icon { font-size: 48px; margin-bottom: 20px; }
            h1 { margin-bottom: 10px; }
            .countdown { font-size: 18px; margin-top: 20px; }
        </style>
    </head>
    <body>
        <div class="container">
            ${status === 'success' 
                ? `<div class="success">
                     <div class="icon">🎉</div>
                     <h1>Payment Successful!</h1>
                     <p>Terima kasih! Langganan anda telah diaktifkan.</p>
                     <p><strong>Transaction ID:</strong> ${transactionId}</p>
                   </div>` 
                : `<div class="pending">
                     <div class="icon">⏳</div>
                     <h1>Payment Processing</h1>
                     <p>Pembayaran anda sedang diproses...</p>
                   </div>`
            }
            <div class="countdown">
                <p>Redirecting to app in <span id="countdown">3</span> seconds...</p>
            </div>
        </div>

        <script>
            let count = 3;
            const countdownEl = document.getElementById('countdown');
            
            const timer = setInterval(() => {
                count--;
                countdownEl.textContent = count;
                
                if (count <= 0) {
                    clearInterval(timer);
                    
                    // Try to redirect to app first
                    try {
                        window.location.href = 'ruwaqjawi://payment/success?status=${status}&billCode=${billCode}&transactionId=${transactionId}';
                    } catch (e) {
                        // Fallback: close window or redirect to a web URL
                        window.close();
                    }
                }
            }, 1000);
            
            // Also try immediate app redirect
            setTimeout(() => {
                try {
                    window.location.href = 'ruwaqjawi://payment/success?status=${status}&billCode=${billCode}&transactionId=${transactionId}';
                } catch (e) {
                    console.log('App redirect failed, will use countdown');
                }
            }, 500);
        </script>
    </body>
    </html>
    `

    return new Response(htmlResponse, {
      headers: { 
        ...corsHeaders, 
        'Content-Type': 'text/html; charset=utf-8' 
      }
    })

  } catch (error) {
    console.error('❌ Error in payment redirect:', error)
    
    return new Response('Internal server error', {
      status: 500,
      headers: corsHeaders
    })
  }
})

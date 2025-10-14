import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

console.log('🚀 Payment Verification Function started')

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { billId, userId, planId } = await req.json()

    console.log(`🔍 Verifying payment - Bill ID: ${billId}, User: ${userId}, Plan: ${planId}`)

    if (!billId || !userId || !planId) {
      console.log('❌ Missing required parameters')
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: 'Missing required parameters: billId, userId, planId' 
        }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Get ToyyibPay credentials from environment
    const toyyibPaySecretKey = Deno.env.get('TOYYIBPAY_SECRET_KEY')
    if (!toyyibPaySecretKey) {
      console.log('❌ ToyyibPay Secret Key not configured')
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: 'ToyyibPay credentials not configured' 
        }),
        { 
          status: 500, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Check payment status dari ToyyibPay
    console.log('🔍 Checking ToyyibPay API...')
    const toyyibPayResponse = await fetch('https://dev.toyyibpay.com/index.php/api/getBillTransactions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        userSecretKey: toyyibPaySecretKey,
        billId: billId
      })
    })

    if (!toyyibPayResponse.ok) {
      console.log(`❌ ToyyibPay API Error: ${toyyibPayResponse.status}`)
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: `ToyyibPay API error: ${toyyibPayResponse.status}` 
        }),
        { 
          status: 500, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    const paymentData = await toyyibPayResponse.json()
    console.log('📄 ToyyibPay Response:', paymentData)

    // Parse payment status
    let paymentStatus = 'pending'
    let transactionId = billId
    let paidAmount = 0

    if (Array.isArray(paymentData) && paymentData.length > 0) {
      const transaction = paymentData[0]
      paymentStatus = transaction.billpaymentStatus // 1 = Success, 0 = Pending, 3 = Failed
      transactionId = transaction.billpaymentInvoiceNo || billId
      paidAmount = parseFloat(transaction.billpaidAmount || transaction.billAmount || '0')
    }

    console.log(`📊 Payment Status: ${paymentStatus}`)

    // Jika payment successful (status = 1), activate subscription
    if (paymentStatus === '1' || paymentStatus === 1) {
      console.log('💰 Payment successful! Activating subscription...')

      // Get plan details
      const { data: plan, error: planError } = await supabaseClient
        .from('subscription_plans')
        .select('duration_days, name, price')
        .eq('id', planId)
        .maybeSingle()

      if (planError || !plan) {
        console.log('❌ Plan not found:', planError)
        return new Response(
          JSON.stringify({ 
            success: false, 
            error: 'Subscription plan not found' 
          }),
          { 
            status: 400, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        )
      }

      // Get user profile
      const { data: profile } = await supabaseClient
        .from('profiles')
        .select('full_name')
        .eq('id', userId)
        .maybeSingle()

      const now = new Date().toISOString()
      const endDate = new Date()
      endDate.setDate(endDate.getDate() + (plan.duration_days || 30))

      // 1. Update user_subscriptions
      console.log('📝 Updating user_subscriptions...')
      const { error: subscriptionError } = await supabaseClient
        .from('user_subscriptions')
        .upsert({
          user_id: userId,
          user_name: profile?.full_name,
          subscription_plan_id: planId,
          status: 'active',
          start_date: now,
          end_date: endDate.toISOString(),
          payment_id: transactionId,
          amount: paidAmount,
          currency: 'MYR',
          updated_at: now
        })

      if (subscriptionError) {
        console.log('❌ Error updating subscription:', subscriptionError)
        return new Response(
          JSON.stringify({ 
            success: false, 
            error: 'Failed to activate subscription' 
          }),
          { 
            status: 500, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        )
      }

      // 2. Update profile status
      console.log('👤 Updating profile status...')
      const { error: profileError } = await supabaseClient
        .from('profiles')
        .update({
          subscription_status: 'active',
          updated_at: now,
        })
        .eq('id', userId)

      if (profileError) {
        console.log('❌ Error updating profile:', profileError)
      }

      // 3. Create payment record
      console.log('💳 Creating payment record...')
      const { error: paymentError } = await supabaseClient
        .from('payments')
        .insert({
          user_id: userId,
          payment_id: transactionId,
          reference_number: `${userId}_${planId}`,
          amount: paidAmount,
          currency: 'MYR',
          status: 'completed',
          payment_method: 'toyyibpay',
          paid_at: now,
          metadata: {
            plan_id: planId,
            plan_name: plan.name,
            user_name: profile?.full_name,
            bill_id: billId
          },
          created_at: now
        })

      if (paymentError) {
        console.log('❌ Error creating payment record:', paymentError)
      }

      // 4. Update payment status in payments table (single source of truth)
      await supabaseClient
        .from('payments')
        .update({
          status: 'completed',
          updated_at: now,
          completed_at: now,
        })
        .eq('bill_id', billId)

      console.log('🎉 Subscription activated successfully!')

      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'Payment verified and subscription activated',
          subscription: {
            status: 'active',
            start_date: now,
            end_date: endDate.toISOString(),
            plan_name: plan.name
          }
        }),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )

    } else if (paymentStatus === '3' || paymentStatus === 3) {
      console.log('❌ Payment failed')
      
      // Update payment status to failed in payments table
      await supabaseClient
        .from('payments')
        .update({
          status: 'failed',
          updated_at: new Date().toISOString(),
        })
        .eq('bill_id', billId)

      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Payment failed',
          paymentStatus: 'failed'
        }),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )

    } else {
      console.log('⏳ Payment still pending')
      
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Payment still pending',
          paymentStatus: 'pending'
        }),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

  } catch (error) {
    console.error('💥 Function error:', error)
    
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message 
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})

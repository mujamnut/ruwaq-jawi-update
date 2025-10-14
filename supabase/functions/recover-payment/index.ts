import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('🔄 Payment recovery function started')

    const { billId } = await req.json()

    if (!billId) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Missing billId parameter'
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    console.log(`🔍 Recovering payment: ${billId}`)

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Step 1: Find the payment record
    const { data: payment, error: paymentError } = await supabase
      .from('payments')
      .select('*')
      .eq('bill_id', billId)
      .single()

    if (paymentError || !payment) {
      console.error('❌ Payment not found:', paymentError)
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Payment not found'
        }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    console.log('📋 Found payment:', {
      id: payment.id,
      user_id: payment.user_id,
      plan_id: payment.plan_id,
      amount: payment.amount_cents / 100,
      status: payment.status,
      provider_payment_id: payment.provider_payment_id
    })

    // Step 2: Check ToyyibPay API status
    const toyyibPaySecretKey = Deno.env.get('TOYYIBPAY_SECRET_KEY')
    if (!toyyibPaySecretKey) {
      console.error('❌ ToyyibPay Secret Key not configured')
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
      console.error(`❌ ToyyibPay API Error: ${toyyibPayResponse.status}`)
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

    // Step 3: Parse payment status
    let toyyibPayStatus = 'unknown'
    let transactionId = billId
    let paidAmount = 0

    if (Array.isArray(paymentData) && paymentData.length > 0) {
      const transaction = paymentData[0]
      toyyibPayStatus = transaction.billpaymentStatus // 1 = Success, 0 = Pending, 3 = Failed
      transactionId = transaction.billpaymentInvoiceNo || billId
      paidAmount = parseFloat(transaction.billpaidAmount || transaction.billAmount || '0')
    }

    console.log(`📊 ToyyibPay Status: ${toyyibPayStatus} (${toyyibPayStatus === '1' ? 'Success' : toyyibPayStatus === '3' ? 'Failed' : 'Pending'})`)

    // Step 4: If payment is successful in ToyyibPay, update our records
    if (toyyibPayStatus === '1' || toyyibPayStatus === 1) {
      console.log('💰 Payment successful in ToyyibPay! Updating records...')

      const now = new Date().toISOString()

      // Update payment status to completed
      const { error: updateError } = await supabase
        .from('payments')
        .update({
          status: 'completed',
          paid_at: now,
          updated_at: now,
          receipt_url: `https://dev.toyyibpay.com/bill/${billId}`,
          raw_payload: {
            ...payment.raw_payload,
            toyyibpay_verification: paymentData,
            recovered_at: now,
            recovery_transaction_id: transactionId
          }
        })
        .eq('id', payment.id)

      if (updateError) {
        console.error('❌ Error updating payment:', updateError)
        return new Response(
          JSON.stringify({
            success: false,
            error: 'Failed to update payment status'
          }),
          {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }

      console.log('✅ Payment updated to completed')

      // Get plan details for subscription
      const { data: plan, error: planError } = await supabase
        .from('subscription_plans')
        .select('duration_days, name, price')
        .eq('id', payment.plan_id)
        .maybeSingle()

      if (planError || !plan) {
        console.error('❌ Plan not found:', planError)
        // Still return success for payment update, but note plan issue
        return new Response(
          JSON.stringify({
            success: true,
            message: 'Payment recovered but plan not found for subscription activation',
            payment: {
              status: 'completed',
              amount: paidAmount,
              transaction_id: transactionId
            }
          }),
          {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }

      // Get user profile
      const { data: profile } = await supabase
        .from('profiles')
        .select('full_name')
        .eq('id', payment.user_id)
        .maybeSingle()

      // Calculate subscription dates
      const startDate = new Date()
      const endDate = new Date()
      endDate.setDate(endDate.getDate() + (plan.duration_days || 30))

      // Create/update subscription
      const { error: subscriptionError } = await supabase
        .from('user_subscriptions')
        .upsert({
          user_id: payment.user_id,
          user_name: profile?.full_name || 'App User',
          subscription_plan_id: payment.plan_id,
          status: 'active',
          start_date: now,
          end_date: endDate.toISOString(),
          payment_id: transactionId,
          amount: paidAmount,
          currency: 'MYR',
          updated_at: now
        })

      if (subscriptionError) {
        console.error('❌ Error creating subscription:', subscriptionError)
      } else {
        console.log('✅ Subscription activated successfully')
      }

      // Update user profile
      const { error: profileUpdateError } = await supabase
        .from('profiles')
        .update({
          subscription_status: 'active',
          updated_at: now,
        })
        .eq('id', payment.user_id)

      if (profileUpdateError) {
        console.error('❌ Error updating profile:', profileUpdateError)
      } else {
        console.log('✅ Profile updated successfully')
      }

      console.log('🎉 Payment recovery completed successfully!')

      return new Response(
        JSON.stringify({
          success: true,
          message: 'Payment recovered and subscription activated',
          payment: {
            bill_id: billId,
            status: 'completed',
            amount: paidAmount,
            transaction_id: transactionId,
            subscription: {
              status: 'active',
              plan_id: payment.plan_id,
              plan_name: plan.name,
              end_date: endDate.toISOString()
            }
          }
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )

    } else if (toyyibPayStatus === '3' || toyyibPayStatus === 3) {
      // Payment failed in ToyyibPay
      console.log('❌ Payment failed in ToyyibPay')

      const { error: updateError } = await supabase
        .from('payments')
        .update({
          status: 'failed',
          updated_at: new Date().toISOString(),
          raw_payload: {
            ...payment.raw_payload,
            toyyibpay_verification: paymentData,
            failed_at: new Date().toISOString()
          }
        })
        .eq('id', payment.id)

      return new Response(
        JSON.stringify({
          success: false,
          message: 'Payment failed in ToyyibPay',
          toyyibPayStatus: 'failed'
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )

    } else {
      // Payment still pending in ToyyibPay
      console.log('⏳ Payment still pending in ToyyibPay')

      return new Response(
        JSON.stringify({
          success: false,
          message: 'Payment still pending in ToyyibPay',
          toyyibPayStatus: 'pending',
          current_status: payment.status
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

  } catch (error) {
    console.error('💥 Recovery function error:', error)

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
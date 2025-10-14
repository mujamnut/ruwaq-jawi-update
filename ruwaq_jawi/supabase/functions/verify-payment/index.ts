import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface PaymentVerificationRequest {
  billId: string;
  userId: string;
  planId: string;
}

interface ToyyibPayTransaction {
  billId: string;
  billpaymentStatus: string;
  billAmount: string;
  billpaymentDate?: string;
  billpaymentInvoiceNo?: string;
  billpaidAmount?: string;
}

interface VerificationResult {
  success: boolean;
  message: string;
  transactionData?: any;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('🔍 Starting payment verification...')
    
    // Parse request body
    const { billId, userId, planId }: PaymentVerificationRequest = await req.json()
    
    console.log(`📋 Verifying payment - Bill ID: ${billId}, User ID: ${userId}, Plan ID: ${planId}`)

    // Validate required fields
    if (!billId || !userId || !planId) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: 'Missing required fields: billId, userId, planId' 
        }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Get ToyyibPay credentials
    const toyyibPaySecretKey = Deno.env.get('TOYYIBPAY_SECRET_KEY')
    if (!toyyibPaySecretKey) {
      console.error('❌ TOYYIBPAY_SECRET_KEY not configured in environment')
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

    console.log(`🔑 Using ToyyibPay Secret Key: ${toyyibPaySecretKey.substring(0, 10)}...`)

    // Call ToyyibPay API to verify payment status
    const toyyibPayUrl = 'https://dev.toyyibpay.com/index.php/api/getBillTransactions'
    const toyyibPayRequest = {
      userSecretKey: toyyibPaySecretKey,
      billId: billId
    }

    console.log('📤 Calling ToyyibPay API...', { url: toyyibPayUrl, billId })

    const toyyibResponse = await fetch(toyyibPayUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(toyyibPayRequest)
    })

    console.log(`📥 ToyyibPay response status: ${toyyibResponse.status}`)

    if (!toyyibResponse.ok) {
      const errorText = await toyyibResponse.text()
      console.error(`❌ ToyyibPay API error: ${toyyibResponse.status} - ${errorText}`)
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: `ToyyibPay API error: ${toyyibResponse.status}`,
          error: errorText
        }),
        { 
          status: 500, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    let toyyibData
    try {
      toyyibData = await toyyibResponse.json()
      console.log('📄 ToyyibPay JSON response:', JSON.stringify(toyyibData))
    } catch (jsonError) {
      console.log('⚠️ Failed to parse JSON, trying as text...', jsonError.message)
      const textResponse = await toyyibResponse.text()
      console.log('📄 ToyyibPay text response:', textResponse)
      
      // Check if response contains HTML or other non-JSON format
      if (textResponse.includes('[BILL-CODE-') || textResponse.includes('<html')) {
        console.log('❌ ToyyibPay returned HTML/error page instead of JSON')
        return new Response(
          JSON.stringify({ 
            success: false, 
            message: 'ToyyibPay API returned invalid response format',
            error: 'Expected JSON but got: ' + textResponse.substring(0, 200)
          }),
          { 
            status: 500, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }
      
      // Try to parse as form data if it looks like that
      try {
        const params = new URLSearchParams(textResponse)
        toyyibData = Object.fromEntries(params.entries())
        console.log('📄 Parsed as form data:', toyyibData)
      } catch (formError) {
        console.error('❌ Could not parse response as JSON or form data:', formError)
        return new Response(
          JSON.stringify({ 
            success: false, 
            message: 'Invalid response format from ToyyibPay',
            error: textResponse.substring(0, 200)
          }),
          { 
            status: 500, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }
    }

    // Parse ToyyibPay response
    if (!Array.isArray(toyyibData) || toyyibData.length === 0) {
      console.log('⏳ No transactions found for bill ID')
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'No transactions found for this bill' 
        }),
        { 
          status: 200, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const transaction: ToyyibPayTransaction = toyyibData[0]
    const paymentStatus = transaction.billpaymentStatus?.toString()
    const amount = parseFloat(transaction.billpaidAmount || transaction.billAmount || '0')

    console.log(`💰 Payment status: ${paymentStatus}, Amount: ${amount}`)

    // Check if payment is successful (status = 1)
    if (paymentStatus === '1') {
      console.log('🎉 Payment successful! Activating subscription...')

      // Get plan details
      const { data: planData, error: planError } = await supabase
        .from('subscription_plans')
        .select('*')
        .eq('id', planId)
        .single()

      if (planError) {
        console.error('❌ Error fetching plan:', planError)
        return new Response(
          JSON.stringify({ 
            success: false, 
            error: 'Plan not found' 
          }),
          { 
            status: 404, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }

      const now = new Date().toISOString()
      const durationDays = planData.duration_days || 30
      const endDate = new Date(Date.now() + (durationDays * 24 * 60 * 60 * 1000)).toISOString()

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

      // 1. Check if payment already processed to prevent duplicates
      const { data: existingPayment, error: paymentCheckError } = await supabase
        .from('user_subscriptions')
        .select('id, status')
        .eq('payment_id', transaction.billpaymentInvoiceNo || billId)
        .maybeSingle()

      if (existingPayment) {
        console.log('⚠️ Payment already processed, skipping duplicate activation')
        return new Response(
          JSON.stringify({
            success: true,
            message: 'Payment already processed and subscription activated',
            alreadyProcessed: true
          }),
          {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }

      // 2. Handle smart subscription logic
      console.log('🧠 Using smart subscription logic...')

      // Get recommendation for this purchase
      const { data: recommendation, error: recommendationError } = await supabase
        .rpc('get_subscription_recommendation', {
          user_id_param: userId,
          target_plan_id: planId
        })

      if (recommendationError) {
        console.error('❌ Error getting recommendation:', recommendationError)
        // Fallback to old logic if recommendation fails
        console.log('⚠️ Falling back to simple activation logic')
      } else {
        console.log('📋 Subscription recommendation:', recommendation[0])
        const rec = recommendation[0]

        if (rec.action_type !== 'new') {
          console.log(`🔄 Handling ${rec.action_type}: ${rec.recommendation}`)
        }
      }

      // 3. Use smart subscription handler
      const { data: subscriptionResult, error: smartSubscriptionError } = await supabase
        .rpc('handle_smart_subscription_purchase', {
          user_id: userId,
          new_plan_id: planId,
          payment_id: transaction.billpaymentInvoiceNo || billId,
          payment_amount: amount,
          payment_data: {
            transaction: transaction,
            plan_name: planData.name,
            user_name: userName,
            activated_at: now
          }
        })

      let subscriptionError = smartSubscriptionError

      if (subscriptionError) {
        console.error('❌ Error updating subscription:', subscriptionError)
        return new Response(
          JSON.stringify({ 
            success: false, 
            error: 'Failed to update subscription' 
          }),
          { 
            status: 500, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }

      // 2. Update profile subscription status
      const { error: profileError } = await supabase
        .from('profiles')
        .update({
          subscription_status: 'active',
          updated_at: now
        })
        .eq('id', userId)

      if (profileError) {
        console.error('❌ Error updating profile:', profileError)
      }

      // 3. Create payment record
      const { error: paymentError } = await supabase
        .from('payments')
        .insert({
          user_id: userId,
          payment_id: transaction.billpaymentInvoiceNo || billId,
          reference_number: `${userId}_${planId}`,
          amount: amount,
          currency: 'MYR',
          status: 'completed',
          payment_method: 'toyyibpay',
          paid_at: transaction.billpaymentDate || now,
          metadata: {
            plan_id: planId,
            plan_name: planData.name,
            user_name: userName,
            toyyib_transaction: transaction
          },
          created_at: now
        })

      if (paymentError) {
        console.error('❌ Error creating payment record:', paymentError)
        // Don't fail - subscription is already activated
      }

      // 4. Update pending payment status
      const { error: pendingError } = await supabase
        .from('pending_payments')
        .update({
          status: 'completed',
          updated_at: now
        })
        .eq('bill_id', billId)
        .eq('user_id', userId)

      if (pendingError) {
        console.log('⚠️ Could not update pending payment:', pendingError)
      }

      console.log('✅ Subscription activated successfully!')

      // Create response with smart logic info
      const responseData = {
        success: true,
        message: 'Payment verified and subscription activated!',
        transactionData: {
          transactionId: transaction.billpaymentInvoiceNo,
          amount: amount,
          status: paymentStatus,
          activatedAt: now
        }
      }

      // Add smart subscription info if available
      if (subscriptionResult && subscriptionResult[0]) {
        const subResult = subscriptionResult[0]
        responseData.subscriptionInfo = {
          actionTaken: subResult.action_taken,
          daysAdded: subResult.days_added,
          previousSubscriptionId: subResult.previous_subscription_id,
          newSubscriptionId: subResult.new_subscription_id
        }

        if (recommendation && recommendation[0]) {
          const rec = recommendation[0]
          responseData.recommendation = {
            actionType: rec.action_type,
            proratedDays: rec.prorated_days,
            proratedValue: rec.prorated_value,
            additionalCost: rec.additional_cost,
            refundAmount: rec.refund_amount,
            recommendation: rec.recommendation
          }
        }

        // Customize message based on action
        if (subResult.action_taken === 'extension') {
          responseData.message = `Subscription extended! ${subResult.days_added} days added (${rec.prorated_days} days prorated)`
        } else if (subResult.action_taken === 'upgrade') {
          responseData.message = `Subscription upgraded! ${subResult.days_added} days total (${rec.prorated_days} days credit applied)`
        } else if (subResult.action_taken === 'downgrade') {
          responseData.message = `Subscription changed! ${rec.refund_amount > 0 ? `RM${rec.refund_amount} credit applied` : 'Switched to economical plan'}`
        }
      }

      return new Response(
        JSON.stringify(responseData),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )

    } else if (paymentStatus === '3') {
      console.log('❌ Payment failed')
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Payment failed' 
        }),
        { 
          status: 200, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )

    } else {
      console.log(`⏳ Payment still pending (status: ${paymentStatus})`)
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: `Payment still pending (status: ${paymentStatus})` 
        }),
        { 
          status: 200, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

  } catch (error) {
    console.error('❌ Error in verify-payment function:', error)
    
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message || 'Internal server error' 
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})

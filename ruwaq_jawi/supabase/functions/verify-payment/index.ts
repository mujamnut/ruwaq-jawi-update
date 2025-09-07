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

      // 1. Activate subscription in user_subscriptions table
      const { error: subscriptionError } = await supabase
        .from('user_subscriptions')
        .upsert({
          user_id: userId,
          user_name: userName,
          subscription_plan_id: planId,
          status: 'active',
          start_date: now,
          end_date: endDate,
          payment_id: transaction.billpaymentInvoiceNo || billId,
          amount: amount,
          currency: 'MYR',
          updated_at: now
        })

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

      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'Payment verified and subscription activated!',
          transactionData: {
            transactionId: transaction.billpaymentInvoiceNo,
            amount: amount,
            status: paymentStatus,
            activatedAt: now
          }
        }),
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

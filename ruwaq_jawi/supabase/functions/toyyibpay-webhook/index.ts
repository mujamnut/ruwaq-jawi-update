import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface ToyyibPayCallback {
  billcode?: string;
  order_id?: string;
  status?: string;
  status_id?: string;
  msg?: string;
  transaction_id?: string;
  amount?: string;
  [key: string]: any;
}

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
    console.log(`🔄 Processing ToyyibPay callback - Method: ${req.method}`)
    console.log(`🔄 Content-Type: ${req.headers.get('content-type')}`)

    let callbackData: ToyyibPayCallback = {}

    // Parse request based on content type and method
    const contentType = req.headers.get('content-type') || ''
    
    if (req.method === 'POST') {
      if (contentType.includes('application/json')) {
        try {
          callbackData = await req.json()
          console.log('📥 Parsed JSON payload:', callbackData)
        } catch (jsonError) {
          console.log('⚠️ JSON parsing failed, trying form data...')
          
          // Try to parse as form data
          try {
            const body = await req.text()
            console.log('📥 Raw body:', body)
            
            const params = new URLSearchParams(body)
            callbackData = Object.fromEntries(params.entries())
            console.log('📥 Parsed form data:', callbackData)
          } catch (formError) {
            console.error('❌ Failed to parse form data:', formError)
            return new Response('Bad Request - Invalid payload format', { 
              status: 400, 
              headers: corsHeaders 
            })
          }
        }
      } else if (contentType.includes('application/x-www-form-urlencoded')) {
        const body = await req.text()
        console.log('📥 Raw form body:', body)
        
        const params = new URLSearchParams(body)
        callbackData = Object.fromEntries(params.entries())
        console.log('📥 Parsed form data:', callbackData)
      } else {
        // Try to parse as text and then as form data
        const body = await req.text()
        console.log('📥 Unknown content type, raw body:', body)
        
        try {
          const params = new URLSearchParams(body)
          callbackData = Object.fromEntries(params.entries())
          console.log('📥 Parsed as form data:', callbackData)
        } catch (e) {
          console.error('❌ Could not parse body:', e)
          return new Response('Bad Request - Could not parse payload', { 
            status: 400, 
            headers: corsHeaders 
          })
        }
      }
    } else if (req.method === 'GET') {
      // Parse query parameters for GET requests
      const url = new URL(req.url)
      callbackData = Object.fromEntries(url.searchParams.entries())
      console.log('📥 Parsed GET parameters:', callbackData)
    }

    // Extract key fields
    const billCode = callbackData.billcode || callbackData.bill_code
    const orderId = callbackData.order_id
    const status = callbackData.status
    const statusId = callbackData.status_id
    const transactionId = callbackData.transaction_id
    const amount = callbackData.amount

    console.log('📋 Extracted callback data:', {
      billCode,
      orderId,
      status,
      statusId,
      transactionId,
      amount
    })

    // Validate required fields
    if (!billCode) {
      console.error('❌ Missing bill code in callback')
      return new Response('Bad Request - Missing bill code', { 
        status: 400, 
        headers: corsHeaders 
      })
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Store webhook event for audit
    const { error: webhookError } = await supabase
      .from('webhook_events')
      .insert({
        provider: 'toyyibpay',
        event_type: 'payment_callback',
        bill_code: billCode,
        transaction_id: transactionId,
        status: status,
        status_id: statusId,
        raw_payload: callbackData,
        received_at: new Date().toISOString()
      })

    if (webhookError) {
      console.error('❌ Error storing webhook event:', webhookError)
    }

    // If payment is successful, activate subscription immediately
    if (status?.toLowerCase() === 'success' && statusId === '1') {
      console.log('🎉 Payment successful from callback! Processing...')

      try {
        // Find pending payment to get user and plan info
        const { data: pendingPayment, error: pendingError } = await supabase
          .from('pending_payments')
          .select('user_id, plan_id, amount')
          .eq('bill_id', billCode)
          .eq('status', 'pending')
          .single()

        if (pendingError || !pendingPayment) {
          console.log('⚠️ No pending payment found for bill code:', billCode)
          return new Response('Payment processed but no pending record found', {
            status: 200,
            headers: corsHeaders
          })
        }

        const userId = pendingPayment.user_id
        const planId = pendingPayment.plan_id
        const paymentAmount = parseFloat(amount || pendingPayment.amount.toString())

        console.log(`🔍 Found pending payment - User: ${userId}, Plan: ${planId}`)

        // Get plan details
        const { data: planData, error: planError } = await supabase
          .from('subscription_plans')
          .select('*')
          .eq('id', planId)
          .single()

        if (planError) {
          console.error('❌ Error fetching plan:', planError)
          throw new Error('Plan not found')
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

        // 1. Activate subscription
        const { error: subscriptionError } = await supabase
          .from('user_subscriptions')
          .upsert({
            user_id: userId,
            user_name: userName,
            subscription_plan_id: planId,
            status: 'active',
            start_date: now,
            end_date: endDate,
            payment_id: transactionId || billCode,
            amount: paymentAmount,
            currency: 'MYR',
            updated_at: now
          })

        if (subscriptionError) {
          console.error('❌ Error activating subscription:', subscriptionError)
          throw subscriptionError
        }

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
            payment_id: transactionId || billCode,
            reference_number: `${userId}_${planId}`,
            amount: paymentAmount,
            currency: 'MYR',
            status: 'completed',
            payment_method: 'toyyibpay',
            paid_at: now,
            metadata: {
              plan_id: planId,
              plan_name: planData.name,
              user_name: userName,
              callback_data: callbackData
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
          .eq('user_id', userId)

        console.log('✅ Subscription activated successfully from callback!')

        return new Response('Payment processed and subscription activated', {
          status: 200,
          headers: corsHeaders
        })

      } catch (error) {
        console.error('❌ Error processing successful payment:', error)
        
        return new Response('Error processing payment', {
          status: 500,
          headers: corsHeaders
        })
      }

    } else if (statusId === '3' || status?.toLowerCase() === 'failed') {
      console.log('❌ Payment failed from callback')
      
      // Update pending payment status to failed
      await supabase
        .from('pending_payments')
        .update({
          status: 'failed',
          updated_at: new Date().toISOString()
        })
        .eq('bill_id', billCode)

      return new Response('Payment failed', {
        status: 200,
        headers: corsHeaders
      })

    } else {
      console.log(`⏳ Payment still pending (status: ${status}, statusId: ${statusId})`)
      
      return new Response('Payment pending', {
        status: 200,
        headers: corsHeaders
      })
    }

  } catch (error) {
    console.error('❌ Error in ToyyibPay webhook:', error)
    
    return new Response('Internal server error', {
      status: 500,
      headers: corsHeaders
    })
  }
})

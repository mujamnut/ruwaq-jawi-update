import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface DirectActivationRequest {
  billId: string;
  userId: string;
  planId: string;
  transactionId: string;
  amount: number;
  reason: string; // Why direct activation is needed
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
    console.log('🔧 Starting direct payment activation...')
    
    // Parse request body
    const { billId, userId, planId, transactionId, amount, reason }: DirectActivationRequest = await req.json()
    
    console.log(`📋 Direct activation - Bill ID: ${billId}, User ID: ${userId}, Plan ID: ${planId}`)
    console.log(`💡 Reason: ${reason}`)

    // Validate required fields
    if (!billId || !userId || !planId || !transactionId || !amount) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: 'Missing required fields: billId, userId, planId, transactionId, amount' 
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

    console.log('🎉 Proceeding with direct activation...')

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
        payment_id: transactionId,
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
        payment_id: transactionId,
        reference_number: `${userId}_${planId}`,
        amount: amount,
        currency: 'MYR',
        status: 'completed',
        payment_method: 'toyyibpay_direct',
        paid_at: now,
        metadata: {
          plan_id: planId,
          plan_name: planData.name,
          user_name: userName,
          activation_reason: reason,
          bill_id: billId,
          direct_activation: true
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

    // 5. Log direct activation for audit
    const { error: auditError } = await supabase
      .from('direct_activations')
      .insert({
        user_id: userId,
        bill_id: billId,
        transaction_id: transactionId,
        plan_id: planId,
        amount: amount,
        reason: reason,
        activated_at: now
      })

    if (auditError) {
      console.log('⚠️ Could not log audit record:', auditError)
    }

    console.log('✅ Direct subscription activation completed successfully!')

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Subscription activated directly!',
        activationData: {
          transactionId: transactionId,
          amount: amount,
          reason: reason,
          activatedAt: now,
          endDate: endDate
        }
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('❌ Error in direct activation function:', error)
    
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

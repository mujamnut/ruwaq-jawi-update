// @ts-nocheck
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};

Deno.serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const formData = await req.formData();
    const status = formData.get('status');
    const billCode = formData.get('billcode');
    const orderId = formData.get('order_id');
    const msg = formData.get('msg');
    const paymentAmount = formData.get('amount');

    console.log(`🔔 Webhook received: status=${status}, billCode=${billCode}, orderId=${orderId}`);

    // Parse metadata from order_id (format: userId_planId)
    const [userId, planId] = orderId?.split('_') || [];
    
    if (!userId || !planId) {
      console.error('❌ Invalid order_id format');
      return new Response(
        JSON.stringify({ error: 'Invalid order_id format' }),
        { 
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    // Log webhook event first
    await logWebhookEvent(supabaseClient, {
      provider: 'toyyibpay',
      event_type: 'payment_status_update',
      payload: { status, billCode, orderId, msg, paymentAmount },
      status: status === '1' ? 'success' : 'failed',
      reference_number: orderId
    });

    // Handle payment status
    if (status === '1') {
      console.log(`💰 Processing successful payment for user: ${userId}, plan: ${planId}`);
      
      try {
        const now = new Date();
        
        // Get plan details from subscription_plans table
        const { data: plan, error: planError } = await supabaseClient
          .from('subscription_plans')
          .select('duration_days, name')
          .eq('id', planId)
          .maybeSingle();
        
        if (planError) {
          console.error('❌ Error fetching plan:', planError);
          throw planError;
        }
        
        const durationDays = plan?.duration_days ?? 30;
        const planName = plan?.name ?? 'Premium Plan';
        const endDate = new Date(now);
        endDate.setDate(endDate.getDate() + durationDays);
        
        console.log(`📅 Subscription duration: ${durationDays} days, end_date: ${endDate.toISOString()}`);

        // Get user's full name for records
        const { data: profile, error: profileError } = await supabaseClient
          .from('profiles')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();

        if (profileError) {
          console.warn('⚠️ Could not fetch user profile:', profileError);
        }

        const userName = profile?.full_name ?? null;
        const planType = mapPlanIdToType(planId);

        // **STEP 1: Update user_subscriptions table (NEW SYSTEM - for edge functions)**
        console.log(`📝 Updating user_subscriptions table...`);
        const { error: newSubError } = await supabaseClient
          .from('user_subscriptions')
          .upsert({
            user_id: userId,
            user_name: userName,
            subscription_plan_id: planId,
            status: 'active',
            start_date: now.toISOString(),
            end_date: endDate.toISOString(),
            payment_id: billCode,
            amount: parseFloat(paymentAmount),
            currency: 'MYR',
            updated_at: now.toISOString()
          });

        if (newSubError) {
          console.error('❌ Error updating user_subscriptions:', newSubError);
          throw newSubError;
        }
        console.log('✅ user_subscriptions table updated');

        // **STEP 2: Update subscriptions table (OLD SYSTEM - for client compatibility)**
        console.log(`📝 Updating subscriptions table...`);
        
        // First deactivate existing subscriptions
        await supabaseClient
          .from('subscriptions')
          .update({ status: 'replaced' })
          .eq('user_id', userId)
          .eq('status', 'active');

        // Create new subscription record
        const { error: oldSubError } = await supabaseClient
          .from('subscriptions')
          .insert({
            user_id: userId,
            plan_type: planType,
            start_date: now.toISOString(),
            end_date: endDate.toISOString(),
            status: 'active',
            payment_method: 'toyyibpay',
            amount: parseFloat(paymentAmount),
            currency: 'MYR',
            auto_renew: false
          });

        if (oldSubError) {
          console.error('❌ Error updating subscriptions:', oldSubError);
          throw oldSubError;
        }
        console.log('✅ subscriptions table updated');

        // **STEP 3: Update profile subscription status**
        console.log(`👤 Updating profile subscription_status...`);
        const { error: profileUpdateError } = await supabaseClient
          .from('profiles')
          .update({
            subscription_status: 'active',
            updated_at: now.toISOString()
          })
          .eq('id', userId);

        if (profileUpdateError) {
          console.error('❌ Error updating profile:', profileUpdateError);
          throw profileUpdateError;
        }
        console.log('✅ Profile subscription_status updated to active');

        // **STEP 4: Create payment record**
        console.log(`💳 Creating payment record...`);
        const { error: paymentError } = await supabaseClient
          .from('payments')
          .insert({
            user_id: userId,
            payment_id: billCode,
            reference_number: orderId,
            amount: parseFloat(paymentAmount),
            currency: 'MYR',
            status: 'completed',
            payment_method: 'toyyibpay',
            paid_at: now.toISOString(),
            metadata: {
              billCode,
              orderId,
              msg,
              planName,
              planId
            },
            created_at: now.toISOString()
          });

        if (paymentError) {
          console.error('❌ Error creating payment record:', paymentError);
          // Don't throw here, payment processing is complete
        } else {
          console.log('✅ Payment record created');
        }

        // **STEP 5: Verify the updates worked**
        const { data: verifyProfile, error: verifyError } = await supabaseClient
          .from('profiles')
          .select('subscription_status, updated_at')
          .eq('id', userId)
          .maybeSingle();

        if (verifyError) {
          console.error('❌ Error verifying profile update:', verifyError);
        } else {
          console.log('✅ Profile verification:', verifyProfile);
        }

        const { data: verifyNewSub } = await supabaseClient
          .from('user_subscriptions')
          .select('status, end_date')
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle();

        console.log('✅ New subscription verification:', verifyNewSub);

        console.log(`🎉 Successfully activated subscription for user ${userId}!`);

      } catch (error) {
        console.error('💥 Error processing successful payment:', error);
        return new Response(
          JSON.stringify({ error: 'Payment processing failed' }),
          { 
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        );
      }
    } else {
      console.log(`❌ Payment failed or pending: status=${status}`);
    }

    return new Response(
      JSON.stringify({ success: true, message: 'Webhook processed' }),
      { 
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );

  } catch (error) {
    console.error('💥 Error processing webhook:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );
  }
});

async function logWebhookEvent(supabaseClient: any, eventData: any) {
  try {
    const { error } = await supabaseClient
      .from('webhook_logs')
      .insert({
        provider: eventData.provider,
        event_type: eventData.event_type,
        payload: eventData.payload,
        status: eventData.status,
        reference_number: eventData.reference_number,
        created_at: new Date().toISOString()
      });

    if (error) {
      console.error('Error logging webhook event:', error);
    } else {
      console.log('📋 Webhook event logged');
    }
  } catch (error) {
    console.error('Error in logWebhookEvent:', error);
  }
}

function mapPlanIdToType(planId: string): string {
  switch (planId.toLowerCase()) {
    case 'monthly_basic':
    case 'monthly_premium':
      return '1month';
    case 'quarterly_premium':
      return '3month';
    case 'semiannual_premium':
      return '6month';
    case 'yearly_premium':
      return '12month';
    default:
      return '1month';
  }
}

/*
DEPLOYMENT INSTRUCTIONS:

1. Deploy this to your Supabase Edge Functions:
   supabase functions deploy payment-webhook --project-ref YOUR_PROJECT_REF

2. Set environment variables:
   - SUPABASE_URL
   - SUPABASE_SERVICE_ROLE_KEY

3. Update your ToyyibPay webhook URL to point to:
   https://YOUR_PROJECT_REF.functions.supabase.co/payment-webhook

4. Test the webhook with a small payment to verify all tables update correctly.

DEBUGGING:
- Check webhook_logs table for webhook reception
- Check payments table for payment records
- Check both subscriptions and user_subscriptions tables
- Check profiles table for subscription_status updates
*/

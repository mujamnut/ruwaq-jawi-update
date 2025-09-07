import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Helper function to convert plan ID to plan type
function _getPlanType(planId: string): string {
  switch (planId.toLowerCase()) {
    case 'monthly_basic':
    case 'monthly_premium':
      return '1month';
    case 'quarterly_premium':
      return '3month';
    case 'semiannual_premium':
      return '6month';
    case 'annual_premium':
    case 'yearly_premium':
      return '12month';
    default:
      return '1month';
  }
}

serve(async (req) => {
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
    
    // Parse metadata from order_id (format: userId_planId)
    const [userId, planId] = (orderId as string)?.split('_') || [];

    if (!userId || !planId) {
      console.error('Invalid order_id format');
      return new Response(
        JSON.stringify({ error: 'Invalid order_id format' }),
        { 
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    console.log(`Processing payment webhook: status=${status}, userId=${userId}, planId=${planId}`);

    // Handle payment status
    if (status === '1') { // Payment successful
      // Calculate subscription dates based on plan's duration_days
      const now = new Date();
      console.log(`Fetching plan details for planId: ${planId}`);
      
      // Determine duration based on plan type
      let durationDays = 30; // default
      switch (planId.toLowerCase()) {
        case 'monthly_basic':
        case 'monthly_premium':
          durationDays = 30;
          break;
        case 'quarterly_premium':
          durationDays = 90;
          break;
        case 'semiannual_premium':
          durationDays = 180;
          break;
        case 'annual_premium':
        case 'yearly_premium':
          durationDays = 365;
          break;
      }
      console.log(`Plan type: ${planId}, duration: ${durationDays} days`);
      const endDate = new Date(now);
      endDate.setDate(endDate.getDate() + durationDays);
      console.log(`Subscription duration: ${durationDays} days, end_date: ${endDate.toISOString()}`);

      // Get user's full name for snapshot
      console.log(`Fetching profile for userId: ${userId}`);
      const { data: profile, error: profileError } = await supabaseClient
        .from('profiles')
        .select('full_name')
        .eq('id', userId)
        .maybeSingle();

      if (profileError) {
        console.warn('Warning: could not fetch user profile for name snapshot:', profileError);
      }
      console.log(`Profile found:`, profile);

      // Check if user already has an active subscription
      const { data: existingSubscription } = await supabaseClient
        .from('subscriptions')
        .select()
        .eq('user_id', userId)
        .eq('status', 'active')
        .gte('end_date', now.toISOString())
        .maybeSingle();

      let subscriptionId;
      
      if (existingSubscription) {
        // Extend existing subscription
        const currentEndDate = new Date(existingSubscription.end_date);
        const newEndDate = new Date(currentEndDate);
        newEndDate.setDate(newEndDate.getDate() + durationDays);
        
        subscriptionId = existingSubscription.id;
        
        const { error: updateError } = await supabaseClient
          .from('subscriptions')
          .update({
            end_date: newEndDate.toISOString(),
            plan_type: _getPlanType(planId),
            amount: parseFloat(paymentAmount as string),
            updated_at: now.toISOString(),
          })
          .eq('id', subscriptionId);
          
        if (updateError) {
          console.error('Error updating subscription:', updateError);
          throw updateError;
        }
        console.log('Extended existing subscription');
      } else {
        // Create new subscription
        const subscriptionData = {
          user_id: userId,
          plan_type: _getPlanType(planId),
          start_date: now.toISOString(),
          end_date: endDate.toISOString(),
          status: 'active',
          payment_method: 'toyyibpay',
          amount: parseFloat(paymentAmount as string),
          currency: 'MYR',
          auto_renew: false,
        };
        
        const { data: newSubscription, error: subscriptionError } = await supabaseClient
          .from('subscriptions')
          .insert(subscriptionData)
          .select()
          .single();
          
        if (subscriptionError) {
          console.error('Error creating subscription:', subscriptionError);
          throw subscriptionError;
        }
        
        subscriptionId = newSubscription.id;
        console.log('Created new subscription');
      }

      if (subscriptionError) {
        console.error('Error creating subscription:', subscriptionError);
        throw subscriptionError;
      }
      console.log('Subscription upserted successfully');

      // Update user's subscription status in profiles table
      console.log(`\n=== UPDATING PROFILE STATUS ===`);
      console.log(`User ID: ${userId}`);
      console.log(`Setting subscription_status to: active`);
      
      const profileUpdateData = {
        subscription_status: 'active',
        updated_at: now.toISOString()
      };
      console.log('Profile update data:', JSON.stringify(profileUpdateData, null, 2));
      
      const { data: updateResult, error: userError } = await supabaseClient
        .from('profiles')
        .update(profileUpdateData)
        .eq('id', userId)
        .select();
        
      console.log('Profile update result:');
      console.log('- Error:', userError);
      console.log('- Updated data:', updateResult);

      // Insert transaction record
      const { error: paymentError } = await supabaseClient
        .from('transactions')
        .insert({
          user_id: userId,
          subscription_id: subscriptionId,
          amount: parseFloat(paymentAmount as string),
          currency: 'MYR',
          payment_method: 'toyyibpay',
          status: 'completed',
          payment_reference: billCode,
          metadata: {
            billCode,
            orderId,
            msg
          }
        });

      if (userError) {
        console.error('❌ ERROR updating user profile:', userError);
        // Don't throw here, continue with payment record
      } else {
        console.log('✅ Profile subscription_status updated successfully to active');
      }

      if (paymentError) {
        console.error('Error inserting payment record:', paymentError);
        throw paymentError;
      }

      console.log(`\n=== SUBSCRIPTION ACTIVATION COMPLETE ===`);
      console.log(`✅ Successfully activated subscription for user ${userId}`);
      
      // Verify the profile was actually updated
      console.log(`\n=== VERIFYING PROFILE UPDATE ===`);
      const { data: updatedProfile, error: verifyError } = await supabaseClient
        .from('profiles')
        .select('subscription_status, updated_at, full_name')
        .eq('id', userId)
        .maybeSingle();
        
      if (verifyError) {
        console.error('❌ Error verifying profile update:', verifyError);
      } else {
        console.log('✅ Profile verification after update:');
        console.log(JSON.stringify(updatedProfile, null, 2));
        
        if (updatedProfile?.subscription_status === 'active') {
          console.log('🎉 CONFIRMATION: Profile subscription_status is ACTIVE');
        } else {
          console.log('⚠️  WARNING: Profile subscription_status is NOT active:', updatedProfile?.subscription_status);
        }
      }
      
      // Also verify subscription record
      console.log(`\n=== VERIFYING SUBSCRIPTION RECORD ===`);
      const { data: subscriptionRecord, error: subVerifyError } = await supabaseClient
        .from('subscriptions')
        .select('*')
        .eq('user_id', userId)
        .eq('status', 'active')
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();
        
      if (subVerifyError) {
        console.error('❌ Error verifying subscription:', subVerifyError);
      } else if (subscriptionRecord) {
        console.log('✅ Active subscription found:');
        console.log(`- Plan: ${subscriptionRecord.plan_type}`);
        console.log(`- Start: ${subscriptionRecord.start_date}`);
        console.log(`- End: ${subscriptionRecord.end_date}`);
        console.log(`- Status: ${subscriptionRecord.status}`);
      } else {
        console.log('❌ No active subscription found in database');
      }
    }

    // Log webhook event
    await supabaseClient
      .from('webhook_logs')
      .insert({
        provider: 'toyyibpay',
        event_type: 'payment_status_update',
        payload: {
          status,
          billCode,
          orderId,
          msg,
          paymentAmount
        },
        status: status === '1' ? 'success' : 'failed',
        reference_number: orderId,
        created_at: new Date().toISOString()
      });

    return new Response(
      JSON.stringify({ success: true }),
      { 
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );

  } catch (error) {
    console.error('Error processing webhook:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );
  }
});

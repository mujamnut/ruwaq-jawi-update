import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS'
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }

  try {
    console.log('🔄 FINAL ToyyibPay Webhook - Processing callback');
    console.log(`🔄 Method: ${req.method}`);
    console.log(`🔄 Headers:`, Object.fromEntries(req.headers.entries()));

    let callbackData = {};

    // Parse request based on content type and method
    const contentType = req.headers.get('content-type') || '';

    if (req.method === 'POST') {
      if (contentType.includes('application/json')) {
        try {
          callbackData = await req.json();
          console.log('📥 Parsed JSON payload:', callbackData);
        } catch (jsonError) {
          console.log('⚠️ JSON parsing failed, trying form data...');
          // Try to parse as form data
          try {
            const body = await req.text();
            console.log('📥 Raw body:', body);
            const params = new URLSearchParams(body);
            callbackData = Object.fromEntries(params.entries());
            console.log('📥 Parsed form data:', callbackData);
          } catch (formError) {
            console.error('❌ Failed to parse form data:', formError);
            return new Response('Bad Request - Invalid payload format', {
              status: 400,
              headers: corsHeaders
            });
          }
        }
      } else if (contentType.includes('application/x-www-form-urlencoded')) {
        const body = await req.text();
        console.log('📥 Raw form body:', body);
        const params = new URLSearchParams(body);
        callbackData = Object.fromEntries(params.entries());
        console.log('📥 Parsed form data:', callbackData);
      } else {
        // Try to parse as text and then as form data
        const body = await req.text();
        console.log('📥 Unknown content type, raw body:', body);
        try {
          const params = new URLSearchParams(body);
          callbackData = Object.fromEntries(params.entries());
          console.log('📥 Parsed as form data:', callbackData);
        } catch (e) {
          console.error('❌ Could not parse body:', e);
          return new Response('Bad Request - Could not parse payload', {
            status: 400,
            headers: corsHeaders
          });
        }
      }
    } else if (req.method === 'GET') {
      // Parse query parameters for GET requests
      const url = new URL(req.url);
      callbackData = Object.fromEntries(url.searchParams.entries());
      console.log('📥 Parsed GET parameters:', callbackData);
    }

    // Extract key fields
    const billCode = callbackData.billcode || callbackData.bill_code;
    const orderId = callbackData.order_id;
    const status = callbackData.status;
    const statusId = callbackData.status_id;
    const transactionId = callbackData.transaction_id;
    const amount = callbackData.amount;

    console.log('📋 Extracted callback data:', {
      billCode,
      orderId,
      status,
      statusId,
      transactionId,
      amount
    });

    // Validate required fields
    if (!billCode) {
      console.error('❌ Missing bill code in callback');
      return new Response('Bad Request - Missing bill code', {
        status: 400,
        headers: corsHeaders
      });
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!supabaseUrl || !supabaseKey) {
      console.error('❌ Missing Supabase configuration');
      return new Response('Server configuration error', {
        status: 500,
        headers: corsHeaders
      });
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    // Store webhook event for audit
    const { error: webhookError } = await supabase.from('webhook_events').insert({
      provider: 'toyyibpay',
      event_type: 'payment_callback',
      bill_code: billCode,
      transaction_id: transactionId,
      status: status,
      status_id: statusId,
      raw_payload: callbackData,
      received_at: new Date(Date.now()).toISOString()
    });

    if (webhookError) {
      console.error('❌ Error storing webhook event:', webhookError);
    }

    // If payment is successful, process payment using single payments table
    if (status?.toLowerCase() === 'success' && statusId === '1') {
      console.log('🎉 Payment successful! Processing payment...');

      try {
        // Find pending payment in payments table
        const { data: payment, error: findError } = await supabase
          .from('payments')
          .select('*')
          .eq('bill_id', billCode)
          .eq('status', 'pending')
          .maybeSingle();

        if (findError || !payment) {
          console.log('⚠️ No pending payment found for:', billCode);
          return new Response('Payment not found', {
            status: 200,
            headers: corsHeaders
          });
        }

        const userId = payment.user_id;
        const planId = payment.plan_id;
        const paymentAmount = payment.amount_cents / 100.0;

        console.log(`🔍 Found payment - User: ${userId}, Plan: ${planId}, Amount: RM${paymentAmount}`);

        const now = new Date(Date.now()).toISOString();

        // Update payment status to completed
        const { error: updateError } = await supabase
          .from('payments')
          .update({
            status: 'completed',
            updated_at: now,
            paid_at: now,
            provider_payment_id: transactionId || billCode,
            raw_payload: {
              ...callbackData,
              processed_at: now
            }
          })
          .eq('id', payment.id);

        if (updateError) {
          console.error('❌ Error updating payment:', updateError);
          throw new Error('Failed to update payment');
        }

        console.log('✅ Payment updated to completed');

        // Activate subscription
        console.log('🔄 Activating subscription...');

        // Get plan details
        const { data: planData } = await supabase
          .from('subscription_plans')
          .select('duration_days, name')
          .eq('id', planId)
          .maybeSingle();

        if (!planData) {
          console.log('⚠️ Plan not found:', planId);
        } else {
          const durationDays = planData.duration_days || 30;
          const endDate = new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000).toISOString();

          // Get user profile
          const { data: profile } = await supabase
            .from('profiles')
            .select('full_name')
            .eq('id', userId)
            .maybeSingle();

          // Create/update subscription
          const { error: subError } = await supabase
            .from('user_subscriptions')
            .upsert({
              user_id: userId,
              user_name: profile?.full_name || 'Unknown',
              subscription_plan_id: planId,
              status: 'active',
              start_date: now,
              end_date: endDate,
              payment_id: transactionId || billCode,
              amount: paymentAmount,
              currency: 'MYR',
              updated_at: now
            });

          if (subError) {
            console.log('❌ Subscription error:', subError);
          } else {
            console.log('✅ Subscription activated');
          }

          // Update profile status
          const { error: profileError } = await supabase
            .from('profiles')
            .update({
              subscription_status: 'active',
              updated_at: now
            })
            .eq('id', userId);

          if (profileError) {
            console.log('❌ Profile update error:', profileError);
          } else {
            console.log('✅ Profile status updated');
          }
        }

        // Create success notification
        try {
          const notificationData = {
            type: 'personal',
            title: 'Pembayaran Berjaya! 🎉',
            message: `Terima kasih! Pembayaran RM${paymentAmount.toFixed(2)} untuk langganan ${planId} telah berjaya. Langganan anda kini aktif.`,
            target_type: 'user',
            target_criteria: {
              user_ids: [userId]
            },
            metadata: {
              type: 'payment_success',
              sub_type: 'payment_success',
              icon: '🎉',
              priority: 'high',
              bill_id: billCode,
              plan_id: planId,
              amount: paymentAmount.toFixed(2),
              payment_date: now,
              action_url: '/subscription',
              source: 'final_webhook'
            },
            created_at: now,
            expires_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
            is_active: true
          };

          const { data: newNotification } = await supabase
            .from('notifications')
            .insert(notificationData)
            .select('id')
            .single();

          if (newNotification) {
            await supabase
              .from('notification_reads')
              .insert({
                notification_id: newNotification.id,
                user_id: userId,
                is_read: false,
                created_at: now,
                updated_at: now
              });
            console.log('✅ Notification created');
          }
        } catch (notificationError) {
          console.error('⚠️ Notification error:', notificationError);
        }

        console.log('✅ Payment processed successfully!');

        return new Response(JSON.stringify({
          success: true,
          message: 'Payment processed and subscription activated',
          billCode: billCode,
          userId: userId,
          planId: planId,
          amount: paymentAmount
        }), {
          status: 200,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        });

      } catch (error) {
        console.error('❌ Processing error:', error);
        return new Response('Error processing payment', {
          status: 500,
          headers: corsHeaders
        });
      }

    } else if (statusId === '3' || status?.toLowerCase() === 'failed') {
      console.log('❌ Payment failed');

      // Update payment to failed
      await supabase
        .from('payments')
        .update({
          status: 'failed',
          updated_at: new Date(Date.now()).toISOString()
        })
        .eq('bill_id', billCode);

      return new Response('Payment failed', {
        status: 200,
        headers: corsHeaders
      });

    } else {
      console.log(`⏳ Payment pending (status: ${status}, statusId: ${statusId})`);

      return new Response('Payment pending', {
        status: 200,
        headers: corsHeaders
      });
    }

  } catch (error) {
    console.error('❌ Webhook error:', error);
    return new Response('Internal server error', {
      status: 500,
      headers: corsHeaders
    });
  }
});
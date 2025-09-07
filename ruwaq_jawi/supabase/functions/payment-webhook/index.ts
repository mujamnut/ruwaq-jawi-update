import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface ChipWebhookPayload {
  event: 'payment.completed' | 'payment.failed';
  data: {
    id: string;
    amount: number;
    currency: string;
    status: 'completed' | 'failed';
    metadata?: {
      transaction_id: string;
      subscription_id: string;
      user_id: string;
    };
  };
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Initialize Supabase client with service role key for admin access
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    // Parse webhook payload
    const payload: ChipWebhookPayload = await req.json();
    
    console.log('Received webhook:', JSON.stringify(payload));

    // Validate webhook signature (in production, verify with Chip's signature)
    // const signature = req.headers.get('x-chip-signature');
    // if (!verifySignature(payload, signature)) {
    //   throw new Error('Invalid webhook signature');
    // }

    if (payload.event === 'payment.completed') {
      await handlePaymentSuccess(supabaseClient, payload);
    } else if (payload.event === 'payment.failed') {
      await handlePaymentFailure(supabaseClient, payload);
    }

    return new Response(
      JSON.stringify({ success: true }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    );
  } catch (error) {
    console.error('Webhook error:', error);
    
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      },
    );
  }
});

async function handlePaymentSuccess(supabaseClient: any, payload: ChipWebhookPayload) {
  const { data: paymentData } = payload;
  const { transaction_id, subscription_id, user_id } = paymentData.metadata || {};

  if (!transaction_id || !subscription_id || !user_id) {
    throw new Error('Missing required metadata in payment webhook');
  }

  // Update transaction status
  const { error: transactionError } = await supabaseClient
    .from('transactions')
    .update({
      status: 'completed',
      gateway_transaction_id: paymentData.id,
      processed_at: new Date().toISOString(),
    })
    .eq('id', transaction_id);

  if (transactionError) {
    throw new Error(`Failed to update transaction: ${transactionError.message}`);
  }

  // Activate subscription
  const { error: subscriptionError } = await supabaseClient
    .from('subscriptions')
    .update({
      status: 'active',
      updated_at: new Date().toISOString(),
    })
    .eq('id', subscription_id);

  if (subscriptionError) {
    throw new Error(`Failed to activate subscription: ${subscriptionError.message}`);
  }

  // Update user profile subscription status
  const { error: profileError } = await supabaseClient
    .from('profiles')
    .update({
      subscription_status: 'active',
      updated_at: new Date().toISOString(),
    })
    .eq('id', user_id);

  if (profileError) {
    throw new Error(`Failed to update profile: ${profileError.message}`);
  }

  console.log(`Payment completed successfully for user ${user_id}, subscription ${subscription_id}`);
}

async function handlePaymentFailure(supabaseClient: any, payload: ChipWebhookPayload) {
  const { data: paymentData } = payload;
  const { transaction_id, subscription_id } = paymentData.metadata || {};

  if (!transaction_id) {
    throw new Error('Missing transaction_id in payment failure webhook');
  }

  // Update transaction status
  const { error: transactionError } = await supabaseClient
    .from('transactions')
    .update({
      status: 'failed',
      failure_reason: 'Payment gateway reported failure',
      processed_at: new Date().toISOString(),
    })
    .eq('id', transaction_id);

  if (transactionError) {
    throw new Error(`Failed to update transaction: ${transactionError.message}`);
  }

  // Update subscription status to cancelled if it exists
  if (subscription_id) {
    const { error: subscriptionError } = await supabaseClient
      .from('subscriptions')
      .update({
        status: 'cancelled',
        updated_at: new Date().toISOString(),
      })
      .eq('id', subscription_id);

    if (subscriptionError) {
      console.error('Failed to update subscription status:', subscriptionError.message);
    }
  }

  console.log(`Payment failed for transaction ${transaction_id}`);
}
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface HitPayWebhookPayload {
  id: string
  status: string
  reference_number: string
  amount: string
  currency: string
  payment_id: string
  paid_at?: string
  metadata?: {
    subscription_plan_id?: string
    user_id?: string
    plan_name?: string
    duration_days?: string
  }
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Get request body and headers
    const body = await req.text()
    const signature = req.headers.get('x-signature') || ''
    const webhookSecret = Deno.env.get('HITPAY_WEBHOOK_SECRET') ?? ''

    // Verify webhook signature (simplified - implement proper HMAC verification)
    if (!verifySignature(body, signature, webhookSecret)) {
      console.error('Invalid webhook signature')
      return new Response(
        JSON.stringify({ error: 'Invalid signature' }),
        { 
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Parse webhook payload
    const payload: HitPayWebhookPayload = JSON.parse(body)
    console.log('Received webhook payload:', payload)

    // Process payment based on status
    if (payload.status === 'completed' || payload.status === 'paid') {
      await handleSuccessfulPayment(supabaseClient, payload)
    } else if (payload.status === 'failed' || payload.status === 'cancelled') {
      await handleFailedPayment(supabaseClient, payload)
    }

    // Log the webhook event
    await logWebhookEvent(supabaseClient, payload)

    return new Response(
      JSON.stringify({ success: true, message: 'Webhook processed successfully' }),
      { 
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('Error processing webhook:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})

async function handleSuccessfulPayment(supabaseClient: any, payload: HitPayWebhookPayload) {
  const { metadata } = payload
  
  if (!metadata?.user_id || !metadata?.subscription_plan_id) {
    console.error('Missing required metadata for subscription')
    return
  }

  const userId = metadata.user_id
  const planId = metadata.subscription_plan_id
  const durationDays = parseInt(metadata.duration_days || '30')
  
  // Calculate subscription end date
  const startDate = new Date()
  const endDate = new Date(startDate.getTime() + (durationDays * 24 * 60 * 60 * 1000))

  try {
    // Insert or update user subscription
    const { error: subscriptionError } = await supabaseClient
      .from('user_subscriptions')
      .upsert({
        user_id: userId,
        subscription_plan_id: planId,
        status: 'active',
        start_date: startDate.toISOString(),
        end_date: endDate.toISOString(),
        payment_id: payload.payment_id,
        amount: parseFloat(payload.amount),
        currency: payload.currency,
        updated_at: new Date().toISOString()
      })

    if (subscriptionError) {
      console.error('Error updating subscription:', subscriptionError)
      throw subscriptionError
    }

    // Insert payment record
    const { error: paymentError } = await supabaseClient
      .from('payments')
      .insert({
        user_id: userId,
        payment_id: payload.payment_id,
        reference_number: payload.reference_number,
        amount: parseFloat(payload.amount),
        currency: payload.currency,
        status: payload.status,
        payment_method: 'hitpay',
        paid_at: payload.paid_at || new Date().toISOString(),
        metadata: payload.metadata,
        created_at: new Date().toISOString()
      })

    if (paymentError) {
      console.error('Error inserting payment record:', paymentError)
      throw paymentError
    }

    // Send notification email (optional)
    await sendSubscriptionConfirmationEmail(supabaseClient, userId, metadata.plan_name || 'Premium Plan')

    console.log(`Successfully activated subscription for user ${userId}`)

  } catch (error) {
    console.error('Error handling successful payment:', error)
    throw error
  }
}

async function handleFailedPayment(supabaseClient: any, payload: HitPayWebhookPayload) {
  const { metadata } = payload
  
  if (!metadata?.user_id) {
    console.error('Missing user_id in metadata for failed payment')
    return
  }

  try {
    // Insert failed payment record
    const { error: paymentError } = await supabaseClient
      .from('payments')
      .insert({
        user_id: metadata.user_id,
        payment_id: payload.payment_id,
        reference_number: payload.reference_number,
        amount: parseFloat(payload.amount),
        currency: payload.currency,
        status: payload.status,
        payment_method: 'hitpay',
        metadata: payload.metadata,
        created_at: new Date().toISOString()
      })

    if (paymentError) {
      console.error('Error inserting failed payment record:', paymentError)
      throw paymentError
    }

    console.log(`Recorded failed payment for user ${metadata.user_id}`)

  } catch (error) {
    console.error('Error handling failed payment:', error)
    throw error
  }
}

async function logWebhookEvent(supabaseClient: any, payload: HitPayWebhookPayload) {
  try {
    const { error } = await supabaseClient
      .from('webhook_logs')
      .insert({
        provider: 'hitpay',
        event_type: 'payment_status_update',
        payload: payload,
        status: payload.status,
        reference_number: payload.reference_number,
        created_at: new Date().toISOString()
      })

    if (error) {
      console.error('Error logging webhook event:', error)
    }
  } catch (error) {
    console.error('Error in logWebhookEvent:', error)
  }
}

async function sendSubscriptionConfirmationEmail(supabaseClient: any, userId: string, planName: string) {
  try {
    // Get user email
    const { data: user, error: userError } = await supabaseClient.auth.admin.getUserById(userId)
    
    if (userError || !user?.email) {
      console.error('Error getting user email:', userError)
      return
    }

    // You can integrate with email service here (SendGrid, Resend, etc.)
    console.log(`Would send confirmation email to ${user.email} for ${planName} subscription`)
    
    // Example with Supabase Edge Functions email service
    // await supabaseClient.functions.invoke('send-email', {
    //   body: {
    //     to: user.email,
    //     subject: 'Subscription Activated - Ruwaq Jawi',
    //     template: 'subscription-confirmation',
    //     data: { planName, userName: user.user_metadata?.full_name || 'User' }
    //   }
    // })

  } catch (error) {
    console.error('Error sending confirmation email:', error)
  }
}

function verifySignature(payload: string, signature: string, secret: string): boolean {
  // Implement proper HMAC SHA256 verification here
  // This is a simplified version - in production, use proper crypto verification
  
  if (!signature || !secret) {
    return false
  }

  // For now, return true if signature exists
  // In production, implement proper HMAC verification:
  // const expectedSignature = crypto.createHmac('sha256', secret).update(payload).digest('hex')
  // return signature === expectedSignature
  
  return signature.length > 0
}

/* 
DATABASE SETUP REQUIRED:

Run these SQL commands in your Supabase SQL editor:

-- Create subscription plans table
CREATE TABLE IF NOT EXISTS subscription_plans (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  price DECIMAL(10,2) NOT NULL,
  currency TEXT DEFAULT 'MYR',
  duration_days INTEGER DEFAULT 30,
  features JSONB DEFAULT '[]',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create user subscriptions table
CREATE TABLE IF NOT EXISTS user_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  subscription_plan_id TEXT REFERENCES subscription_plans(id),
  status TEXT DEFAULT 'pending',
  start_date TIMESTAMP WITH TIME ZONE,
  end_date TIMESTAMP WITH TIME ZONE,
  payment_id TEXT,
  amount DECIMAL(10,2),
  currency TEXT DEFAULT 'MYR',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, subscription_plan_id)
);

-- Create payments table
CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  payment_id TEXT UNIQUE NOT NULL,
  reference_number TEXT,
  amount DECIMAL(10,2) NOT NULL,
  currency TEXT DEFAULT 'MYR',
  status TEXT NOT NULL,
  payment_method TEXT DEFAULT 'hitpay',
  paid_at TIMESTAMP WITH TIME ZONE,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create webhook logs table
CREATE TABLE IF NOT EXISTS webhook_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider TEXT NOT NULL,
  event_type TEXT NOT NULL,
  payload JSONB NOT NULL,
  status TEXT,
  reference_number TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert sample subscription plans
INSERT INTO subscription_plans (id, name, description, price, currency, duration_days, features) VALUES
('monthly_basic', 'Monthly Basic', 'Access to basic Islamic content library', 19.90, 'MYR', 30, '["Access to 100+ Islamic books", "Basic video lectures", "Mobile app access", "Email support"]'),
('monthly_premium', 'Monthly Premium', 'Full access to all Islamic educational content', 39.90, 'MYR', 30, '["Access to 500+ Islamic books", "Premium video lectures", "Offline download", "Priority support", "Advanced search features"]'),
('yearly_premium', 'Yearly Premium', 'Full access with significant savings', 399.90, 'MYR', 365, '["Access to 500+ Islamic books", "Premium video lectures", "Offline download", "Priority support", "Advanced search features", "2 months free"]')
ON CONFLICT (id) DO NOTHING;

-- Enable RLS
ALTER TABLE user_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE webhook_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own subscriptions" ON user_subscriptions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can view their own payments" ON payments FOR SELECT USING (auth.uid() = user_id);

-- Admin policies (adjust as needed)
CREATE POLICY "Service role can manage all data" ON user_subscriptions FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Service role can manage all payments" ON payments FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Service role can manage webhook logs" ON webhook_logs FOR ALL USING (auth.role() = 'service_role');

ENVIRONMENT VARIABLES NEEDED:
- HITPAY_WEBHOOK_SECRET: Your HitPay webhook secret
- SUPABASE_URL: Your Supabase project URL
- SUPABASE_SERVICE_ROLE_KEY: Your Supabase service role key

DEPLOYMENT INSTRUCTIONS:
1. Copy this code to a new Edge Function in your Supabase project
2. Set the required environment variables
3. Deploy the function
4. Configure the webhook URL in your HitPay dashboard to point to this function
*/

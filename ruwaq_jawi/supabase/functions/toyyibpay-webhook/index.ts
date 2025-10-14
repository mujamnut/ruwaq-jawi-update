import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { createHash } from "https://deno.land/std@0.168.0/crypto/mod.ts"
import { encodeHex } from "https://deno.land/std@0.168.0/encoding/hex.ts"

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

// 🔒 SECURITY: Rate limiting storage (in production, use Redis or database)
const rateLimitStore = new Map<string, { count: number; lastReset: number }>()
const RATE_LIMIT_WINDOW = 60 * 1000 // 1 minute
const RATE_LIMIT_MAX_REQUESTS = 10 // Max 10 requests per minute per IP

// 🔒 SECURITY: ToyyibPay webhook secret (use environment variable in production)
const WEBHOOK_SECRET = Deno.env.get('TOYYIBPAY_WEBHOOK_SECRET') || 'your_webhook_secret_here'

// 🔒 SECURITY: Verify ToyyibPay webhook signature
function verifyWebhookSignature(body: string, signature: string, secret: string): boolean {
  try {
    const expectedSignature = encodeHex(createHash('sha-256', new TextEncoder().encode(body + secret)))
    const isValid = expectedSignature === signature.toLowerCase()

    if (!isValid) {
      console.log('🚨 SECURITY: Invalid webhook signature')
      console.log('🔍 Expected:', expectedSignature)
      console.log('🔍 Received:', signature.toLowerCase())
    }

    return isValid
  } catch (error) {
    console.error('❌ Error verifying webhook signature:', error)
    return false
  }
}

// 🔒 SECURITY: Rate limiting check
function checkRateLimit(ip: string): boolean {
  const now = Date.now()
  const windowStart = now - RATE_LIMIT_WINDOW

  let clientData = rateLimitStore.get(ip)

  if (!clientData || clientData.lastReset < windowStart) {
    clientData = { count: 0, lastReset: now }
    rateLimitStore.set(ip, clientData)
  }

  if (clientData.count >= RATE_LIMIT_MAX_REQUESTS) {
    console.log('🚨 SECURITY: Rate limit exceeded for IP:', ip)
    return false
  }

  clientData.count++
  return true
}

// 🔒 SECURITY: Restricted CORS - Only allow specific origins
const corsHeaders = {
  'Access-Control-Allow-Origin': 'https://ckgxglvozrsognqqkpkk.supabase.co', // Your Supabase project URL
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-toyyibpay-signature',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Max-Age': '86400', // 24 hours
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 🔒 SECURITY: Rate limiting check
    const clientIP = req.headers.get('x-forwarded-for') || req.headers.get('x-real-ip') || 'unknown'
    if (!checkRateLimit(clientIP)) {
      return new Response('Rate limit exceeded. Please try again later.', {
        status: 429,
        headers: corsHeaders
      })
    }

    console.log(`🔄 Processing ToyyibPay callback - Method: ${req.method}, IP: ${clientIP}`)
    console.log(`🔄 Content-Type: ${req.headers.get('content-type')}`)

    // 🔒 SECURITY: Get webhook signature
    const signature = req.headers.get('x-toyyibpay-signature') || req.headers.get('toyyibpay-signature') || ''

    if (!signature) {
      console.log('🚨 SECURITY: Missing webhook signature')
      return new Response('Unauthorized - Missing signature', {
        status: 401,
        headers: corsHeaders
      })
    }

    let callbackData: ToyyibPayCallback = {}

    // Parse request based on content type and method
    const contentType = req.headers.get('content-type') || ''
    
    if (req.method === 'POST') {
      let body = ''

      if (contentType.includes('application/json')) {
        try {
          body = await req.text()
          callbackData = await req.json()
          console.log('📥 Parsed JSON payload:', callbackData)
        } catch (jsonError) {
          console.log('⚠️ JSON parsing failed, trying form data...')

          // Try to parse as form data
          try {
            body = await req.text()
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
        body = await req.text()
        console.log('📥 Raw form body:', body)

        const params = new URLSearchParams(body)
        callbackData = Object.fromEntries(params.entries())
        console.log('📥 Parsed form data:', callbackData)
      } else {
        // Try to parse as text and then as form data
        body = await req.text()
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

      // 🔒 SECURITY: Verify webhook signature
      if (!verifyWebhookSignature(body, signature, WEBHOOK_SECRET)) {
        return new Response('Unauthorized - Invalid signature', {
          status: 401,
          headers: corsHeaders
        })
      }

      console.log('✅ Webhook signature verified successfully')
    } else if (req.method === 'GET') {
      // Parse query parameters for GET requests
      const url = new URL(req.url)
      callbackData = Object.fromEntries(url.searchParams.entries())
      console.log('📥 Parsed GET parameters:', callbackData)

      // 🔒 SECURITY: GET requests don't have body to verify signature
      console.log('⚠️ WARNING: GET request - signature verification skipped')
    } else {
      return new Response('Method not allowed', {
        status: 405,
        headers: corsHeaders
      })
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
        received_at: new Date(Date.now()).toISOString()
      })

    if (webhookError) {
      console.error('❌ Error storing webhook event:', webhookError)
    }

    // If payment is successful, process payment and update both tables
    if (status?.toLowerCase() === 'success' && statusId === '1') {
      console.log('🎉 Payment successful from callback! Processing payment...')

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

        console.log(`🔍 Found pending payment - User: ${userId}, Plan: ${planId}, Amount: ${paymentAmount}`)

        // Step 1: Update payments table status to 'completed'
        const now = new Date(Date.now()).toISOString()

        // Find existing payment record
        const { data: existingPayment } = await supabase
          .from('payments')
          .select('id')
          .eq('bill_id', billCode)
          .order('created_at', { ascending: true })
          .limit(1)
          .single()

        if (existingPayment) {
          console.log('📝 Updating existing payment record:', existingPayment.id)

          const { error: updateError } = await supabase
            .from('payments')
            .update({
              status: 'completed',
              updated_at: now,
              paid_at: now,
              provider_payment_id: transactionId || billCode,
              raw_payload: { ...callbackData, processed_at: now }
            })
            .eq('id', existingPayment.id)

          if (updateError) {
            console.error('❌ Error updating payment record:', updateError)
            throw new Error('Failed to update payment status')
          }

          console.log('✅ Payment record updated to completed')
        } else {
          console.log('⚠️ No existing payment record found to update')
        }

        // Step 2: Process subscription activation
        console.log('🔄 Activating subscription...')

        // Call extend-subscription edge function for centralized processing
        const extendSubscriptionUrl = `${supabaseUrl}/functions/v1/extend-subscription`
        const extendResponse = await fetch(extendSubscriptionUrl, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            userId: userId,
            planId: planId,
            paymentData: {
              transactionId: transactionId || billCode,
              amount: paymentAmount,
              billId: billCode,
              status: '1',
              source: 'webhook'
            }
          })
        })

        let extendResult = null
        if (!extendResponse.ok) {
          const errorText = await extendResponse.text()
          console.error('❌ Extend subscription function error:', extendResponse.status, errorText)
          // Don't throw error yet - still update pending payment status
          console.log('⚠️ Subscription activation failed, but marking payment as completed')
        } else {
          extendResult = await extendResponse.json()
          console.log('✅ Subscription activation result:', extendResult)
        }

        // Step 3: Update pending payment status to completed
        await supabase
          .from('pending_payments')
          .update({
            status: 'completed',
            updated_at: now
          })
          .eq('bill_id', billCode)
          .eq('user_id', userId)

        // Step 4: Create payment success notification
        try {
          console.log('🔔 Creating payment success notification...')

          const formattedAmount = paymentAmount.toFixed(2)
          const notificationData = {
            type: 'personal',
            title: 'Pembayaran Berjaya! 🎉',
            message: `Terima kasih! Pembayaran RM${formattedAmount} untuk langganan ${planId} telah berjaya. Langganan anda kini aktif.`,
            target_type: 'user',
            target_criteria: { user_ids: [userId] },
            metadata: {
              type: 'payment_success',
              sub_type: 'payment_success',
              icon: '🎉',
              priority: 'high',
              bill_id: billCode,
              plan_id: planId,
              amount: formattedAmount,
              subscription_id: extendResult?.newSubscriptionId || null,
              days_added: extendResult?.daysAdded || 0,
              payment_date: now,
              action_url: '/subscription',
              source: 'toyyibpay_webhook',
            },
            created_at: now,
            expires_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(), // 30 days
            is_active: true
          }

          console.log('📝 Inserting notification with data:', notificationData)

          // FIXED: Get notification ID from insert response instead of searching
          const { data: newNotification, error: notificationError } = await supabase
            .from('notifications')
            .insert(notificationData)
            .select('id')
            .single()

          if (notificationError) {
            console.error('❌ Error creating notification:', notificationError)
            console.error('❌ Notification error details:', JSON.stringify(notificationError, null, 2))
          } else if (newNotification) {
            console.log('✅ Payment success notification created with ID:', newNotification.id)

            // FIXED: Create notification read entry for immediate visibility using the returned ID
            const readEntryData = {
              notification_id: newNotification.id,
              user_id: userId,
              is_read: false,
              created_at: now,
              updated_at: now
            }

            console.log('📝 Creating notification read entry:', readEntryData)

            const { error: readError } = await supabase
              .from('notification_reads')
              .insert(readEntryData)

            if (readError) {
              console.error('❌ Error creating notification read entry:', readError)
              console.error('❌ Read entry error details:', JSON.stringify(readError, null, 2))
            } else {
              console.log('✅ Notification read entry created successfully for real-time delivery')
              console.log('🔔 User', userId, 'should receive notification immediately')
            }
          } else {
            console.error('❌ No notification data returned from insert')
          }
        } catch (notificationError) {
          console.error('⚠️ Error creating payment notification:', notificationError)
          console.error('⚠️ Notification error stack:', notificationError.stack)
          // Don't fail the payment process for notification errors
        }

        console.log('✅ Payment processed successfully via webhook!')

        return new Response(JSON.stringify({
          success: true,
          message: 'Payment processed and status updated to completed',
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
          updated_at: new Date(Date.now()).toISOString()
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

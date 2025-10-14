// @ts-nocheck
// This function handles ToyyibPay redirects without requiring authentication
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    console.log(`📥 Payment redirect - Method: ${req.method}`);
    console.log(`📥 URL: ${req.url}`);
    console.log(`📥 Headers:`, Object.fromEntries(req.headers.entries()));

    const url = new URL(req.url);
    const status = url.searchParams.get('status');
    const statusId = url.searchParams.get('status_id');
    const billCode = url.searchParams.get('billcode');
    const orderId = url.searchParams.get('order_id');
    const transactionId = url.searchParams.get('transaction_id');
    const msg = url.searchParams.get('msg');

    console.log('📋 Payment redirect parameters:', {
      status,
      statusId,
      billCode,
      orderId,
      transactionId,
      msg
    });

    // 🔥 IMPORTANT: This function handles ToyyibPay redirects WITHOUT authentication
    // The actual subscription activation is handled by the webhook (v20)
    // This page only shows the appropriate success/failure message to users

    // Check if this is a successful payment
    const isSuccess = status === 'success' && statusId === '1';
    console.log(`✅ Payment success determined: ${isSuccess}`);

    // Log the redirect for debugging
    console.log(`🔄 TOYYIBPAY REDIRECT RECEIVED:`);
    console.log(`   - Status: ${status} (ID: ${statusId})`);
    console.log(`   - Bill Code: ${billCode}`);
    console.log(`   - Transaction ID: ${transactionId}`);
    console.log(`   - Order ID: ${orderId}`);
    console.log(`   - Success: ${isSuccess}`);
    console.log(`   - Message: ${msg || 'none'}`);
    console.log(`📝 Note: Webhook (v20) handles actual subscription activation`);
    console.log(`📝 Note: This page only shows user feedback`);
    
    // Create a simple HTML page that will close the WebView
    const html = `
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Payment ${status === 'success' ? 'Successful' : 'Failed'}</title>
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
                min-height: 100vh;
                margin: 0;
                background: ${status === 'success' ? 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)' : 'linear-gradient(135deg, #f093fb 0%, #f5576c 100%)'};
                color: white;
                text-align: center;
                padding: 20px;
            }
            .container {
                background: rgba(255, 255, 255, 0.1);
                backdrop-filter: blur(10px);
                border-radius: 20px;
                padding: 40px;
                box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
                border: 1px solid rgba(255, 255, 255, 0.2);
                max-width: 400px;
                width: 100%;
            }
            .icon {
                font-size: 64px;
                margin-bottom: 20px;
            }
            h1 {
                margin: 0 0 10px 0;
                font-size: 24px;
                font-weight: 600;
            }
            p {
                margin: 0 0 30px 0;
                font-size: 16px;
                opacity: 0.9;
                line-height: 1.5;
            }
            .button {
                background: rgba(255, 255, 255, 0.2);
                border: 1px solid rgba(255, 255, 255, 0.3);
                color: white;
                padding: 12px 24px;
                border-radius: 10px;
                font-size: 16px;
                font-weight: 500;
                cursor: pointer;
                transition: all 0.3s ease;
                text-decoration: none;
                display: inline-block;
            }
            .button:hover {
                background: rgba(255, 255, 255, 0.3);
                transform: translateY(-2px);
            }
            .loading {
                margin-top: 20px;
                font-size: 14px;
                opacity: 0.7;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="icon">${isSuccess ? '✅' : '❌'}</div>
            <h1>${isSuccess ? 'Pembayaran Berjaya!' : 'Pembayaran Gagal'}</h1>
            <p>
                ${isSuccess
                    ? 'Terima kasih! Pembayaran anda berjaya. Langganan akan diaktifkan secara automatik melalui webhook.'
                    : 'Pembayaran tidak dapat diproses. Sila cuba lagi atau hubungi sokongan pelanggan.'}
            </p>
            ${isSuccess ? `
            <div style="background: rgba(76,175,80,0.2); padding: 15px; border-radius: 10px; margin: 20px 0; font-size: 14px;">
                <p><strong>✅ Status Pembayaran:</strong> Berjaya</p>
                <p><strong>📱 Langganan:</strong> Akan diaktifkan secara automatik</p>
                <p><strong>🔄 Proses:</strong> Webhook mengaktifkan langganan anda</p>
                <p><strong>⏱️ Masa:</strong> Biasanya mengambil masa < 1 minit</p>
            </div>
            ` : `
            <div style="background: rgba(244,67,54,0.2); padding: 15px; border-radius: 10px; margin: 20px 0; font-size: 14px;">
                <p><strong>❌ Status:</strong> Pembayaran tidak berjaya</p>
                <p><strong>🔄 Tindakan:</strong> Sila cuba lagi</p>
                <p><strong>💡 Bantuan:</strong> Hubungi support jika masalah berterusan</p>
            </div>
            `}
            <button class="button" onclick="closeWindow()">
                ${isSuccess ? 'Kembali ke Aplikasi' : 'Cuba Lagi'}
            </button>
            <div class="loading">Auto-redirect dalam 3 saat...</div>
        </div>

        <script>
            function closeWindow() {
                // Try multiple methods to close/redirect
                if (window.ReactNativeWebView) {
                    window.ReactNativeWebView.postMessage(JSON.stringify({
                        type: 'payment_result',
                        status: '${status}',
                        statusId: '${statusId}',
                        billCode: '${billCode}',
                        transactionId: '${transactionId}',
                        success: ${isSuccess}
                    }));
                }

                // For Flutter WebView
                if (window.flutter_inappwebview) {
                    window.flutter_inappwebview.callHandler('payment_result', {
                        status: '${status}',
                        statusId: '${statusId}',
                        billCode: '${billCode}',
                        transactionId: '${transactionId}',
                        success: ${isSuccess}
                    });
                }

                // Fallback - try to close window
                try {
                    window.close();
                } catch (e) {
                    // If can't close, redirect to a special URL that the app can detect
                    window.location.href = 'ruwaqjawi://payment?status=${status}&statusId=${statusId}&billCode=${billCode}&success=${isSuccess}';
                }
            }

            // Auto close after 3 seconds
            setTimeout(() => {
                closeWindow();
            }, 3000);

            // Also trigger on page load
            window.onload = function() {
                setTimeout(closeWindow, 1000);
            };
        </script>
    </body>
    </html>`;

    return new Response(html, {
      headers: {
        ...corsHeaders,
        'Content-Type': 'text/html; charset=utf-8',
      },
    });

  } catch (error) {
    console.error('Error in payment redirect:', error);

    const errorHtml = `
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <title>Error</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                text-align: center;
                padding: 50px;
                background: #f5f5f5;
            }
            .error {
                background: white;
                padding: 30px;
                border-radius: 10px;
                box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                max-width: 400px;
                margin: 0 auto;
            }
        </style>
    </head>
    <body>
        <div class="error">
            <h2>Ralat</h2>
            <p>Terdapat masalah dengan redirect pembayaran. Sila tutup tetingkap ini dan cuba lagi.</p>
            <button onclick="window.close()">Tutup</button>
        </div>
    </body>
    </html>`;

    return new Response(errorHtml, {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'text/html; charset=utf-8',
      },
    });
  }
});

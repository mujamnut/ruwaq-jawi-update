@echo off
echo 🚀 Deploying Supabase Edge Functions...

echo.
echo 📦 Deploying verify-payment function...
supabase functions deploy verify-payment --no-verify-jwt

echo.
echo 📦 Deploying toyyibpay-webhook function...
supabase functions deploy toyyibpay-webhook --no-verify-jwt

echo.
echo 📦 Deploying direct-activation function...
supabase functions deploy direct-activation --no-verify-jwt

echo.
echo 🔑 Setting environment secrets...
echo Please run these commands manually in your terminal:
echo.
echo supabase secrets set TOYYIBPAY_SECRET_KEY=j82mer37-15g3-zezd-nmq3-hcha3n8gt3xz
echo supabase secrets set TOYYIBPAY_BASE_URL=https://dev.toyyibpay.com
echo.

echo ✅ Deployment completed!
echo.
echo 🔗 Your function URLs:
echo verify-payment: https://ckgxglvozrsognqqkpkk.supabase.co/functions/v1/verify-payment
echo toyyibpay-webhook: https://ckgxglvozrsognqqkpkk.supabase.co/functions/v1/toyyibpay-webhook
echo.
echo 📋 Next steps:
echo 1. Set the webhook URL in ToyyibPay dashboard to: https://ckgxglvozrsognqqkpkk.supabase.co/functions/v1/toyyibpay-webhook
echo 2. Set the redirect URL to: https://ckgxglvozrsognqqkpkk.supabase.co/functions/v1/payment-redirect
echo 3. Test a payment to verify everything works!
pause

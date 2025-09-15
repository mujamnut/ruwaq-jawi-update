# Edge Functions Cleanup Plan

## ✅ **KEEP - Actively Used:**
1. `payment-redirect` - Used for ToyyibPay success/failed redirects
2. `payment-webhook` - ToyyibPay webhook URL in PaymentConfig
3. `verify-payment-hardcoded` - Used in SubscriptionProvider for payment verification
4. `direct-activation-fixed` - **MAIN FUNCTION** - Used in SubscriptionProvider for activation
5. `toyyibpay-webhook` - ToyyibPay callback webhook (updated with notifications)

## ✅ **KEEP - Updated Functions:**
6. `verify-payment` - **NOW USED** in SubscriptionProvider (updated from verify-payment-hardcoded)

## ❌ **DELETE - Unused/Test Functions:**
7. `verify-payment-hardcoded` - **NOW UNUSED** (replaced by verify-payment)
8. `verify-payment-fixed` - Alternative verify function (not needed)
9. `smart-task` - Test function, not used in production
10. `test_payment` - Test function
11. `payment-webhook-fixed` - Duplicate, not called anywhere
12. `webhook-simple` - Test webhook
13. `webhook-no-auth` - Test webhook
14. `manual-subscription` - Not used
15. `direct-activation` - **OLD VERSION** (superseded by direct-activation-fixed)
16. `debug-env-vars` - Debug function only
17. `notification-triggers` - **OBSOLETE** (using SQL functions now)

## Summary:
- **Keep**: 6 functions (actively used)
- **Delete**: 11 functions (unused/test/obsolete)

## Current Flow:
1. User pays → ToyyibPay calls `toyyibpay-webhook` OR `payment-webhook`
2. App calls `direct-activation-fixed` for manual activation
3. App uses `verify-payment` to check payment status
4. `payment-redirect` handles success/failure redirects
5. Notifications now use SQL functions instead of `notification-triggers`

## Delete Command (run in Supabase Dashboard):
```sql
-- Note: Supabase doesn't have direct SQL commands to delete edge functions
-- You need to delete them through the Supabase Dashboard or CLI
```

Functions to delete via Dashboard:
- verify-payment-hardcoded (replaced by verify-payment)
- verify-payment-fixed (not needed)
- smart-task
- test_payment
- payment-webhook-fixed
- webhook-simple
- webhook-no-auth
- manual-subscription
- direct-activation (old version)
- debug-env-vars
- notification-triggers
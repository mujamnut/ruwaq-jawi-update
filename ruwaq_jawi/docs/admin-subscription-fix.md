# Admin Subscription Table Fix

## Problem
Admin screens were failing due to references to the old `user_subscriptions` table which was renamed to `subscriptions` after database migrations.

## Schema Mapping (user_subscriptions → subscriptions)
| Old Field (user_subscriptions) | New Field (subscriptions) | Notes |
|--------------------------------|---------------------------|--------|
| `start_date` | `started_at` | Renamed field |
| `end_date` | `current_period_end` | Renamed field |
| `plan_type` | `plan_id` | Renamed field |
| `payment_method` | `provider` | Renamed field |
| `subscription_plan_id` | `plan_id` | Consolidated |

## Files Fixed
1. **`lib/features/admin/screens/admin_users_screen.dart`**
   - Line 46: `user_subscriptions` → `subscriptions`
   - Line 49: `end_date` → `current_period_end`

2. **`lib/features/admin/screens/admin_dashboard_screen.dart`**
   - Line 55: `user_subscriptions` → `subscriptions`
   - Line 58: `end_date` → `current_period_end`
   - Line 69: `transactions` → `payments` (for pending counts)

3. **`lib/core/providers/subscription_provider.dart`**
   - Line 76: `user_subscriptions` → `subscriptions`
   - Lines 86-93: Updated field mapping for new schema

4. **`lib/core/services/content_service.dart`**
   - Line 15: `user_subscriptions` → `subscriptions`
   - Lines 19-20: `start_date/end_date` → `started_at/current_period_end`
   - Lines 115-120: Updated subscription details query

5. **`lib/core/services/subscription_service.dart`**
   - Removed dual-write to old table
   - Updated all queries to use new schema
   - Lines 152-223: Fixed subscription status checks

## Database Status
- ✅ New `subscriptions` table: 4 records
- ✅ Old `user_subscriptions` table: Removed/renamed to legacy
- ✅ Schema migrations: Complete (migrations 011-013)

## Next Steps
1. Test admin screens to ensure they load without errors
2. Verify subscription data displays correctly
3. Test subscription creation/payment flow
4. Run full regression testing on subscription functionality

## Rollback Plan
If issues occur, temporarily create a view:
```sql
CREATE VIEW user_subscriptions AS 
SELECT 
  id,
  user_id,
  plan_id as subscription_plan_id,
  status,
  started_at as start_date,
  current_period_end as end_date,
  amount,
  currency,
  created_at,
  updated_at
FROM subscriptions;
```

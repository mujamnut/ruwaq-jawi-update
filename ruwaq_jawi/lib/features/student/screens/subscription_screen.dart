import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/payment_provider.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/models/payment_models.dart';
import 'payment_screen.dart';

// Enum for subscription actions
enum SubscriptionAction {
  purchase,     // Can buy (no active subscription)
  upgrade,      // Can upgrade to higher tier
  currentPlan,  // Same as current plan (disabled)
  notAvailable, // Lower tier while active (disabled)
}

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late Future<void> _loadPlansFuture;
  Map<String, dynamic>? _currentSubscription;
  bool _isLoadingSubscription = true;
  
  // Subscription plan hierarchy (1 = lowest, 3 = highest)
  static const Map<String, int> _planTiers = {
    'monthly_basic': 1,
    'monthly_premium': 2,
    'yearly_premium': 3,
  };
  
  static const Map<String, String> _planNames = {
    'monthly_basic': 'Basic Monthly',
    'monthly_premium': 'Premium Monthly', 
    'yearly_premium': 'Premium Annual',
  };

  @override
  void initState() {
    super.initState();
    _loadPlansFuture = _loadSubscriptionPlans();
    _loadCurrentSubscription();
  }

  Future<void> _loadSubscriptionPlans() async {
    final paymentProvider = context.read<PaymentProvider>();
    if (paymentProvider.subscriptionPlans.isEmpty) {
      await paymentProvider.loadSubscriptionPlans();
    }
  }
  
  Future<void> _loadCurrentSubscription() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.user;
      
      if (user != null) {
        final subscriptionService = SubscriptionService(SupabaseService.client);
        final currentSub = await subscriptionService.getUserActiveSubscription(user.id);
        
        if (mounted) {
          setState(() {
            _currentSubscription = currentSub;
            _isLoadingSubscription = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingSubscription = false;
          });
        }
      }
    } catch (e) {
      print('Error loading current subscription: $e');
      if (mounted) {
        setState(() {
          _isLoadingSubscription = false;
        });
      }
    }
  }
  
  // Get current subscription plan ID
  String? get _currentPlanId {
    if (_currentSubscription == null) return null;
    String planId = _currentSubscription!['subscription_plan_id'] ?? _currentSubscription!['plan_type'];
    return _normalizePlanId(planId);
  }
  
  // Normalize plan ID to standard format for comparison
  String _normalizePlanId(String planId) {
    // Convert legacy plan types to new plan IDs
    switch (planId) {
      case '1month':
        return 'monthly_basic';
      case '3month':
        return 'quarterly_premium';
      case '6month':
        return 'semiannual_premium';
      case '12month':
        return 'yearly_premium';
      default:
        return planId; // Already in new format
    }
  }
  
  // Get current plan tier (1-3)
  int get _currentPlanTier {
    final planId = _currentPlanId;
    if (planId == null) return 0; // No subscription
    return _planTiers[planId] ?? 0;
  }
  
  // Check if subscription is still active
  bool get _hasActiveSubscription {
    if (_currentSubscription == null) return false;
    try {
      final endDate = DateTime.parse(_currentSubscription!['end_date']);
      return endDate.isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }
  
  // Check if user can purchase/upgrade to a plan
  SubscriptionAction _getActionForPlan(String planId) {
    // If no active subscription, can buy any plan
    if (!_hasActiveSubscription) {
      print('DEBUG: No active subscription, can purchase $planId');
      return SubscriptionAction.purchase;
    }
    
    final currentTier = _currentPlanTier;
    final targetTier = _planTiers[planId] ?? 0;
    final currentPlanId = _currentPlanId;
    final normalizedTargetPlanId = _normalizePlanId(planId);
    
    print('DEBUG: Current plan: $currentPlanId (tier $currentTier), Target plan: $normalizedTargetPlanId (tier $targetTier)');
    
    // Same plan - cannot purchase again (compare normalized IDs)
    if (normalizedTargetPlanId == currentPlanId) {
      print('DEBUG: Same plan detected - $normalizedTargetPlanId = $currentPlanId');
      return SubscriptionAction.currentPlan;
    }
    
    // Check if it's the same tier but different plan ID (legacy compatibility)
    if (currentTier == targetTier && currentTier > 0) {
      print('DEBUG: Same tier detected - both tier $currentTier');
      return SubscriptionAction.currentPlan;
    }
    
    // Higher tier - can upgrade
    if (targetTier > currentTier) {
      print('DEBUG: Can upgrade from tier $currentTier to $targetTier');
      return SubscriptionAction.upgrade;
    }
    
    // Lower tier - cannot downgrade while active
    print('DEBUG: Cannot downgrade from tier $currentTier to $targetTier');
    return SubscriptionAction.notAvailable;
  }
  
  // Get action message for plan
  String _getActionMessage(String planId) {
    final action = _getActionForPlan(planId);
    switch (action) {
      case SubscriptionAction.purchase:
        return 'Subscribe Now';
      case SubscriptionAction.upgrade:
        return 'Upgrade Now';
      case SubscriptionAction.currentPlan:
        return 'Currently Subscribed ✓';
      case SubscriptionAction.notAvailable:
        return 'Not Available';
    }
  }
  
  // Check if action button should be enabled
  bool _isActionEnabled(String planId) {
    final action = _getActionForPlan(planId);
    return action == SubscriptionAction.purchase || action == SubscriptionAction.upgrade;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Subscription'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Prefer go_router semantics
            if (context.canPop()) {
              context.pop();
            } else {
              // If there's no back stack (e.g., navigated with context.go), send to home
              context.go('/home');
            }
          },
        ),
      ),
      body: FutureBuilder<void>(
        future: _loadPlansFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final paymentProvider = context.read<PaymentProvider>();

          if (paymentProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading plans',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(paymentProvider.error!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _loadPlansFuture = _loadSubscriptionPlans();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Current Subscription Status
              if (_isLoadingSubscription)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_currentSubscription != null)
                _buildCurrentSubscriptionCard(),
              
              const SizedBox(height: 16),
              
              // Subscription Plans Title
              Text(
                _currentSubscription != null 
                    ? 'Upgrade or Extend Plan' 
                    : 'Choose Your Plan',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Subscription Plans
              ...paymentProvider.subscriptionPlans
                  .map((plan) => _buildPlanCard(context, plan))
                  .toList(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCurrentSubscriptionCard() {
    final endDate = DateTime.parse(_currentSubscription!['end_date']);
    final planType = _currentSubscription!['subscription_plan_id'] ?? _currentSubscription!['plan_type'] as String;
    final daysLeft = endDate.difference(DateTime.now()).inDays;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.green[100]!, Colors.green[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.green, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Current Plan: ${_getPlanDisplayName(planType)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Active until: ${endDate.day}/${endDate.month}/${endDate.year}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$daysLeft days remaining',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.green[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _getPlanDisplayName(String planType) {
    // Handle new plan IDs
    if (_planNames.containsKey(planType)) {
      return _planNames[planType]!;
    }
    
    // Handle legacy plan types
    switch (planType) {
      case '1month': return 'Monthly Basic';
      case '3month': return 'Quarterly Premium';
      case '6month': return 'Semi-Annual Premium';
      case '12month': return 'Annual Premium';
      default: return planType;
    }
  }

  Widget _buildPlanCard(BuildContext context, SubscriptionPlan plan) {
    final bool isYearly = plan.durationDays == 365;
    final action = _getActionForPlan(plan.id);
    final isEnabled = _isActionEnabled(plan.id);
    final actionText = _getActionMessage(plan.id);
    
    // Determine card styling based on action
    Color? borderColor;
    List<Color>? gradientColors;
    String? badgeText;
    Color? badgeColor;
    
    switch (action) {
      case SubscriptionAction.currentPlan:
        borderColor = Colors.green[600];
        gradientColors = [Colors.green[200]!, Colors.green[100]!];
        badgeText = '✓ SUBSCRIBED';
        badgeColor = Colors.green[600];
        break;
      case SubscriptionAction.upgrade:
        if (isYearly) {
          borderColor = Colors.amber;
          gradientColors = [Colors.amber[100]!, Colors.amber[50]!];
          badgeText = 'UPGRADE';
          badgeColor = Colors.amber;
        } else {
          badgeText = 'UPGRADE';
          badgeColor = Colors.blue;
        }
        break;
      case SubscriptionAction.purchase:
        if (isYearly) {
          borderColor = Colors.amber;
          gradientColors = [Colors.amber[100]!, Colors.amber[50]!];
          badgeText = 'BEST VALUE';
          badgeColor = Colors.amber;
        }
        break;
      case SubscriptionAction.notAvailable:
        borderColor = Colors.grey[400];
        gradientColors = [Colors.grey[200]!, Colors.grey[100]!];
        badgeText = 'NOT AVAILABLE';
        badgeColor = Colors.grey;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isEnabled ? 4 : 2,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.6,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: gradientColors != null
                ? LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            border: borderColor != null ? Border.all(color: borderColor, width: 2) : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.name,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: action == SubscriptionAction.currentPlan 
                                  ? Colors.green[800] 
                                  : (isYearly ? Colors.amber[800] : null),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            plan.description,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isEnabled ? Colors.grey[600] : Colors.grey[400],
                            ),
                          ),
                          // Add reason for not available
                          if (action == SubscriptionAction.notAvailable)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Cannot downgrade while subscription is active',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.red[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          // Add indication for current plan
                          if (action == SubscriptionAction.currentPlan)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'You are currently subscribed to this plan',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (badgeText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      plan.formattedPrice,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isEnabled 
                            ? Theme.of(context).primaryColor
                            : Colors.grey[500],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '/ ${plan.durationText}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isEnabled ? Colors.grey[600] : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...plan.features.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle, 
                          color: isEnabled ? Colors.green : Colors.grey[400], 
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            feature,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isEnabled ? null : Colors.grey[500],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isEnabled ? () => _selectPlan(context, plan) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getButtonColor(action, isYearly),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      actionText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Color _getButtonColor(SubscriptionAction action, bool isYearly) {
    switch (action) {
      case SubscriptionAction.currentPlan:
        return Colors.green[300]!; // Lighter green to show it's disabled but positive
      case SubscriptionAction.upgrade:
        return isYearly ? Colors.amber : Colors.blue;
      case SubscriptionAction.purchase:
        return isYearly ? Colors.amber : Theme.of(context).primaryColor;
      case SubscriptionAction.notAvailable:
        return Colors.grey;
    }
  }

  String _getPlanTypeFromId(String planId) {
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

  void _selectPlan(BuildContext context, SubscriptionPlan plan) {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login first')));
      return;
    }

    final action = _getActionForPlan(plan.id);
    print('DEBUG: User clicked on plan ${plan.id}, action: $action');
    
    // Extra protection - should not reach here if button is properly disabled
    if (!_isActionEnabled(plan.id)) {
      print('WARNING: User tried to select disabled plan ${plan.id}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This plan is not available for selection'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Handle different actions
    switch (action) {
      case SubscriptionAction.purchase:
        _navigateToPayment(context, plan, user, isPurchase: true);
        break;
        
      case SubscriptionAction.upgrade:
        _showUpgradeConfirmationDialog(context, plan, user);
        break;
        
      case SubscriptionAction.currentPlan:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You are already subscribed to ${plan.name}'),
            backgroundColor: Colors.green[600],
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
        break;
        
      case SubscriptionAction.notAvailable:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot downgrade while subscription is active'),
            backgroundColor: Colors.red,
          ),
        );
        break;
    }
  }
  
  void _showUpgradeConfirmationDialog(BuildContext context, SubscriptionPlan plan, user) {
    final currentPlanId = _currentPlanId;
    final currentPlan = currentPlanId != null ? _getPlanDisplayName(currentPlanId) : 'Unknown';
    final endDate = _currentSubscription != null 
        ? DateTime.parse(_currentSubscription!['end_date'])
        : null;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upgrade Plan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Plan: $currentPlan',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (endDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Valid until: ${endDate.day}/${endDate.month}/${endDate.year}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Upgrading to ${plan.name} will:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text('• Replace your current plan immediately'),
            const Text('• Extend your subscription period'),
            const Text('• Give you access to higher tier features'),
            const SizedBox(height: 16),
            const Text(
              'Do you want to continue?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToPayment(context, plan, user, isPurchase: false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }
  
  void _navigateToPayment(BuildContext context, SubscriptionPlan plan, user, {required bool isPurchase}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          plan: plan,
          userEmail: user.email ?? '',
          userName: user.userMetadata?['full_name'] ?? 'User',
          userPhone: user.phone ?? '',
          userId: user.id,
        ),
      ),
    ).then((_) {
      // Refresh subscription status when returning from payment
      if (mounted) {
        setState(() {
          _isLoadingSubscription = true;
        });
        _loadCurrentSubscription().then((_) {
          // Show success message based on action type
          if (mounted) {
            final message = isPurchase 
                ? 'Subscription activated successfully!'
                : 'Plan upgraded successfully!';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Colors.green,
              ),
            );
          }
        });
      }
    });
  }
}

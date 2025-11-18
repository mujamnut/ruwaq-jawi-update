'use client'

import { useState } from 'react'
import DashboardLayout from "@/components/dashboard-layout"
import {
  useSubscriptions,
  useSubscriptionAnalytics,
  useUpdateSubscriptionStatus,
  useRealTimeSubscriptions
} from "@/hooks"
import { useTestConnection } from "@/hooks/use-test-connection"
import {
  TableLoadingWrapper,
  StatsLoadingWrapper
} from "@/components/ui/loading-wrapper"
import {
  Users,
  CreditCard,
  TrendingUp,
  TrendingDown,
  Calendar,
  Search,
  Filter,
  MoreHorizontal,
  Check,
  X,
  Clock,
  AlertTriangle,
  DollarSign,
  Activity,
  UserCheck
} from 'lucide-react'

function SubscriptionsContent() {
  const [searchTerm, setSearchTerm] = useState('')
  const [statusFilter, setStatusFilter] = useState<string>('all')
  const [selectedSubscription, setSelectedSubscription] = useState<string | null>(null)

  // Test connection
  const { data: connectionTest, isLoading: connectionTestLoading, error: connectionTestError } = useTestConnection()

  // Initialize real-time subscriptions
  useRealTimeSubscriptions()

  // Fetch subscriptions and analytics
  const { data: subscriptions, isLoading: subscriptionsLoading, error: subscriptionsError } = useSubscriptions({
    search: searchTerm || undefined,
    status: statusFilter !== 'all' ? statusFilter : undefined
  })

  const { data: analytics, isLoading: analyticsLoading } = useSubscriptionAnalytics()
  const updateSubscriptionStatus = useUpdateSubscriptionStatus()

  const loading = subscriptionsLoading || analyticsLoading

  const handleStatusUpdate = async (subscriptionId: string, newStatus: string) => {
    try {
      await updateSubscriptionStatus.mutateAsync({
        subscriptionId,
        status: newStatus
      })
    } catch (error) {
      console.error('Failed to update subscription status:', error)
    }
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'active': return 'text-emerald-400 bg-emerald-400/10 border-emerald-400/40'
      case 'trial': return 'text-blue-400 bg-blue-400/10 border-blue-400/40'
      case 'expired': return 'text-red-400 bg-red-400/10 border-red-400/40'
      case 'cancelled': return 'text-gray-600 bg-slate-400/10 border-slate-400/40'
      case 'pending': return 'text-amber-400 bg-amber-400/10 border-amber-400/40'
      default: return 'text-gray-600 bg-slate-400/10 border-slate-400/40'
    }
  }

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'active': return <Check className="w-3 h-3" />
      case 'trial': return <Clock className="w-3 h-3" />
      case 'expired': return <X className="w-3 h-3" />
      case 'cancelled': return <X className="w-3 h-3" />
      case 'pending': return <AlertTriangle className="w-3 h-3" />
      default: return <Clock className="w-3 h-3" />
    }
  }

  // Debug information
  console.log('Page State:', {
    loading,
    subscriptionsLoading,
    analyticsLoading,
    connectionTestLoading,
    subscriptionsCount: subscriptions?.length || 0,
    analytics,
    subscriptionsError,
    connectionTest,
    connectionTestError
  })

  return (
    <DashboardLayout title="Subscriptions" subtitle="User subscription management">
      <div>
  
        {/* Analytics Cards */}
        <StatsLoadingWrapper isLoading={analyticsLoading} error={null} cards={6}>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4 mb-6">
            <div className="card rounded-2xl p-4 border-l-4 border-l-emerald-500 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
              <div className="flex items-center justify-between mb-2">
                <div className="p-2 rounded-xl bg-emerald-500/10 border border-emerald-500/40">
                  <UserCheck className="w-4 h-4 text-emerald-400" />
                </div>
                <span className="flex items-center gap-1 text-xs text-emerald-300 dark:text-emerald-400">
                  <TrendingUp className="w-3 h-3" />
                  +12%
                </span>
              </div>
              <h3 className="text-xl font-bold mb-1 text-gray-900 dark:text-white">{analytics?.activeSubscriptions || 0}</h3>
              <p className="text-xs text-gray-600 dark:text-gray-400">Active</p>
            </div>

            <div className="card rounded-2xl p-4 border-l-4 border-l-blue-500 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
              <div className="flex items-center justify-between mb-2">
                <div className="p-2 rounded-xl bg-blue-500/10 border border-blue-500/40">
                  <Clock className="w-4 h-4 text-blue-400" />
                </div>
                <span className="flex items-center gap-1 text-xs text-blue-300 dark:text-blue-400">
                  <TrendingUp className="w-3 h-3" />
                  +8%
                </span>
              </div>
              <h3 className="text-xl font-bold mb-1 text-gray-900 dark:text-white">{analytics?.trialSubscriptions || 0}</h3>
              <p className="text-xs text-gray-600 dark:text-gray-400">Trial</p>
            </div>

            <div className="card rounded-2xl p-4 border-l-4 border-l-red-500 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
              <div className="flex items-center justify-between mb-2">
                <div className="p-2 rounded-xl bg-red-500/10 border border-red-500/40">
                  <X className="w-4 h-4 text-red-400" />
                </div>
                <span className="flex items-center gap-1 text-xs text-red-300 dark:text-red-400">
                  <TrendingDown className="w-3 h-3" />
                  -5%
                </span>
              </div>
              <h3 className="text-xl font-bold mb-1 text-gray-900 dark:text-white">{analytics?.cancelledSubscriptions || 0}</h3>
              <p className="text-xs text-gray-600 dark:text-gray-400">Cancelled</p>
            </div>

            <div className="card rounded-2xl p-4 border-l-4 border-l-purple-500 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
              <div className="flex items-center justify-between mb-2">
                <div className="p-2 rounded-xl bg-purple-500/10 border border-purple-500/40">
                  <DollarSign className="w-4 h-4 text-purple-400" />
                </div>
                <span className="flex items-center gap-1 text-xs text-purple-300 dark:text-purple-400">
                  <TrendingUp className="w-3 h-3" />
                  +18%
                </span>
              </div>
              <h3 className="text-xl font-bold mb-1 text-gray-900 dark:text-white">${analytics?.mrr?.toFixed(0) || '0'}</h3>
              <p className="text-xs text-gray-600 dark:text-gray-400">MRR</p>
            </div>

            <div className="card rounded-2xl p-4 border-l-4 border-l-amber-500 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
              <div className="flex items-center justify-between mb-2">
                <div className="p-2 rounded-xl bg-amber-500/10 border border-amber-500/40">
                  <Activity className="w-4 h-4 text-amber-400" />
                </div>
                <span className="flex items-center gap-1 text-xs text-amber-300 dark:text-amber-400">
                  <TrendingDown className="w-3 h-3" />
                  {analytics?.churnRate?.toFixed(1) || '0'}%
                </span>
              </div>
              <h3 className="text-xl font-bold mb-1 text-gray-900 dark:text-white">{analytics?.churnRate?.toFixed(1) || '0'}%</h3>
              <p className="text-xs text-gray-600 dark:text-gray-400">Churn Rate</p>
            </div>

            <div className="card rounded-2xl p-4 border-l-4 border-l-indigo-500 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
              <div className="flex items-center justify-between mb-2">
                <div className="p-2 rounded-md bg-indigo-100 dark:bg-indigo-500/10 border border-indigo-300 dark:border-indigo-500/40">
                  <TrendingUp className="w-4 h-4 text-indigo-600 dark:text-indigo-400" />
                </div>
                <span className="flex items-center gap-1 text-xs text-indigo-600 dark:text-indigo-400">
                  <TrendingUp className="w-3 h-3" />
                  +{analytics?.newSubscriptionsThisMonth || 0}
                </span>
              </div>
              <h3 className="text-xl font-bold mb-1 text-gray-900 dark:text-white">{analytics?.newSubscriptionsThisMonth || 0}</h3>
              <p className="text-xs text-gray-600 dark:text-gray-400">New This Month</p>
            </div>
          </div>
        </StatsLoadingWrapper>

        {/* Filters */}
        <div className="flex flex-col sm:flex-row gap-4 mb-6">
          <div className="flex-1 relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-600 dark:text-gray-400" />
            <input
              type="text"
              placeholder="Search by name or email..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-10 pr-4 py-2 rounded-md bg-white/80 dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
          <div className="flex gap-2">
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              className="px-4 py-2 rounded-md bg-white/80 dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white"
            >
              <option value="all">All Status</option>
              <option value="active">Active</option>
              <option value="trial">Trial</option>
              <option value="expired">Expired</option>
              <option value="cancelled">Cancelled</option>
              <option value="pending">Pending</option>
            </select>
          </div>
        </div>

        {/* Subscriptions Table */}
        <TableLoadingWrapper isLoading={subscriptionsLoading} error={subscriptionsError}>
          <div className="card rounded-2xl overflow-hidden bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-gray-200 dark:border-slate-600">
                    <th className="text-left p-4 text-xs font-medium text-gray-700 dark:text-gray-300 uppercase tracking-wider">User</th>
                    <th className="text-left p-4 text-xs font-medium text-gray-700 dark:text-gray-300 uppercase tracking-wider">Plan</th>
                    <th className="text-left p-4 text-xs font-medium text-gray-700 dark:text-gray-300 uppercase tracking-wider">Status</th>
                    <th className="text-left p-4 text-xs font-medium text-gray-700 dark:text-gray-300 uppercase tracking-wider">Start Date</th>
                    <th className="text-left p-4 text-xs font-medium text-gray-700 dark:text-gray-300 uppercase tracking-wider">End Date</th>
                    <th className="text-left p-4 text-xs font-medium text-gray-700 dark:text-gray-300 uppercase tracking-wider">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200 dark:divide-slate-600">
                  {subscriptions?.map((subscription: any) => (
                    <tr key={subscription.id} className="hover:bg-gray-50 dark:hover:bg-slate-700/50 transition-colors">
                      <td className="p-4">
                        <div>
                          <p className="text-sm font-medium text-gray-900 dark:text-white">
                            {subscription.auth?.users?.full_name || subscription.auth?.users?.name || 'Unknown User'}
                          </p>
                          <p className="text-xs text-gray-600 dark:text-gray-400">
                            {subscription.auth?.users?.email || 'No email'}
                          </p>
                        </div>
                      </td>
                      <td className="p-4">
                        <div>
                          <p className="text-sm font-medium text-gray-900 dark:text-white">
                            {subscription.subscription_plans?.name || 'Unknown Plan'}
                          </p>
                          <p className="text-xs text-gray-600 dark:text-gray-400">
                            ${subscription.subscription_plans?.price || '0'}/{subscription.subscription_plans?.duration_days >= 365 ? 'year' : 'month'}
                          </p>
                        </div>
                      </td>
                      <td className="p-4">
                        <span className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-[10px] font-medium border ${getStatusColor(subscription.status)}`}>
                          {getStatusIcon(subscription.status)}
                          {subscription.status}
                        </span>
                      </td>
                      <td className="p-4">
                        <p className="text-sm text-gray-900 dark:text-white">
                          {new Date(subscription.start_date).toLocaleDateString()}
                        </p>
                      </td>
                      <td className="p-4">
                        <p className="text-sm text-gray-900 dark:text-white">
                          {new Date(subscription.end_date).toLocaleDateString()}
                        </p>
                      </td>
                      <td className="p-4">
                        <div className="flex items-center gap-2">
                          {subscription.status === 'active' && (
                            <button
                              onClick={() => handleStatusUpdate(subscription.id, 'cancelled')}
                              className="p-1.5 rounded-lg bg-red-500/10 border border-red-500/40 text-red-400 hover:bg-red-500/20 transition-colors dark:hover:bg-red-500/30"
                              title="Cancel Subscription"
                            >
                              <X className="w-3 h-3" />
                            </button>
                          )}
                          {(subscription.status === 'expired' || subscription.status === 'cancelled') && (
                            <button
                              onClick={() => handleStatusUpdate(subscription.id, 'active')}
                              className="p-1.5 rounded-lg bg-emerald-500/10 border border-emerald-500/40 text-emerald-400 hover:bg-emerald-500/20 transition-colors dark:hover:bg-emerald-500/30"
                              title="Reactivate Subscription"
                            >
                              <Check className="w-3 h-3" />
                            </button>
                          )}
                          <button className="p-1.5 rounded-lg bg-gray-100/80 border border-gray-300/80 text-gray-600 hover:bg-gray-100 transition-colors dark:bg-slate-700/50 dark:border-slate-600 dark:text-gray-400 dark:hover:bg-slate-700">
                            <MoreHorizontal className="w-3 h-3" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </TableLoadingWrapper>
      </div>
    </DashboardLayout>
  )
}

export default function SubscriptionsPage() {
  return <SubscriptionsContent />
}
'use client'

import { useState } from 'react'
import DashboardLayout from "@/components/dashboard-layout"
import {
  useSubscriptionPlans,
  useSubscriptionAnalytics
} from "@/hooks"
import {
  TableLoadingWrapper,
  StatsLoadingWrapper
} from "@/components/ui/loading-wrapper"
import {
  CreditCard,
  DollarSign,
  Plus,
  Edit,
  Trash2,
  ChevronLeft,
  ChevronRight,
  Star,
  Check,
  X,
  Calendar,
  Users,
  TrendingUp
} from 'lucide-react'

function SubscriptionPlansContent() {
  const [showCreateModal, setShowCreateModal] = useState(false)

  // Fetch subscription plans and analytics
  const { data: plans, isLoading: plansLoading, refetch: refetchPlans } = useSubscriptionPlans()
  const { data: analytics, isLoading: analyticsLoading } = useSubscriptionAnalytics()

  const loading = plansLoading || analyticsLoading

  const handleTogglePlan = async (planId: string, isActive: boolean) => {
    // This would typically call an API to update the plan status
    console.log(`Toggling plan ${planId} to ${!isActive}`)
    // await updatePlanStatus(planId, !isActive)
    // refetchPlans()
  }

  const handleDeletePlan = async (planId: string) => {
    if (confirm('Are you sure you want to delete this subscription plan?')) {
      console.log(`Deleting plan ${planId}`)
      // await deletePlan(planId)
      // refetchPlans()
    }
  }

  const getBillingIntervalColor = (durationDays: number) => {
    return durationDays >= 365
      ? 'text-purple-400 bg-purple-400/10 border-purple-400/40'
      : 'text-blue-400 bg-blue-400/10 border-blue-400/40'
  }

  const getBillingIntervalText = (durationDays: number) => {
    return durationDays >= 365 ? 'year' : 'month'
  }

  const formatPrice = (price: number, currency: string = 'USD') => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: currency,
      minimumFractionDigits: 2
    }).format(price)
  }

  const headerExtra = (
    <button
      onClick={() => setShowCreateModal(true)}
      className="flex items-center gap-2 px-4 py-2 rounded-xl bg-gradient-to-r from-blue-600 to-indigo-600 text-white text-xs font-medium hover:from-blue-700 hover:to-indigo-700 transition-all shadow-lg"
    >
      <Plus className="w-4 h-4" />
      Create Plan
    </button>
  )

  return (
    <DashboardLayout
      title="Subscription Plans"
      subtitle="Subscription plan configuration"
      headerExtra={headerExtra}
    >
      <div>
        {/* Analytics Cards */}
        <StatsLoadingWrapper isLoading={analyticsLoading} error={null} cards={4}>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
            <div className="card rounded-2xl p-4 border-l-4 border-l-emerald-500 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
              <div className="flex items-center justify-between mb-2">
                <div className="p-2 rounded-xl bg-emerald-500/10 border border-emerald-500/40">
                  <CreditCard className="w-4 h-4 text-emerald-400" />
                </div>
                <span className="flex items-center gap-1 text-xs text-emerald-300 dark:text-emerald-400">
                  <Users className="w-3 h-3" />
                  Active
                </span>
              </div>
              <h3 className="text-xl font-bold mb-1 text-gray-900 dark:text-white">{analytics?.activeSubscriptions || 0}</h3>
              <p className="text-xs text-gray-600 dark:text-gray-400">Total Plans</p>
            </div>

            <div className="card rounded-2xl p-4 border-l-4 border-l-blue-500 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
              <div className="flex items-center justify-between mb-2">
                <div className="p-2 rounded-xl bg-blue-500/10 border border-blue-500/40">
                  <DollarSign className="w-4 h-4 text-blue-400" />
                </div>
                <span className="flex items-center gap-1 text-xs text-blue-300 dark:text-blue-400">
                  <TrendingUp className="w-3 h-3" />
                  MRR
                </span>
              </div>
              <h3 className="text-xl font-bold mb-1 text-gray-900 dark:text-white">${analytics?.mrr.toFixed(0) || '0'}</h3>
              <p className="text-xs text-gray-600 dark:text-gray-400">Monthly Revenue</p>
            </div>

            <div className="card rounded-2xl p-4 border-l-4 border-l-purple-500 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
              <div className="flex items-center justify-between mb-2">
                <div className="p-2 rounded-xl bg-purple-500/10 border border-purple-500/40">
                  <Calendar className="w-4 h-4 text-purple-400" />
                </div>
                <span className="flex items-center gap-1 text-xs text-purple-300 dark:text-purple-400">
                  <Star className="w-3 h-3" />
                  Annual
                </span>
              </div>
              <h3 className="text-xl font-bold mb-1 text-gray-900 dark:text-white">${analytics?.arr.toFixed(0) || '0'}</h3>
              <p className="text-xs text-gray-600 dark:text-gray-400">Annual Revenue</p>
            </div>

            <div className="card rounded-2xl p-4 border-l-4 border-l-amber-500 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
              <div className="flex items-center justify-between mb-2">
                <div className="p-2 rounded-xl bg-amber-500/10 border border-amber-500/40">
                  <Users className="w-4 h-4 text-amber-400" />
                </div>
                <span className="flex items-center gap-1 text-xs text-amber-300 dark:text-amber-400">
                  <TrendingUp className="w-3 h-3" />
                  +{analytics?.newSubscriptionsThisMonth || 0}
                </span>
              </div>
              <h3 className="text-xl font-bold mb-1 text-gray-900 dark:text-white">{analytics?.newSubscriptionsThisMonth || 0}</h3>
              <p className="text-xs text-gray-600 dark:text-gray-400">New This Month</p>
            </div>
          </div>
        </StatsLoadingWrapper>

          {/* Subscription Plans Table */}
        <TableLoadingWrapper isLoading={plansLoading} error={null}>
          <div className="card rounded-2xl overflow-hidden bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-gray-200 dark:border-slate-600">
                    <th className="text-left p-4 text-xs font-medium text-gray-700 dark:text-gray-300 uppercase tracking-wider">Plan</th>
                    <th className="text-left p-4 text-xs font-medium text-gray-700 dark:text-gray-300 uppercase tracking-wider">Price</th>
                    <th className="text-left p-4 text-xs font-medium text-gray-700 dark:text-gray-300 uppercase tracking-wider">Billing</th>
                    <th className="text-left p-4 text-xs font-medium text-gray-700 dark:text-gray-300 uppercase tracking-wider">Features</th>
                    <th className="text-left p-4 text-xs font-medium text-gray-700 dark:text-gray-300 uppercase tracking-wider">Status</th>
                    <th className="text-left p-4 text-xs font-medium text-gray-700 dark:text-gray-300 uppercase tracking-wider">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200 dark:divide-slate-600">
                  {plans?.map((plan: any) => (
                    <tr key={plan.id} className="hover:bg-gray-50 dark:hover:bg-slate-700/50 transition-colors">
                      <td className="p-4">
                        <div>
                          <p className="text-sm font-medium text-gray-900 dark:text-white">{plan.name}</p>
                          <p className="text-xs text-gray-600 dark:text-gray-400 mt-1">{plan.description}</p>
                        </div>
                      </td>
                      <td className="p-4">
                        <div className="flex items-center gap-2">
                          <span className="text-lg font-bold text-gray-900 dark:text-white">
                            {formatPrice(plan.price, plan.currency)}
                          </span>
                        </div>
                      </td>
                      <td className="p-4">
                        <span className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-[10px] font-medium border ${getBillingIntervalColor(plan.duration_days)}`}>
                          {getBillingIntervalText(plan.duration_days)}
                        </span>
                      </td>
                      <td className="p-4">
                        <div className="max-w-xs">
                          <div className="flex flex-wrap gap-1">
                            {plan.features?.slice(0, 3).map((feature: string, index: number) => (
                              <span key={index} className="inline-flex items-center gap-1 px-2 py-1 rounded bg-gray-100 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-[10px] text-gray-700 dark:text-gray-300">
                                <Check className="w-2 h-2" />
                                {feature}
                              </span>
                            ))}
                            {plan.features?.length > 3 && (
                              <span className="text-xs text-gray-600 dark:text-gray-400">
                                +{plan.features.length - 3} more
                              </span>
                            )}
                          </div>
                        </div>
                      </td>
                      <td className="p-4">
                        <button
                          onClick={() => handleTogglePlan(plan.id, plan.is_active)}
                          className="flex items-center gap-2"
                        >
                          {plan.is_active ? (
                            <div className="flex items-center gap-1 text-emerald-400 dark:text-emerald-400">
                              <ChevronRight className="w-5 h-5" />
                              <span className="text-xs">Active</span>
                            </div>
                          ) : (
                            <div className="flex items-center gap-1 text-gray-600 dark:text-gray-400">
                              <ChevronLeft className="w-5 h-5" />
                              <span className="text-xs">Inactive</span>
                            </div>
                          )}
                        </button>
                      </td>
                      <td className="p-4">
                        <div className="flex items-center gap-2">
                          <button className="p-1.5 rounded-lg bg-blue-500/10 border border-blue-500/40 text-blue-400 hover:bg-blue-500/20 transition-colors dark:hover:bg-blue-500/30">
                            <Edit className="w-3 h-3" />
                          </button>
                          <button
                            onClick={() => handleDeletePlan(plan.id)}
                            className="p-1.5 rounded-lg bg-red-500/10 border border-red-500/40 text-red-400 hover:bg-red-500/20 transition-colors dark:hover:bg-red-500/30"
                          >
                            <Trash2 className="w-3 h-3" />
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

          {/* Create Plan Modal */}
        {showCreateModal && (
          <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50">
            <div className="card rounded-2xl p-6 w-full max-w-md mx-4 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-lg">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-semibold text-gray-900 dark:text-white">Create Subscription Plan</h3>
                <button
                  onClick={() => setShowCreateModal(false)}
                  className="p-2 rounded-lg bg-gray-100 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-slate-600 transition-colors"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>

              <div className="space-y-4">
                <div>
                  <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-1">Plan Name</label>
                  <input
                    type="text"
                    placeholder="e.g., Premium Plan"
                    className="w-full px-3 py-2 rounded-lg bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
                  />
                </div>

                <div>
                  <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-1">Description</label>
                  <textarea
                    placeholder="Plan description..."
                    rows={3}
                    className="w-full px-3 py-2 rounded-lg bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
                  />
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-1">Price</label>
                    <input
                      type="number"
                      placeholder="9.99"
                      className="w-full px-3 py-2 rounded-lg bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-1">Billing</label>
                    <select className="w-full px-3 py-2 rounded-lg bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white">
                      <option value="month">Monthly</option>
                      <option value="year">Yearly</option>
                    </select>
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-1">Features (one per line)</label>
                  <textarea
                    placeholder="Unlimited access&#10;Premium content&#10;No ads"
                    rows={4}
                    className="w-full px-3 py-2 rounded-lg bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
                  />
                </div>
              </div>

              <div className="flex gap-3 mt-6">
                <button
                  onClick={() => setShowCreateModal(false)}
                  className="flex-1 px-4 py-2 rounded-lg bg-gray-100 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-slate-600 transition-colors"
                >
                  Cancel
                </button>
                <button className="flex-1 px-4 py-2 rounded-lg bg-gradient-to-r from-blue-600 to-indigo-600 text-white font-medium hover:from-blue-700 hover:to-indigo-700 transition-all">
                  Create Plan
                </button>
              </div>
            </div>
          </div>
        )}
    </DashboardLayout>
  )
}

export default function SubscriptionPlansPage() {
  return <SubscriptionPlansContent />
}
'use client'

import { useState } from 'react'
import DashboardLayout from "@/components/dashboard-layout"
import {
  usePayments,
  useSubscriptionAnalytics,
  useRealTimeSubscriptions
} from "@/hooks"
import {
  TableLoadingWrapper,
  StatsLoadingWrapper
} from "@/components/ui/loading-wrapper"
import {
  CreditCard,
  DollarSign,
  TrendingUp,
  TrendingDown,
  Calendar,
  Search,
  Funnel,
  Download,
  Check,
  X,
  Clock,
  AlertTriangle,
  RotateCw,
  ArrowUpRight,
  ArrowDownRight
} from 'lucide-react'

function PaymentsContent() {
  const [searchTerm, setSearchTerm] = useState('')
  const [statusFilter, setStatusFilter] = useState<string>('all')
  const [dateFilter, setDateFilter] = useState<string>('all')

  // Initialize real-time subscriptions
  useRealTimeSubscriptions()

  const getDateRange = (range: string) => {
    const now = new Date()
    switch (range) {
      case 'today':
        return {
          from: now.toISOString().split('T')[0],
          to: now.toISOString().split('T')[0]
        }
      case 'week':
        const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000)
        return {
          from: weekAgo.toISOString().split('T')[0],
          to: now.toISOString().split('T')[0]
        }
      case 'month':
        const monthAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000)
        return {
          from: monthAgo.toISOString().split('T')[0],
          to: now.toISOString().split('T')[0]
        }
      default:
        return { from: '', to: '' }
    }
  }

  // Fetch payments and analytics
  const { data: payments, isLoading: paymentsLoading } = usePayments({
    search: searchTerm || undefined,
    status: statusFilter !== 'all' ? statusFilter : undefined,
    date_from: dateFilter !== 'all' ? getDateRange(dateFilter).from : undefined,
    date_to: dateFilter !== 'all' ? getDateRange(dateFilter).to : undefined
  })

  const { data: analytics, isLoading: analyticsLoading } = useSubscriptionAnalytics()

  const loading = paymentsLoading || analyticsLoading

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'completed': return 'text-emerald-400 bg-emerald-400/10 border-emerald-400/40'
      case 'pending': return 'text-amber-400 bg-amber-400/10 border-amber-400/40'
      case 'failed': return 'text-red-400 bg-red-400/10 border-red-400/40'
      case 'refunded': return 'text-blue-400 bg-blue-400/10 border-blue-400/40'
      case 'partially_refunded': return 'text-purple-400 bg-purple-400/10 border-purple-400/40'
      default: return 'text-gray-600 bg-slate-400/10 border-slate-400/40'
    }
  }

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'completed': return <Check className="w-3 h-3" />
      case 'pending': return <Clock className="w-3 h-3" />
      case 'failed': return <X className="w-3 h-3" />
      case 'refunded': return <RotateCw className="w-3 h-3" />
      case 'partially_refunded': return <ArrowDownRight className="w-3 h-3" />
      default: return <AlertTriangle className="w-3 h-3" />
    }
  }

  const getPaymentMethodIcon = (provider: string) => {
    switch (provider?.toLowerCase()) {
      case 'stripe': return <CreditCard className="w-4 h-4" />
      case 'paypal': return <DollarSign className="w-4 h-4" />
      case 'toyyibpay': return <ArrowUpRight className="w-4 h-4" />
      case 'manual': return <DollarSign className="w-4 h-4" />
      default: return <CreditCard className="w-4 h-4" />
    }
  }

  const totalRevenue = analytics?.totalRevenue || 0
  const monthlyRevenue = analytics?.monthlyRevenue || 0
  const completedPayments = payments?.filter(p => p.status === 'completed').length || 0
  const pendingPayments = payments?.filter(p => p.status === 'pending').length || 0

  return (
    <DashboardLayout title="Payments" subtitle="Payment transaction history">
      <div>
        {/* Analytics Cards */}
        <StatsLoadingWrapper isLoading={analyticsLoading} error={null} cards={4}>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
            <div className="card rounded-2xl p-4 border-l-4 border-l-emerald-500 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
              <div className="flex items-center justify-between mb-2">
                <div className="p-2 rounded-xl bg-emerald-500/10 border border-emerald-500/40">
                  <DollarSign className="w-4 h-4 text-emerald-400" />
                </div>
                <span className="flex items-center gap-1 text-xs text-emerald-300 dark:text-emerald-400">
                  <TrendingUp className="w-3 h-3" />
                  +15%
                </span>
              </div>
              <h3 className="text-xl font-bold mb-1 text-gray-900 dark:text-white">${totalRevenue.toFixed(2)}</h3>
              <p className="text-xs text-gray-600 dark:text-gray-400">Total Revenue</p>
            </div>

            <div className="card rounded-2xl p-4 border-l-4 border-l-blue-500 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
              <div className="flex items-center justify-between mb-2">
                <div className="p-2 rounded-xl bg-blue-500/10 border border-blue-500/40">
                  <Calendar className="w-4 h-4 text-blue-400" />
                </div>
                <span className="flex items-center gap-1 text-xs text-blue-300 dark:text-blue-400">
                  <TrendingUp className="w-3 h-3" />
                  +22%
                </span>
              </div>
              <h3 className="text-xl font-bold mb-1 text-gray-900 dark:text-white">${monthlyRevenue.toFixed(2)}</h3>
              <p className="text-xs text-gray-600 dark:text-gray-400">This Month</p>
            </div>

            <div className="card rounded-2xl p-4 border-l-4 border-l-amber-500 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
              <div className="flex items-center justify-between mb-2">
                <div className="p-2 rounded-xl bg-amber-500/10 border border-amber-500/40">
                  <Check className="w-4 h-4 text-amber-400" />
                </div>
                <span className="flex items-center gap-1 text-xs text-amber-300 dark:text-amber-400">
                  <TrendingUp className="w-3 h-3" />
                  +8%
                </span>
              </div>
              <h3 className="text-xl font-bold mb-1 text-gray-900 dark:text-white">{completedPayments}</h3>
              <p className="text-xs text-gray-600 dark:text-gray-400">Completed</p>
            </div>

            <div className="card rounded-2xl p-4 border-l-4 border-l-orange-500 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
              <div className="flex items-center justify-between mb-2">
                <div className="p-2 rounded-xl bg-orange-500/10 border border-orange-500/40">
                  <Clock className="w-4 h-4 text-orange-400" />
                </div>
                <span className="flex items-center gap-1 text-xs text-orange-300 dark:text-orange-400">
                  <AlertTriangle className="w-3 h-3" />
                  {pendingPayments}
                </span>
              </div>
              <h3 className="text-xl font-bold mb-1 text-gray-900 dark:text-white">{pendingPayments}</h3>
              <p className="text-xs text-gray-600 dark:text-gray-400">Pending</p>
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
              className="w-full pl-10 pr-4 py-2 rounded-xl bg-white/80 dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
          <div className="flex gap-2">
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              className="px-4 py-2 rounded-xl bg-white/80 dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white"
            >
              <option value="all">All Status</option>
              <option value="completed">Completed</option>
              <option value="pending">Pending</option>
              <option value="failed">Failed</option>
              <option value="refunded">Refunded</option>
              <option value="partially_refunded">Partially Refunded</option>
            </select>
            <select
              value={dateFilter}
              onChange={(e) => setDateFilter(e.target.value)}
              className="px-4 py-2 rounded-xl bg-white/80 dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white"
            >
              <option value="all">All Time</option>
              <option value="today">Today</option>
              <option value="week">This Week</option>
              <option value="month">This Month</option>
            </select>
            <button className="px-4 py-2 rounded-xl bg-blue-600/20 border border-blue-500/40 text-blue-600 dark:text-blue-300 hover:bg-blue-600/30 transition-colors flex items-center gap-2">
              <Download className="w-4 h-4" />
              Export
            </button>
          </div>
        </div>

          {/* Payments Table */}
        <TableLoadingWrapper isLoading={paymentsLoading} error={null}>
          <div className="card rounded-2xl overflow-hidden bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-gray-200 dark:border-slate-600">
                    <th className="text-left p-4 text-xs font-medium text-gray-700 dark:text-gray-300 uppercase tracking-wider">Date</th>
                    <th className="text-left p-4 text-xs font-medium text-gray-700 dark:text-gray-300 uppercase tracking-wider">User</th>
                    <th className="text-left p-4 text-xs font-medium text-gray-700 dark:text-gray-300 uppercase tracking-wider">Amount</th>
                    <th className="text-left p-4 text-xs font-medium text-gray-700 dark:text-gray-300 uppercase tracking-wider">Method</th>
                    <th className="text-left p-4 text-xs font-medium text-gray-700 dark:text-gray-300 uppercase tracking-wider">Status</th>
                    <th className="text-left p-4 text-xs font-medium text-gray-700 dark:text-gray-300 uppercase tracking-wider">Description</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200 dark:divide-slate-600">
                  {payments?.map((payment: any) => (
                    <tr key={payment.id} className="hover:bg-gray-50 dark:hover:bg-slate-700/50 transition-colors">
                      <td className="p-4">
                        <div>
                          <p className="text-sm text-gray-900 dark:text-white">
                            {new Date(payment.created_at).toLocaleDateString()}
                          </p>
                          <p className="text-xs text-gray-600 dark:text-gray-400">
                            {new Date(payment.created_at).toLocaleTimeString()}
                          </p>
                        </div>
                      </td>
                      <td className="p-4">
                        <div>
                          <p className="text-sm font-medium text-gray-900 dark:text-white">
                            {payment.profiles?.full_name || 'Unknown User'}
                          </p>
                          <p className="text-xs text-gray-600 dark:text-gray-400">
                            {payment.profiles?.email || 'No email'}
                          </p>
                        </div>
                      </td>
                      <td className="p-4">
                        <div className="flex items-center gap-2">
                          <span className="text-sm font-semibold text-gray-900 dark:text-white">
                            ${(payment.amount_cents / 100).toFixed(2)}
                          </span>
                          <span className="text-xs text-gray-600 dark:text-gray-400 uppercase">
                            {payment.currency}
                          </span>
                        </div>
                      </td>
                      <td className="p-4">
                        <div className="flex items-center gap-2">
                          <div className="text-gray-600 dark:text-gray-400">
                            {getPaymentMethodIcon(payment.provider)}
                          </div>
                          <span className="text-sm text-gray-900 dark:text-white capitalize">
                            {payment.provider || 'Unknown'}
                          </span>
                        </div>
                      </td>
                      <td className="p-4">
                        <span className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-[10px] font-medium border ${getStatusColor(payment.status)}`}>
                          {getStatusIcon(payment.status)}
                          {payment.status?.replace('_', ' ')}
                        </span>
                      </td>
                      <td className="p-4">
                        <p className="text-sm text-gray-900 dark:text-white max-w-xs truncate">
                          {payment.description || 'Payment transaction'}
                        </p>
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

export default function PaymentsPage() {
  return <PaymentsContent />
}
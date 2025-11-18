'use client'

import { useState } from 'react'
import {
  TrendingUp,
  TrendingDown,
  BarChart3,
  Activity,
  Users,
  BookOpen,
  Video,
  CreditCard,
  DollarSign,
  Calendar,
  Download,
  RotateCw,
  ArrowRight,
  ArrowUp,
  ArrowDown,
  Minus,
  Copy,
  Eye
} from 'lucide-react'

interface ComparisonData {
  current: {
    totalUsers: number
    totalContent: number
    totalViews: number
    totalRevenue: number
    avgRating: number
    engagementRate: number
    conversionRate: number
    activeUsers: number
  }
  previous: {
    totalUsers: number
    totalContent: number
    totalViews: number
    totalRevenue: number
    avgRating: number
    engagementRate: number
    conversionRate: number
    activeUsers: number
  }
}

interface ComparisonCardProps {
  title: string
  current: number
  previous: number
  format?: 'number' | 'currency' | 'percentage' | 'duration'
  icon: React.ReactNode
  showTrend?: boolean
}

function ComparisonCard({ title, current, previous, format = 'number', icon, showTrend = true }: ComparisonCardProps) {
  const change = previous > 0 ? ((current - previous) / previous) * 100 : 0
  const isPositive = change > 0
  const isNeutral = change === 0

  const formatValue = (value: number) => {
    switch (format) {
      case 'currency':
        return `$${value.toLocaleString()}`
      case 'percentage':
        return `${value.toFixed(1)}%`
      case 'duration':
        return `${value}s`
      default:
        return value.toLocaleString()
    }
  }

  const getTrendIcon = () => {
    if (isNeutral) return <Minus className="w-4 h-4 text-gray-600" />
    if (isPositive) return <ArrowUp className="w-4 h-4 text-emerald-400" />
    return <ArrowDown className="w-4 h-4 text-red-400" />
  }

  const getTrendColor = () => {
    if (isNeutral) return 'text-gray-600 bg-slate-400/10 border-slate-400/40'
    if (isPositive) return 'text-emerald-400 bg-emerald-400/10 border-emerald-400/40'
    return 'text-red-400 bg-red-400/10 border-red-400/40'
  }

  return (
    <div className="bg-white/50 border border-gray-300/50 rounded-xl p-4">
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2">
          <div className="p-2 rounded-lg bg-gray-100/50">
            {icon}
          </div>
          <h4 className="text-sm font-medium text-gray-700">{title}</h4>
        </div>
        {showTrend && (
          <div className={`flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium border ${getTrendColor()}`}>
            {getTrendIcon()}
            {Math.abs(change).toFixed(1)}%
          </div>
        )}
      </div>

      <div className="space-y-2">
        <div className="flex items-end justify-between">
          <div>
            <p className="text-2xl font-bold text-gray-900">
              {formatValue(current)}
            </p>
            <p className="text-xs text-gray-500">Current Period</p>
          </div>
        </div>

        <div className="pt-2 border-t border-gray-300/30">
          <div className="flex items-end justify-between">
            <div>
              <p className="text-lg font-medium text-gray-600">
                {formatValue(previous)}
              </p>
              <p className="text-xs text-gray-500">Previous Period</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

interface DataComparisonProps {
  data: ComparisonData
  currentPeriod: string
  previousPeriod: string
  onExport?: () => void
  onRefresh?: () => void
  isLoading?: boolean
}

export default function DataComparison({
  data,
  currentPeriod,
  previousPeriod,
  onExport,
  onRefresh,
  isLoading = false
}: DataComparisonProps) {
  const [activeTab, setActiveTab] = useState<'overview' | 'detailed' | 'insights'>('overview')

  const keyMetrics = [
    {
      title: 'Total Users',
      current: data.current.totalUsers,
      previous: data.previous.totalUsers,
      icon: <Users className="w-4 h-4 text-blue-400" />
    },
    {
      title: 'Total Content',
      current: data.current.totalContent,
      previous: data.previous.totalContent,
      icon: <BookOpen className="w-4 h-4 text-green-400" />
    },
    {
      title: 'Total Views',
      current: data.current.totalViews,
      previous: data.previous.totalViews,
      icon: <Eye className="w-4 h-4 text-purple-400" />
    },
    {
      title: 'Total Revenue',
      current: data.current.totalRevenue,
      previous: data.previous.totalRevenue,
      format: 'currency' as const,
      icon: <DollarSign className="w-4 h-4 text-emerald-400" />
    },
    {
      title: 'Avg Rating',
      current: data.current.avgRating,
      previous: data.previous.avgRating,
      format: 'number' as const,
      icon: <Activity className="w-4 h-4 text-amber-400" />
    },
    {
      title: 'Engagement Rate',
      current: data.current.engagementRate,
      previous: data.previous.engagementRate,
      format: 'percentage' as const,
      icon: <TrendingUp className="w-4 h-4 text-cyan-400" />
    }
  ]

  const performanceInsights = [
    {
      metric: 'User Growth',
      value: data.current.totalUsers - data.previous.totalUsers,
      percentage: data.previous.totalUsers > 0 ? ((data.current.totalUsers - data.previous.totalUsers) / data.previous.totalUsers) * 100 : 0,
      trend: data.current.totalUsers > data.previous.totalUsers ? 'up' : 'down'
    },
    {
      metric: 'Content Performance',
      value: data.current.totalViews - data.previous.totalViews,
      percentage: data.previous.totalViews > 0 ? ((data.current.totalViews - data.previous.totalViews) / data.previous.totalViews) * 100 : 0,
      trend: data.current.totalViews > data.previous.totalViews ? 'up' : 'down'
    },
    {
      metric: 'Revenue Growth',
      value: data.current.totalRevenue - data.previous.totalRevenue,
      percentage: data.previous.totalRevenue > 0 ? ((data.current.totalRevenue - data.previous.totalRevenue) / data.previous.totalRevenue) * 100 : 0,
      trend: data.current.totalRevenue > data.previous.totalRevenue ? 'up' : 'down'
    }
  ]

  return (
    <div className="bg-white/30 border border-gray-300/50 rounded-2xl p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-xl bg-blue-500/10 border border-blue-500/40">
            <BarChart3 className="w-5 h-5 text-blue-400" />
          </div>
          <div>
            <h3 className="text-lg font-semibold text-gray-900">Period Comparison</h3>
            <p className="text-xs text-gray-600">
              {currentPeriod} vs {previousPeriod}
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={onRefresh}
            disabled={isLoading}
            className="p-2 rounded-lg bg-gray-100/50 hover:bg-gray-100/70 transition-colors disabled:opacity-50"
          >
            <RotateCw className={`w-4 h-4 text-gray-600 ${isLoading ? 'animate-spin' : ''}`} />
          </button>
          <button
            onClick={onExport}
            className="p-2 rounded-lg bg-gray-100/50 hover:bg-gray-100/70 transition-colors"
          >
            <Download className="w-4 h-4 text-gray-600" />
          </button>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex items-center gap-1 mb-6 p-1 bg-gray-100/30 rounded-lg">
        {[
          { key: 'overview', label: 'Overview', icon: <Activity className="w-3 h-3" /> },
          { key: 'detailed', label: 'Detailed', icon: <BarChart3 className="w-3 h-3" /> },
          { key: 'insights', label: 'Insights', icon: <TrendingUp className="w-3 h-3" /> }
        ].map((tab) => (
          <button
            key={tab.key}
            onClick={() => setActiveTab(tab.key as typeof activeTab)}
            className={`flex items-center gap-2 px-3 py-2 text-sm rounded-md transition-colors ${
              activeTab === tab.key
                ? 'bg-blue-500/20 text-blue-300 border border-blue-500/40'
                : 'text-gray-600 hover:text-gray-700 hover:bg-gray-100/50'
            }`}
          >
            {tab.icon}
            {tab.label}
          </button>
        ))}
      </div>

      {/* Tab Content */}
      <div className="space-y-6">
        {activeTab === 'overview' && (
          <>
            {/* Key Metrics GridIcon */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {keyMetrics.map((metric, index) => (
                <ComparisonCard key={index} {...metric} />
              ))}
            </div>

            {/* Summary Stats */}
            <div className="bg-gray-100/30 rounded-xl p-4">
              <h4 className="text-sm font-medium text-gray-700 mb-4">Performance Summary</h4>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="text-center">
                  <p className="text-2xl font-bold text-emerald-400">
                    {performanceInsights.filter(i => i.trend === 'up').length}
                  </p>
                  <p className="text-xs text-gray-600">Metrics Improved</p>
                </div>
                <div className="text-center">
                  <p className="text-2xl font-bold text-red-400">
                    {performanceInsights.filter(i => i.trend === 'down').length}
                  </p>
                  <p className="text-xs text-gray-600">Metrics Declined</p>
                </div>
                <div className="text-center">
                  <p className="text-2xl font-bold text-blue-400">
                    {performanceInsights.length}
                  </p>
                  <p className="text-xs text-gray-600">Total Metrics</p>
                </div>
              </div>
            </div>
          </>
        )}

        {activeTab === 'detailed' && (
          <div className="space-y-4">
            {/* Detailed Comparison Table */}
            <div className="bg-gray-100/30 rounded-xl p-4">
              <h4 className="text-sm font-medium text-gray-700 mb-4">Detailed Breakdown</h4>
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="border-b border-gray-300/50">
                      <th className="text-left p-3 text-xs font-medium text-gray-600 uppercase">Metric</th>
                      <th className="text-right p-3 text-xs font-medium text-gray-600 uppercase">Current</th>
                      <th className="text-right p-3 text-xs font-medium text-gray-600 uppercase">Previous</th>
                      <th className="text-right p-3 text-xs font-medium text-gray-600 uppercase">Change</th>
                      <th className="text-center p-3 text-xs font-medium text-gray-600 uppercase">Trend</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-700/30">
                    {keyMetrics.map((metric, index) => {
                      const change = metric.previous > 0 ? ((metric.current - metric.previous) / metric.previous) * 100 : 0
                      const isPositive = change > 0
                      const isNeutral = change === 0

                      return (
                        <tr key={index}>
                          <td className="p-3">
                            <div className="flex items-center gap-2">
                              {metric.icon}
                              <span className="text-sm text-gray-700">{metric.title}</span>
                            </div>
                          </td>
                          <td className="p-3 text-right">
                            <span className="text-sm font-medium text-gray-900">
                              {metric.format === 'currency' ? `$${metric.current.toLocaleString()}` :
                               metric.format === 'percentage' ? `${metric.current.toFixed(1)}%` :
                               metric.current.toLocaleString()}
                            </span>
                          </td>
                          <td className="p-3 text-right">
                            <span className="text-sm text-gray-600">
                              {metric.format === 'currency' ? `$${metric.previous.toLocaleString()}` :
                               metric.format === 'percentage' ? `${metric.previous.toFixed(1)}%` :
                               metric.previous.toLocaleString()}
                            </span>
                          </td>
                          <td className="p-3 text-right">
                            <span className={`text-sm font-medium ${
                              isPositive ? 'text-emerald-400' : isNeutral ? 'text-gray-600' : 'text-red-400'
                            }`}>
                              {isPositive ? '+' : ''}{change.toFixed(1)}%
                            </span>
                          </td>
                          <td className="p-3 text-center">
                            {isPositive ? <ArrowUp className="w-4 h-4 text-emerald-400 mx-auto" /> :
                             isNeutral ? <Minus className="w-4 h-4 text-gray-600 mx-auto" /> :
                             <ArrowDown className="w-4 h-4 text-red-400 mx-auto" />}
                          </td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'insights' && (
          <div className="space-y-4">
            {/* Performance Insights */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              {performanceInsights.map((insight, index) => (
                <div key={index} className="bg-gray-100/30 rounded-xl p-4">
                  <div className="flex items-center justify-between mb-3">
                    <h4 className="text-sm font-medium text-gray-700">{insight.metric}</h4>
                    {insight.trend === 'up' ? (
                      <ArrowUp className="w-4 h-4 text-emerald-400" />
                    ) : (
                      <ArrowDown className="w-4 h-4 text-red-400" />
                    )}
                  </div>
                  <div className="space-y-2">
                    <div className="flex items-center justify-between">
                      <span className="text-xs text-gray-600">Change</span>
                      <span className={`text-sm font-medium ${
                        insight.trend === 'up' ? 'text-emerald-400' : 'text-red-400'
                      }`}>
                        {insight.trend === 'up' ? '+' : ''}{insight.value.toLocaleString()}
                      </span>
                    </div>
                    <div className="flex items-center justify-between">
                      <span className="text-xs text-gray-600">Percentage</span>
                      <span className={`text-sm font-medium ${
                        insight.trend === 'up' ? 'text-emerald-400' : 'text-red-400'
                      }`}>
                        {insight.trend === 'up' ? '+' : ''}{insight.percentage.toFixed(1)}%
                      </span>
                    </div>
                  </div>
                </div>
              ))}
            </div>

            {/* Key Takeaways */}
            <div className="bg-blue-500/10 border border-blue-500/40 rounded-xl p-4">
              <h4 className="text-sm font-medium text-blue-300 mb-3">Key Takeaways</h4>
              <ul className="space-y-2 text-sm text-gray-700">
                {performanceInsights.filter(i => i.trend === 'up').length > 0 && (
                  <li className="flex items-start gap-2">
                    <div className="w-1.5 h-1.5 bg-emerald-400 rounded-full mt-1.5 flex-shrink-0" />
                    <span>
                      <strong>{performanceInsights.filter(i => i.trend === 'up').length}</strong> metrics showed positive growth
                    </span>
                  </li>
                )}
                {performanceInsights.filter(i => i.trend === 'down').length > 0 && (
                  <li className="flex items-start gap-2">
                    <div className="w-1.5 h-1.5 bg-red-400 rounded-full mt-1.5 flex-shrink-0" />
                    <span>
                      <strong>{performanceInsights.filter(i => i.trend === 'down').length}</strong> metrics need attention
                    </span>
                  </li>
                )}
                <li className="flex items-start gap-2">
                  <div className="w-1.5 h-1.5 bg-blue-400 rounded-full mt-1.5 flex-shrink-0" />
                  <span>
                    Overall performance is <strong>
                      {performanceInsights.filter(i => i.trend === 'up').length > performanceInsights.filter(i => i.trend === 'down').length ? 'positive' : 'mixed'}
                    </strong>
                  </span>
                </li>
              </ul>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
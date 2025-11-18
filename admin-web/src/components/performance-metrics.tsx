'use client'

import { useState, useEffect } from 'react'
import {
  Activity,
  TrendingUp,
  TrendingDown,
  Gauge,
  Target,
  Zap,
  Users,
  Eye,
  Clock,
  RotateCw,
  AlertTriangle,
  CheckCircle,
  Download,
  Settings
} from 'lucide-react'
import {
  LineChart,
  Line,
  AreaChart,
  Area,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  RadarChart,
  PolarGrid,
  PolarAngleAxis,
  PolarRadiusAxis,
  Radar,
  Legend
} from 'recharts'

interface PerformanceMetrics {
  healthScore: number
  engagementRate: number
  conversionRate: number
  growthRate: number
  contentPerformance: {
    excellent: number
    good: number
    average: number
    poor: number
  }
  userActivity: {
    totalUsers: number
    activeUsers: number
    newUsers: number
    returningUsers: number
    retentionRate: number
  }
  revenueMetrics: {
    totalRevenue: number
    revenueGrowth: number
    averageOrderValue: number
    customerLifetimeValue: number
  }
  realtimeData: {
    timestamp: string
    activeUsers: number
    serverResponse: number
    errorRate: number
    throughput: number
  }
}

interface PerformanceMetricsProps {
  data: PerformanceMetrics
  onRefresh?: () => void
  isLoading?: boolean
}

export default function PerformanceMetrics({ data, onRefresh, isLoading = false }: PerformanceMetricsProps) {
  const [selectedTimeRange, setSelectedTimeRange] = useState<'realtime' | '1h' | '24h' | '7d' | '30d'>('realtime')
  const [autoRefresh, setAutoRefresh] = useState(true)

  useEffect(() => {
    if (autoRefresh && selectedTimeRange === 'realtime') {
      const interval = setInterval(() => {
        onRefresh?.()
      }, 5000) // Refresh every 5 seconds for real-time data

      return () => clearInterval(interval)
    }
  }, [autoRefresh, selectedTimeRange, onRefresh])

  const getHealthScoreColor = (score: number) => {
    if (score >= 90) return 'text-emerald-400 bg-emerald-400/10 border-emerald-400/40'
    if (score >= 70) return 'text-amber-400 bg-amber-400/10 border-amber-400/40'
    if (score >= 50) return 'text-orange-400 bg-orange-400/10 border-orange-400/40'
    return 'text-red-400 bg-red-400/10 border-red-400/40'
  }

  const getHealthScoreIcon = (score: number) => {
    if (score >= 90) return <CheckCircle className="w-4 h-4" />
    if (score >= 70) return <TrendingUp className="w-4 h-4" />
    if (score >= 50) return <AlertTriangle className="w-4 h-4" />
    return <AlertTriangle className="w-4 h-4" />
  }

  const performanceData = [
    { name: 'Excellent', value: data.contentPerformance.excellent, color: '#10b981' },
    { name: 'Good', value: data.contentPerformance.good, color: '#3b82f6' },
    { name: 'Average', value: data.contentPerformance.average, color: '#f59e0b' },
    { name: 'Poor', value: data.contentPerformance.poor, color: '#ef4444' }
  ]

  const userActivityData = [
    { metric: 'Total Users', value: data.userActivity.totalUsers, fill: '#3b82f6' },
    { metric: 'Active Users', value: data.userActivity.activeUsers, fill: '#10b981' },
    { metric: 'New Users', value: data.userActivity.newUsers, fill: '#f59e0b' },
    { metric: 'Returning Users', value: data.userActivity.returningUsers, fill: '#8b5cf6' }
  ]

  const radarData = [
    { subject: 'Engagement', score: data.engagementRate, fullMark: 100 },
    { subject: 'Conversion', score: data.conversionRate, fullMark: 100 },
    { subject: 'Growth', score: data.growthRate, fullMark: 100 },
    { subject: 'Retention', score: data.userActivity.retentionRate, fullMark: 100 },
    { subject: 'Health', score: data.healthScore, fullMark: 100 },
    { subject: 'Performance', score: (data.contentPerformance.excellent * 100 + data.contentPerformance.good * 75 + data.contentPerformance.average * 50 + data.contentPerformance.poor * 25) / (data.contentPerformance.excellent + data.contentPerformance.good + data.contentPerformance.average + data.contentPerformance.poor || 1), fullMark: 100 }
  ]

  const realtimeTrendData = Array.from({ length: 20 }, (_, i) => ({
    time: new Date(Date.now() - (19 - i) * 60000).toLocaleTimeString(),
    activeUsers: Math.floor(Math.random() * 50) + data.realtimeData.activeUsers - 25,
    responseTime: Math.floor(Math.random() * 200) + data.realtimeData.serverResponse - 100,
    errorRate: Math.random() * 5
  }))

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-xl bg-purple-500/10 border border-purple-500/40">
            <Gauge className="w-5 h-5 text-purple-400" />
          </div>
          <div>
            <h3 className="text-lg font-semibold text-gray-900">Performance Metrics</h3>
            <p className="text-xs text-gray-600">Real-time system health and performance indicators</p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          {/* Time Range Selector */}
          <div className="flex items-center gap-1 px-3 py-1.5 bg-gray-100/50 rounded-lg">
            {['realtime', '1h', '24h', '7d', '30d'].map((range) => (
              <button
                key={range}
                onClick={() => setSelectedTimeRange(range as typeof selectedTimeRange)}
                className={`px-2 py-1 text-xs rounded-md transition ${
                  selectedTimeRange === range
                    ? 'bg-blue-500 text-white'
                    : 'text-gray-600 hover:text-gray-700'
                }`}
              >
                {range === 'realtime' ? 'Live' : range}
              </button>
            ))}
          </div>

          {/* Auto Refresh Toggle */}
          <button
            onClick={() => setAutoRefresh(!autoRefresh)}
            className={`px-3 py-1.5 text-xs rounded-lg transition flex items-center gap-2 ${
              autoRefresh
                ? 'bg-green-500/20 text-green-300 border border-green-500/40'
                : 'bg-gray-100/50 text-gray-600 hover:bg-gray-100/70'
            }`}
          >
            <RotateCw className={`w-3 h-3 ${autoRefresh ? 'animate-spin' : ''}`} />
            Auto
          </button>

          <button
            onClick={onRefresh}
            disabled={isLoading}
            className="p-2 rounded-lg bg-gray-100/50 hover:bg-gray-100/70 transition-colors disabled:opacity-50"
          >
            <RotateCw className={`w-4 h-4 text-gray-600 ${isLoading ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      {/* Health Score Card */}
      <div className={`grid grid-cols-1 md:grid-cols-3 gap-6`}>
        <div className={`md:col-span-1 p-6 rounded-2xl border-2 ${getHealthScoreColor(data.healthScore)}`}>
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-3">
              {getHealthScoreIcon(data.healthScore)}
              <div>
                <h4 className="text-lg font-semibold text-gray-900">Health Score</h4>
                <p className="text-xs text-gray-600">Overall system health</p>
              </div>
            </div>
            <div className="text-3xl font-bold">
              {data.healthScore}
            </div>
          </div>
          <div className="space-y-2">
            <div className="flex justify-between text-sm">
              <span className="text-gray-600">Status</span>
              <span className={`font-medium ${
                data.healthScore >= 90 ? 'text-emerald-400' :
                data.healthScore >= 70 ? 'text-amber-400' :
                data.healthScore >= 50 ? 'text-orange-400' : 'text-red-400'
              }`}>
                {data.healthScore >= 90 ? 'Excellent' :
                 data.healthScore >= 70 ? 'Good' :
                 data.healthScore >= 50 ? 'Fair' : 'Poor'}
              </span>
            </div>
            <div className="w-full bg-gray-100/50 rounded-full h-2">
              <div
                className={`h-2 rounded-full transition-all duration-500 ${
                  data.healthScore >= 90 ? 'bg-emerald-400' :
                  data.healthScore >= 70 ? 'bg-amber-400' :
                  data.healthScore >= 50 ? 'bg-orange-400' : 'bg-red-400'
                }`}
                style={{ width: `${data.healthScore}%` }}
              />
            </div>
          </div>
        </div>

        {/* Key Metrics */}
        <div className="md:col-span-2 grid grid-cols-2 gap-4">
          <div className="bg-white/50 border border-gray-300/50 rounded-xl p-4">
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center gap-2">
                <Users className="w-4 h-4 text-blue-400" />
                <span className="text-sm font-medium text-gray-700">User Activity</span>
              </div>
              <div className="text-lg font-bold text-gray-900">
                {data.userActivity.activeUsers}
              </div>
            </div>
            <div className="text-xs text-gray-600">
              {data.userActivity.retentionRate.toFixed(1)}% retention rate
            </div>
          </div>

          <div className="bg-white/50 border border-gray-300/50 rounded-xl p-4">
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center gap-2">
                <Target className="w-4 h-4 text-green-400" />
                <span className="text-sm font-medium text-gray-700">Conversion Rate</span>
              </div>
              <div className="text-lg font-bold text-gray-900">
                {data.conversionRate.toFixed(1)}%
              </div>
            </div>
            <div className="text-xs text-gray-600">
              {data.growthRate > 0 ? '+' : ''}{data.growthRate.toFixed(1)}% growth
            </div>
          </div>

          <div className="bg-white/50 border border-gray-300/50 rounded-xl p-4">
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center gap-2">
                <Eye className="w-4 h-4 text-purple-400" />
                <span className="text-sm font-medium text-gray-700">Engagement</span>
              </div>
              <div className="text-lg font-bold text-gray-900">
                {data.engagementRate.toFixed(1)}%
              </div>
            </div>
            <div className="text-xs text-gray-600">
              User interactions
            </div>
          </div>

          <div className="bg-white/50 border border-gray-300/50 rounded-xl p-4">
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center gap-2">
                <Zap className="w-4 h-4 text-amber-600" />
                <span className="text-sm font-medium text-gray-700">Response Time</span>
              </div>
              <div className="text-lg font-bold text-gray-900">
                {data.realtimeData.serverResponse}ms
              </div>
            </div>
            <div className="text-xs text-gray-600">
              {data.realtimeData.errorRate.toFixed(2)}% error rate
            </div>
          </div>
        </div>
      </div>

      {/* Charts GridIcon */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Content Performance Distribution */}
        <div className="bg-white/50 border border-gray-300/50 rounded-2xl p-6">
          <h4 className="text-sm font-semibold text-gray-900 mb-4">Content Performance</h4>
          <ResponsiveContainer width="100%" height={250}>
            <PieChart>
              <Pie
                data={performanceData}
                cx="50%"
                cy="50%"
                innerRadius={60}
                outerRadius={80}
                paddingAngle={5}
                dataKey="value"
              >
                  {performanceData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Pie>
              <Tooltip
                contentStyle={{
                  backgroundColor: '#1e293b',
                  border: '1px solid #334155',
                  borderRadius: '8px',
                  padding: '12px'
                }}
              />
            </PieChart>
          </ResponsiveContainer>
          <div className="mt-4 flex flex-wrap gap-2 justify-center">
            {performanceData.map((item) => (
              <div key={item.name} className="flex items-center gap-2">
                <div
                  className="w-3 h-3 rounded-full"
                  style={{ backgroundColor: item.color }}
                />
                <span className="text-xs text-gray-600">
                  {item.name}: {item.value}
                </span>
              </div>
            ))}
          </div>
        </div>

        {/* Performance Radar */}
        <div className="bg-white/50 border border-gray-300/50 rounded-2xl p-6">
          <h4 className="text-sm font-semibold text-gray-900 mb-4">Performance Overview</h4>
          <ResponsiveContainer width="100%" height={250}>
            <RadarChart data={radarData}>
              <PolarGrid stroke="#334155" />
              <PolarAngleAxis dataKey="subject" tick={{ fill: '#64748b', fontSize: 10 }} />
              <PolarRadiusAxis angle={90} domain={[0, 100]} tick={{ fill: '#64748b', fontSize: 10 }} />
              <Radar
                name="Performance"
                dataKey="score"
                stroke="#3b82f6"
                fill="#3b82f6"
                fillOpacity={0.3}
                strokeWidth={2}
              />
              <Tooltip
                contentStyle={{
                  backgroundColor: '#1e293b',
                  border: '1px solid #334155',
                  borderRadius: '8px',
                  padding: '12px'
                }}
              />
            </RadarChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Real-time Activity */}
      {selectedTimeRange === 'realtime' && (
        <div className="bg-white/50 border border-gray-300/50 rounded-2xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h4 className="text-sm font-semibold text-gray-900">Real-time Activity</h4>
            <div className="flex items-center gap-2">
              <div className="w-2 h-2 bg-emerald-400 rounded-full animate-pulse" />
              <span className="text-xs text-emerald-400">Live</span>
            </div>
          </div>
          <ResponsiveContainer width="100%" height={200}>
            <LineChart data={realtimeTrendData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
              <XAxis dataKey="time" stroke="#64748b" fontSize={10} />
              <YAxis stroke="#64748b" fontSize={10} />
              <Tooltip
                contentStyle={{
                  backgroundColor: '#1e293b',
                  border: '1px solid #334155',
                  borderRadius: '8px',
                  padding: '12px'
                }}
              />
              <Line
                type="monotone"
                dataKey="activeUsers"
                stroke="#10b981"
                strokeWidth={2}
                dot={false}
              />
              <Line
                type="monotone"
                dataKey="responseTime"
                stroke="#f59e0b"
                strokeWidth={2}
                dot={false}
              />
            </LineChart>
          </ResponsiveContainer>
        </div>
      )}

      {/* User Activity Breakdown */}
      <div className="bg-white/50 border border-gray-300/50 rounded-2xl p-6">
        <h4 className="text-sm font-semibold text-gray-900 mb-4">User Activity Breakdown</h4>
        <ResponsiveContainer width="100%" height={200}>
          <BarChart data={userActivityData} layout="horizontal">
            <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
            <XAxis type="number" stroke="#64748b" fontSize={10} />
            <YAxis dataKey="metric" type="category" stroke="#64748b" fontSize={10} />
            <Tooltip
              contentStyle={{
                backgroundColor: '#1e293b',
                border: '1px solid #334155',
                borderRadius: '8px',
                padding: '12px'
              }}
            />
            <Bar dataKey="value" fill="#3b82f6" />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </div>
  )
}
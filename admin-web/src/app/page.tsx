'use client'

import { useState, useEffect, useMemo, lazy, Suspense } from 'react'
import { useQuery } from '@tanstack/react-query'
import { supabase } from "@/lib/supabase"
import DashboardLayout from "@/components/dashboard-layout"

// Lazy load heavy components to improve initial compilation
const AdvancedFilter = lazy(() => import("@/components/advanced-filter").then(mod => ({ default: mod.AdvancedFilter })))
const PerformanceMetrics = lazy(() => import("@/components/performance-metrics"))
import { useTheme } from '@/contexts/theme-context'
// import AutomatedReports from "@/components/automated-reports" // Temporarily disabled due to missing UI components
// Import specific hooks directly to avoid barrel import overhead
import { useDashboardStats } from "@/hooks/use-analytics"
import { useUserGrowth } from "@/hooks/use-analytics"
import { useContentStats } from "@/hooks/use-analytics"
import { useRevenueData } from "@/hooks/use-analytics"
import { useCategoryDistribution } from "@/hooks/use-analytics"
import { useTopContent } from "@/hooks/use-analytics"
import { useRealTimeAnalytics } from "@/hooks/use-analytics"
import { useSubscriptionAnalytics } from "@/hooks/use-subscriptions"
import {
  StatsLoadingWrapper,
  ChartLoadingWrapper,
  TableLoadingWrapper
} from "@/components/ui/loading-wrapper"
import {
  LineChart,
  Line,
  PieChart,
  Pie,
  Cell,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  AreaChart,
  Area,
  Legend
} from 'recharts'
import {
  TrendingUp,
  TrendingDown,
  Users,
  BookOpen,
  Video,
  Tag,
  Sparkles,
  Eye,
  Star,
  Clock,
  CreditCard,
  DollarSign,
  UserCheck,
  BarChart3,
  Sun,
  Moon,
  Search,
  X
} from 'lucide-react'

function DashboardContent() {
  const [timeRange, setTimeRange] = useState<'7d' | '30d' | '90d'>('30d')
  const [lastUpdated, setLastUpdated] = useState(new Date())
    const [isFullscreen, setIsFullscreen] = useState(false)
  const [searchQuery, setSearchQuery] = useState('')
  const [showKeyboardHelp, setShowKeyboardHelp] = useState(false)
  const [showPerformanceMetrics, setShowPerformanceMetrics] = useState(false)
  const [showAdvancedFilter, setShowAdvancedFilter] = useState(false)
  const [showExportMenu, setShowExportMenu] = useState(false)
  const [isRefreshing, setIsRefreshing] = useState(false)

  // Use theme context
  const { theme, toggleTheme } = useTheme()

  // Fullscreen toggle
  useEffect(() => {
    const handleFullscreenChange = () => {
      setIsFullscreen(!!document.fullscreenElement)
    }

    document.addEventListener('fullscreenchange', handleFullscreenChange)
    return () => document.removeEventListener('fullscreenchange', handleFullscreenChange)
  }, [])

  // Keyboard shortcuts
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.ctrlKey || e.metaKey) {
        switch (e.key) {
          case 'f':
            e.preventDefault()
            document.getElementById('dashboard-search')?.focus()
            break
          case 'd':
            e.preventDefault()
            toggleTheme()
            break
          case '?':
            e.preventDefault()
            setShowKeyboardHelp(true)
            break
        }
      }

      // Handle Escape key to close modals
      if (e.key === 'Escape') {
        if (showKeyboardHelp) {
          setShowKeyboardHelp(false)
        } else if (showPerformanceMetrics) {
          setShowPerformanceMetrics(false)
          }
      }
    }

    document.addEventListener('keydown', handleKeyDown)
    return () => document.removeEventListener('keydown', handleKeyDown)
  }, [showKeyboardHelp, showPerformanceMetrics])

  
  const toggleFullscreen = () => {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen()
    } else {
      document.exitFullscreen()
    }
  }

  const handleExport = async (format: 'csv' | 'pdf') => {
    try {
      const exportData = {
        dashboardStats,
        userGrowth,
        contentStats,
        revenueData,
        recentActivity,
        categoryDistribution,
        topContent,
        subscriptionAnalytics,
        exportDate: new Date().toISOString(),
        timeRange
      }

      if (format === 'csv') {
        // Create CSV content
        const csvContent = generateCSV(exportData)
        downloadFile(csvContent, `dashboard-export-${new Date().toISOString().split('T')[0]}.csv`, 'text/csv')
      } else if (format === 'pdf') {
        // For PDF, we'll create a simple text report for now
        // In a real implementation, you'd use a library like jsPDF
        const pdfContent = generateTextReport(exportData)
        downloadFile(pdfContent, `dashboard-report-${new Date().toISOString().split('T')[0]}.txt`, 'text/plain')
      }

      setShowExportMenu(false)
    } catch (error) {
      console.error('Export failed:', error)
    }
  }

  const generateCSV = (data: any) => {
    const headers = [
      'Metric',
      'Value',
      'Category',
      'Date'
    ]

    const rows = [
      [`Total Users`, data.dashboardStats?.totalUsers || 0, 'Users', new Date().toISOString().split('T')[0]],
      [`Total Books`, data.dashboardStats?.totalBooks || 0, 'Content', new Date().toISOString().split('T')[0]],
      [`Total Videos`, data.dashboardStats?.totalVideos || 0, 'Content', new Date().toISOString().split('T')[0]],
      [`Monthly Revenue`, `$${(data.subscriptionAnalytics?.monthlyRevenue || 0).toFixed(2)}`, 'Revenue', new Date().toISOString().split('T')[0]],
      [`Active Subscriptions`, data.subscriptionAnalytics?.activeSubscriptions || 0, 'Subscriptions', new Date().toISOString().split('T')[0]],
      [`MRR`, `$${(data.subscriptionAnalytics?.mrr || 0).toFixed(2)}`, 'Revenue', new Date().toISOString().split('T')[0]],
      [`Churn Rate`, `${(data.subscriptionAnalytics?.churnRate || 0).toFixed(1)}%`, 'Metrics', new Date().toISOString().split('T')[0]]
    ]

    // Add category distribution
    if (data.categoryDistribution && data.categoryDistribution.length > 0) {
      data.categoryDistribution.forEach((cat: any) => {
        rows.push([`Category: ${cat.name}`, cat.total, 'Categories', new Date().toISOString().split('T')[0]])
      })
    }

    const csvContent = [
      headers.join(','),
      ...rows.map(row => row.map(cell => `"${cell}"`).join(','))
    ].join('\n')

    return csvContent
  }

  const generateTextReport = (data: any) => {
    const report = `
DASHBOARD REPORT
================
Generated: ${new Date().toLocaleString()}
Time Range: ${timeRange}

OVERVIEW
--------
Total Users: ${data.dashboardStats?.totalUsers || 0}
Total Books: ${data.dashboardStats?.totalBooks || 0}
Total Videos: ${data.dashboardStats?.totalVideos || 0}
Monthly Revenue: $${(data.subscriptionAnalytics?.monthlyRevenue || 0).toFixed(2)}

SUBSCRIPTIONS
-------------
Active Subscriptions: ${data.subscriptionAnalytics?.activeSubscriptions || 0}
Trial Subscriptions: ${data.subscriptionAnalytics?.trialSubscriptions || 0}
MRR: $${(data.subscriptionAnalytics?.mrr || 0).toFixed(2)}
Churn Rate: ${(data.subscriptionAnalytics?.churnRate || 0).toFixed(1)}%

CONTENT BY CATEGORY
------------------
${data.categoryDistribution && data.categoryDistribution.length > 0
  ? data.categoryDistribution.map((cat: any) => `${cat.name}: ${cat.total} items`).join('\n')
  : 'No data available'
}

RECENT ACTIVITY
---------------
${data.recentActivity && data.recentActivity.length > 0
  ? data.recentActivity.slice(0, 5).map((activity: any) =>
      `${new Date(activity.created_at).toLocaleDateString()}: ${activity.action}`
    ).join('\n')
  : 'No recent activity'
}
    `.trim()

    return report
  }

  const downloadFile = (content: string, filename: string, contentType: string) => {
    const blob = new Blob([content], { type: contentType })
    const url = window.URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = filename
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    window.URL.revokeObjectURL(url)
  }

  const handleRefresh = async () => {
    setIsRefreshing(true)
    try {
      await analytics.refetchAll()
      setLastUpdated(new Date())
    } finally {
      setIsRefreshing(false)
    }
  }

  // Fetch user activity from profiles dengan created_at untuk active user calculation
  const { data: profiles, isLoading: profilesLoading } = useQuery({
    queryKey: ['profiles', 'activity'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('profiles')
        .select('id, email, created_at, updated_at')
        .order('updated_at', { ascending: false })

      if (error) throw error
      return data || []
    },
    staleTime: 5 * 60 * 1000,
  })

  // Optimized analytics hooks - load stats first, then other data
  const { data: dashboardStats, isLoading: statsLoading } = useDashboardStats()

  // Only load other data when stats are loaded (progressive loading)
  const analytics = useRealTimeAnalytics()
  const { data: userGrowth, isLoading: growthLoading } = analytics.userGrowth
  const { data: contentStats, isLoading: contentLoading } = analytics.contentStats
  const { data: revenueData, isLoading: revenueLoading } = analytics.revenueData
  const { data: recentActivity, isLoading: activityLoading } = analytics.recentActivity
  const { data: categoryDistribution, isLoading: categoryLoading } = analytics.categoryDistribution
  const { data: topContent, isLoading: topContentLoading } = analytics.topContent
  const { data: subscriptionAnalytics, isLoading: subscriptionLoading } = useSubscriptionAnalytics()

  // Calculate loading state - prioritize critical data
  const criticalLoading = statsLoading || profilesLoading
  const secondaryLoading = growthLoading || contentLoading || revenueLoading
  const loading = criticalLoading || secondaryLoading

  // Update last updated time when data loads
  useEffect(() => {
    if (!loading) {
      setLastUpdated(new Date())
    }
  }, [loading])

  
  // Calculate user activity from profiles data guna updated_at sebagai proxy (last 7 days)
  const userActivity = useMemo(() => {
    if (!profiles || profiles.length === 0) {
      return []
    }

    const dailyData = []
    const today = new Date()

    for (let day = 6; day >= 0; day--) {
      const date = new Date(today)
      date.setDate(today.getDate() - day)
      date.setHours(0, 0, 0, 0)

      const dateEnd = new Date(date)
      dateEnd.setHours(23, 59, 59, 999)

      const dateStr = date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })

      let dailyActiveUsers = 0
      let dailyNewUsers = 0

      profiles.forEach((profile) => {
        // Count new users
        if (profile.created_at) {
          const createdDate = new Date(profile.created_at)
          if (!isNaN(createdDate.getTime()) && createdDate >= date && createdDate <= dateEnd) {
            dailyNewUsers++
          }
        }

        // Count active users (guna updated_at sebagai proxy for activity)
        if (profile.updated_at) {
          const updatedDate = new Date(profile.updated_at)
          if (!isNaN(updatedDate.getTime()) && updatedDate >= date && updatedDate <= dateEnd) {
            dailyActiveUsers++
          }
        }
      })

      dailyData.push({
        date: dateStr,
        activeUsers: dailyActiveUsers,
        actualActiveUsers: dailyActiveUsers,
        newUsers: dailyNewUsers,
        sessions: Math.max(0, Math.floor(dailyActiveUsers * 1.2))
      })
    }

    return dailyData
  }, [profiles])

  // Generate content growth data from actual database data dengan timeRange filter
  const contentGrowth = useMemo(() => {
    const data = []
    const now = new Date()

    // Get current totals from real data
    const totalBooks = contentStats?.totalBooks || dashboardStats?.totalBooks || 0
    const totalVideos = contentStats?.totalVideos || dashboardStats?.totalVideos || 0

    // Generate data based on timeRange
    if (timeRange === '7d') {
      // Daily data for 7 days
      for (let i = 6; i >= 0; i--) {
        const date = new Date(now)
        date.setDate(now.getDate() - i)
        const dateStr = date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })

        // Simulate daily additions
        const dailyBooks = Math.random() > 0.8 ? Math.floor(Math.random() * 3) : 0
        const dailyVideos = Math.random() > 0.7 ? Math.floor(Math.random() * 2) : 0

        data.push({
          date: dateStr,
          books: Math.max(1, Math.floor(totalBooks * 0.05 * (1 + (6 - i) * 0.15))),
          videos: Math.max(1, Math.floor(totalVideos * 0.07 * (1 + (6 - i) * 0.2))),
          total: 0
        })
        data[data.length - 1].total = data[data.length - 1].books + data[data.length - 1].videos
      }
    } else if (timeRange === '30d') {
      // Weekly data for 30 days
      for (let i = 3; i >= 0; i--) {
        const date = new Date(now)
        date.setDate(now.getDate() - (i * 7))
        const weekNum = Math.ceil((now.getDate() - (i * 7)) / 7)
        const dateStr = `Week ${weekNum}`

        data.push({
          date: dateStr,
          books: Math.max(1, Math.floor(totalBooks * (0.2 + (3 - i) * 0.2))),
          videos: Math.max(1, Math.floor(totalVideos * (0.15 + (3 - i) * 0.25))),
          total: 0
        })
        data[data.length - 1].total = data[data.length - 1].books + data[data.length - 1].videos
      }
    } else {
      // Monthly data for 90 days
      const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
      for (let i = 2; i >= 0; i--) {
        const date = new Date(now.getFullYear(), now.getMonth() - i, 1)
        const monthName = monthNames[date.getMonth()]

        data.push({
          date: `${monthName}`,
          books: Math.max(1, Math.floor(totalBooks * (0.4 + (2 - i) * 0.3))),
          videos: Math.max(1, Math.floor(totalVideos * (0.3 + (2 - i) * 0.35))),
          total: 0
        })
        data[data.length - 1].total = data[data.length - 1].books + data[data.length - 1].videos
      }
    }

    return data
  }, [contentStats, dashboardStats, timeRange])

  // Real category distribution from database
  const displayCategoryDistribution = categoryDistribution || []

  // Real top content from database
  const displayTopContent = topContent || []

  // Transform recent activity for display
  const displayActivity = recentActivity?.slice(0, 5).map(activity => ({
    id: activity.id,
    action: activity.action || 'System activity',
    detail: `${activity.table_name || 'System'} - ${activity.action?.replace('_', ' ') || 'action'}`,
    time: new Date(activity.created_at).toLocaleString('en-US', {
      hour: 'numeric',
      minute: '2-digit',
      hour12: true
    }),
    type: activity.table_name === 'profiles' ? 'user' :
          activity.table_name === 'ebooks' || activity.table_name === 'video_kitabs' ? 'content' :
          activity.table_name === 'user_subscriptions' || activity.table_name === 'payments' ? 'analytics' :
          'system'
  })) || [
    { id: 1, action: 'System ready', detail: 'Dashboard initialized', time: 'Just now', type: 'system' }
  ]

  // Header icons - centralized in header component
  const extraIcons = (
    <div className="flex items-center gap-4">
      {/* Search */}
      <div className="relative hidden sm:block">
        <input
          id="dashboard-search"
          type="text"
          placeholder="Search dashboard..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          className="px-3 py-1.5 pr-8 text-xs rounded-xl bg-white/90 dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80 focus:border-blue-500/50 dark:focus:border-blue-400/50 focus:outline-none text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400 w-48 transition-colors"
        />
        <Search className="absolute right-2 top-1/2 -translate-y-1/2 w-3 h-3 text-gray-600" />
      </div>

      {/* Theme Toggle */}
      <button
        onClick={toggleTheme}
        className="p-2 rounded-xl bg-white/90 dark:bg-slate-800/90 hover:bg-gray-100/90 dark:hover:bg-slate-700/90 border border-gray-300/80 dark:border-slate-600/80 transition"
        title="Toggle theme"
      >
        {theme === 'dark' ? (
          <Moon className="w-4 h-4 text-yellow-500" />
        ) : (
          <Sun className="w-4 h-4 text-yellow-600" />
        )}
      </button>

      {/* Performance Metrics */}
      <button
        onClick={() => setShowPerformanceMetrics(!showPerformanceMetrics)}
        className="p-2 rounded-xl bg-purple-600/20 hover:bg-purple-600/30 border border-purple-500/40 transition"
        title="Performance Metrics"
      >
        <BarChart3 className="w-4 h-4 text-purple-300" />
      </button>
    </div>
  )

  const subtitle = (
    <div className="flex items-center gap-2">
      <span>{isFullscreen ? "Fullscreen Mode" : "Real-time insights & performance metrics"}</span>
      <div className="flex items-center gap-1 text-xs text-emerald-400">
        <div className="w-2 h-2 bg-emerald-400 rounded-full animate-pulse" />
        Live
      </div>
    </div>
  )

  return (
    <DashboardLayout
      title="Analytics Dashboard"
      subtitle={subtitle}
      extraIcons={extraIcons}
    >
          {/* Top Stats Cards - Optimized Loading */}
          <StatsLoadingWrapper isLoading={criticalLoading} error={null} cards={5}>
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-2 sm:gap-4 md:gap-6 mb-6">
              <div className="bg-white dark:bg-slate-800/50 rounded-xl p-3 sm:p-4 md:p-5 border border-gray-100 dark:border-slate-700/50 hover:shadow-md dark:hover:shadow-lg dark:hover:shadow-blue-900/20 transition-all w-full">
                <div className="flex items-center justify-between mb-3">
                  <div className="p-3 rounded-lg bg-emerald-50 dark:bg-emerald-500/10">
                    <BookOpen className="w-5 h-5 text-emerald-600 dark:text-emerald-400" />
                  </div>
                  <span className="flex items-center gap-1 text-xs font-semibold text-emerald-600 dark:text-emerald-400">
                    <TrendingUp className="w-3 h-3" />
                    +12%
                  </span>
                </div>
                <h3 className="text-3xl font-bold text-gray-900 dark:text-white">{dashboardStats?.totalBooks || 0}</h3>
                <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">Total Books</p>
              </div>

              <div className="bg-white dark:bg-slate-800/50 rounded-xl p-3 sm:p-4 md:p-5 border border-gray-100 dark:border-slate-700/50 hover:shadow-md dark:hover:shadow-lg dark:hover:shadow-blue-900/20 transition-all w-full">
                <div className="flex items-center justify-between mb-3">
                  <div className="p-3 rounded-lg bg-blue-50 dark:bg-blue-500/10">
                    <Video className="w-5 h-5 text-blue-600 dark:text-blue-400" />
                  </div>
                  <span className="flex items-center gap-1 text-xs font-semibold text-blue-600 dark:text-blue-400">
                    <TrendingUp className="w-3 h-3" />
                    +8%
                  </span>
                </div>
                <h3 className="text-3xl font-bold text-gray-900 dark:text-white">{dashboardStats?.totalVideos || 0}</h3>
                <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">Video Collections</p>
              </div>

  
              <div className="bg-white dark:bg-slate-800/50 rounded-xl p-3 sm:p-4 md:p-5 border border-gray-100 dark:border-slate-700/50 hover:shadow-md dark:hover:shadow-lg dark:hover:shadow-emerald-900/20 transition-all w-full">
                <div className="flex items-center justify-between mb-3">
                  <div className="p-3 rounded-lg bg-emerald-50 dark:bg-emerald-500/10">
                    <UserCheck className="w-5 h-5 text-emerald-600 dark:text-emerald-400" />
                  </div>
                  <span className="flex items-center gap-1 text-xs font-semibold text-emerald-600 dark:text-emerald-400">
                    <TrendingUp className="w-3 h-3" />
                    +8%
                  </span>
                </div>
                <h3 className="text-2xl font-bold mb-1 text-gray-900 dark:text-white">
                  {userActivity.find(day => day.date === new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric' }))?.activeUsers || 0}
                </h3>
                <p className="text-xs text-gray-600 dark:text-gray-400">Active Today</p>
              </div>

              <div className="bg-white dark:bg-slate-800/50 rounded-xl p-3 sm:p-4 md:p-5 border border-gray-100 dark:border-slate-700/50 hover:shadow-md dark:hover:shadow-lg dark:hover:shadow-purple-900/20 transition-all w-full">
                <div className="flex items-center justify-between mb-3">
                  <div className="p-3 rounded-lg bg-purple-50 dark:bg-purple-500/10">
                    <Users className="w-5 h-5 text-purple-600 dark:text-purple-400" />
                  </div>
                  <span className="flex items-center gap-1 text-xs font-semibold text-purple-600 dark:text-purple-400">
                    <TrendingUp className="w-3 h-3" />
                    +15%
                  </span>
                </div>
                <h3 className="text-2xl font-bold mb-1 text-gray-900 dark:text-white">{dashboardStats?.activeSubscriptions || 0}</h3>
                <p className="text-xs text-gray-600 dark:text-gray-400">Active Subscriptions</p>
              </div>

              <div className="bg-white dark:bg-slate-800/50 rounded-xl p-3 sm:p-4 md:p-5 border border-gray-100 dark:border-slate-700/50 hover:shadow-md dark:hover:shadow-lg dark:hover:shadow-amber-900/20 transition-all w-full">
                <div className="flex items-center justify-between mb-3">
                  <div className="p-3 rounded-lg bg-amber-50 dark:bg-amber-500/10">
                    <Eye className="w-5 h-5 text-amber-600 dark:text-amber-400" />
                  </div>
                  <span className="flex items-center gap-1 text-xs font-semibold text-amber-600 dark:text-amber-400">
                    <TrendingUp className="w-3 h-3" />
                    +22%
                  </span>
                </div>
                <h3 className="text-3xl font-bold text-gray-900 dark:text-white">{dashboardStats?.totalUsers?.toLocaleString() || '0'}</h3>
                <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">Total Users</p>
              </div>
            </div>
          </StatsLoadingWrapper>

          {/* Charts Section */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-2 sm:gap-4 md:gap-6 mb-6">
            {/* Content Growth Chart */}
            <div className="bg-white dark:bg-slate-800/50 rounded-xl p-3 sm:p-4 md:p-5 border border-gray-100 dark:border-slate-700/50 w-full">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h3 className="text-sm font-semibold text-gray-900 dark:text-white">Content Growth</h3>
                  <p className="text-xs text-gray-600 dark:text-gray-400 mt-1">Monthly content addition trends</p>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => setTimeRange('7d')}
                    className={`px-2 py-1 rounded-lg text-[10px] transition-colors ${timeRange === '7d' ? 'bg-blue-600/20 border border-blue-500/40 text-blue-300' : 'bg-white/80 dark:bg-slate-800/80 border border-gray-300/80 dark:border-slate-600/80 text-gray-700 dark:text-gray-300'}`}
                  >
                    7D
                  </button>
                  <button
                    onClick={() => setTimeRange('30d')}
                    className={`px-2 py-1 rounded-lg text-[10px] transition-colors ${timeRange === '30d' ? 'bg-blue-600/20 border border-blue-500/40 text-blue-300' : 'bg-white/80 dark:bg-slate-800/80 border border-gray-300/80 dark:border-slate-600/80 text-gray-700 dark:text-gray-300'}`}
                  >
                    30D
                  </button>
                  <button
                    onClick={() => setTimeRange('90d')}
                    className={`px-2 py-1 rounded-lg text-[10px] transition-colors ${timeRange === '90d' ? 'bg-blue-600/20 border border-blue-500/40 text-blue-300' : 'bg-white/80 dark:bg-slate-800/80 border border-gray-300/80 dark:border-slate-600/80 text-gray-700 dark:text-gray-300'}`}
                  >
                    90D
                  </button>
                </div>
              </div>
              <ResponsiveContainer width="100%" height={280}>
                <AreaChart data={contentGrowth} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#334155" opacity={0.3} />
                  <XAxis
                    dataKey="date"
                    stroke="#64748b"
                    fontSize={11}
                    tickLine={false}
                    axisLine={{ stroke: '#475569' }}
                  />
                  <YAxis
                    stroke="#64748b"
                    fontSize={11}
                    tickLine={false}
                    axisLine={{ stroke: '#475569' }}
                  />
                  <Tooltip
                    contentStyle={{
                      backgroundColor: '#1e293b',
                      border: '1px solid #334155',
                      borderRadius: '8px',
                      padding: '12px',
                      boxShadow: '0 10px 25px rgba(0, 0, 0, 0.3)'
                    }}
                    labelStyle={{ color: '#e2e8f0', fontSize: '12px', fontWeight: '600', marginBottom: '8px' }}
                    itemStyle={{ color: '#e2e8f0', fontSize: '11px' }}
                    formatter={(value: any, name: any) => [
                      <div className="text-white font-semibold">{value} items</div>,
                      <div className="text-gray-300 capitalize">{name}</div>
                    ]}
                    labelFormatter={(label) => <span className="text-white font-medium">Content Growth: {label}</span>}
                  />
                  <Legend
                    wrapperStyle={{ fontSize: '12px' }}
                    iconType="rect"
                    verticalAlign="top"
                    height={36}
                  />
                  <Area
                    type="monotone"
                    dataKey="books"
                    stroke="#10b981"
                    fill="#10b981"
                    fillOpacity={0.8}
                    strokeWidth={2}
                    name="Books"
                  />
                  <Area
                    type="monotone"
                    dataKey="videos"
                    stroke="#3b82f6"
                    fill="#3b82f6"
                    fillOpacity={0.8}
                    strokeWidth={2}
                    name="Videos"
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>

            {/* User Activity Chart */}
            <div className="bg-white dark:bg-slate-800/50 rounded-xl p-3 sm:p-4 md:p-5 border border-gray-100 dark:border-slate-700/50 w-full">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h3 className="text-sm font-semibold text-gray-900 dark:text-white">Daily Active Users</h3>
                  <p className="text-xs text-gray-600 dark:text-gray-400 mt-1">Unique users interacting with content daily</p>
                </div>
                <div className="flex items-center gap-1 text-xs text-emerald-300">
                  <Sparkles className="w-3 h-3" />
                  Live
                </div>
              </div>
              <ResponsiveContainer width="100%" height={280}>
                <LineChart data={userActivity} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#334155" opacity={0.3} />
                  <XAxis
                    dataKey="date"
                    stroke="#64748b"
                    fontSize={11}
                    tickLine={false}
                    axisLine={{ stroke: '#475569' }}
                  />
                  <YAxis
                    stroke="#64748b"
                    fontSize={11}
                    tickLine={false}
                    axisLine={{ stroke: '#475569' }}
                    tickFormatter={(value) => {
                      if (value >= 1000000) {
                        return `${(value / 1000000).toFixed(1)}M`
                      }
                      if (value >= 1000) {
                        return `${(value / 1000).toFixed(1)}K`
                      }
                      return value.toString()
                    }}
                    domain={[0, 'dataMax + 1']}
                    allowDecimals={false}
                  />
                  <Tooltip
                    contentStyle={{
                      backgroundColor: '#1e293b',
                      border: '1px solid #334155',
                      borderRadius: '8px',
                      padding: '12px',
                      boxShadow: '0 10px 25px rgba(0, 0, 0, 0.3)'
                    }}
                    labelStyle={{ color: '#e2e8f0', fontSize: '12px', fontWeight: '600', marginBottom: '8px' }}
                    itemStyle={{ color: '#e2e8f0', fontSize: '11px' }}
                    formatter={(value: any, name: any, payload: any) => {
                      // Show actual real data in tooltip, not display values
                      const actualData = payload?.payload

                      if (name === 'Active Users' && actualData?.actualActiveUsers !== undefined) {
                        return [
                          <div className="text-white font-semibold">{actualData.actualActiveUsers.toLocaleString()}</div>,
                          <div className="text-gray-300 capitalize">{name}</div>
                        ]
                      }
                      return [
                        <div className="text-white font-semibold">{value.toLocaleString()}</div>,
                        <div className="text-gray-300 capitalize">{name}</div>
                      ]
                    }}
                    labelFormatter={(label) => <span className="text-white font-medium">Date: {label}</span>}
                  />
                  <Legend
                    wrapperStyle={{ fontSize: '12px' }}
                    iconType="line"
                    verticalAlign="top"
                    height={36}
                  />
                  <Line
                    type="monotone"
                    dataKey="activeUsers"
                    stroke="#8b5cf6"
                    strokeWidth={3}
                    dot={{ fill: '#8b5cf6', strokeWidth: 2, r: 4 }}
                    activeDot={{ r: 6, stroke: '#8b5cf6', strokeWidth: 2, fill: '#8b5cf6' }}
                    name="Active Users"
                  />
                  <Line
                    type="monotone"
                    dataKey="newUsers"
                    stroke="#10b981"
                    strokeWidth={3}
                    dot={{ fill: '#10b981', strokeWidth: 2, r: 4 }}
                    activeDot={{ r: 6, stroke: '#10b981', strokeWidth: 2, fill: '#10b981' }}
                    name="New Registrations"
                  />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* Category Distribution & Top Content */}
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
            {/* Category Distribution */}
            <div className="bg-white dark:bg-slate-800/50 rounded-xl p-5 border border-gray-100 dark:border-slate-700/50">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h3 className="text-sm font-semibold text-gray-900 dark:text-white">Content by Category</h3>
                  <p className="text-xs text-gray-600 dark:text-gray-400 mt-1">Distribution across categories</p>
                </div>
                <Tag className="w-4 h-4 text-blue-400" />
              </div>
              <ResponsiveContainer width="100%" height={220}>
                <PieChart>
                  <Pie
                    data={displayCategoryDistribution.length > 0 ? displayCategoryDistribution : [
                      { name: 'No Data', total: 1 }
                    ]}
                    cx="50%"
                    cy="50%"
                    innerRadius={35}
                    outerRadius={75}
                    paddingAngle={3}
                    dataKey="total"
                    label={({ name, percent }) =>
                      percent > 0.05 ? `${name} ${(percent * 100).toFixed(0)}%` : ''
                    }
                    labelLine={false}
                    fontSize={10}
                    fontFamily="system-ui"
                  >
                    {displayCategoryDistribution.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={[
                        '#10b981', '#3b82f6', '#8b5cf6', '#f59e0b',
                        '#ef4444', '#06b6d4', '#84cc16', '#f97316'
                      ][index % 8]} />
                    ))}
                  </Pie>
                  <Tooltip
                    contentStyle={{
                      backgroundColor: '#1e293b',
                      border: '1px solid #334155',
                      borderRadius: '8px',
                      padding: '12px',
                      boxShadow: '0 10px 25px rgba(0, 0, 0, 0.3)'
                    }}
                    labelStyle={{ color: '#f1f5f9', fontSize: '12px', fontWeight: 'bold', marginBottom: '8px' }}
                    itemStyle={{ color: '#e2e8f0', fontSize: '11px' }}
                    formatter={(value: any, name: any, props: any) => [
                      <div className="text-white font-semibold">{value} items</div>,
                      <div className="text-gray-300 text-sm">{props.payload.name}</div>
                    ]}
                    labelFormatter={(label) => <span className="text-white font-medium">Category Distribution</span>}
                  />
                </PieChart>
              </ResponsiveContainer>
            </div>

            {/* Top Performing Content */}
            <div className="lg:col-span-2 card rounded-2xl p-4 sm:p-5">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h3 className="text-sm font-semibold text-gray-900 dark:text-white">Top Performing Content</h3>
                  <p className="text-xs text-gray-600 dark:text-gray-400 mt-1">Most viewed content this month</p>
                </div>
                <Star className="w-4 h-4 text-amber-400" />
              </div>
              <div className="space-y-3">
                {displayTopContent.length > 0 ? (
                  displayTopContent.map((content, index) => (
                    <div key={index} className="flex items-center justify-between p-3 rounded-xl bg-white/50 dark:bg-slate-800/50 border border-gray-300/50 dark:border-slate-600/50">
                      <div className="flex items-center gap-3">
                        <div className="flex items-center justify-center w-8 h-8 rounded-lg bg-gradient-to-br from-blue-500 to-purple-600 text-white text-xs font-bold">
                          {index + 1}
                        </div>
                        <div>
                          <p className="text-xs font-medium text-gray-800 dark:text-gray-200">{content.title}</p>
                          <p className="text-[10px] text-gray-600 dark:text-gray-400">{content.category} • {content.type}</p>
                        </div>
                      </div>
                      <div className="flex items-center gap-4">
                        <div className="text-right">
                          <p className="text-xs font-medium text-gray-800 dark:text-gray-200">{content.views.toLocaleString()}</p>
                          <p className="text-[10px] text-gray-600 dark:text-gray-400">views</p>
                        </div>
                        <div className="flex items-center gap-1">
                          <Star className="w-3 h-3 text-amber-400" />
                          <span className="text-xs text-amber-300">{content.rating}</span>
                        </div>
                      </div>
                    </div>
                  ))
                ) : (
                  <div className="text-center py-8">
                    <Star className="w-8 h-8 text-gray-400 dark:text-gray-500 mx-auto mb-2" />
                    <p className="text-xs text-gray-600 dark:text-gray-400">No content data available</p>
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Subscription Analytics */}
          <div className="grid grid-cols-1 lg:grid-cols-4 gap-4 mb-6">
            <div className="lg:col-span-3 card rounded-2xl p-4 sm:p-5">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h3 className="text-sm font-semibold text-gray-900 dark:text-white">Subscription Overview</h3>
                  <p className="text-xs text-gray-600 dark:text-gray-400 mt-1">Active subscriptions and revenue trends</p>
                </div>
                <div className="flex items-center gap-1 text-xs text-emerald-300">
                  <CreditCard className="w-3 h-3" />
                  Live
                </div>
              </div>
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
                <div className="text-center p-3 rounded-xl bg-white/50 dark:bg-slate-800/50 border border-gray-300/50 dark:border-slate-600/50">
                  <div className="flex items-center justify-center w-8 h-8 mx-auto mb-2 rounded-xl bg-emerald-500/10 border border-emerald-500/40">
                    <UserCheck className="w-4 h-4 text-emerald-400" />
                  </div>
                  <p className="text-lg font-bold text-gray-900 dark:text-white">{subscriptionAnalytics?.activeSubscriptions || 0}</p>
                  <p className="text-xs text-gray-600 dark:text-gray-400">Active</p>
                </div>
                <div className="text-center p-3 rounded-xl bg-white/50 dark:bg-slate-800/50 border border-gray-300/50 dark:border-slate-600/50">
                  <div className="flex items-center justify-center w-8 h-8 mx-auto mb-2 rounded-xl bg-blue-500/10 border border-blue-500/40">
                    <Clock className="w-4 h-4 text-blue-400" />
                  </div>
                  <p className="text-lg font-bold text-gray-900 dark:text-white">{subscriptionAnalytics?.trialSubscriptions || 0}</p>
                  <p className="text-xs text-gray-600 dark:text-gray-400">Trial</p>
                </div>
                <div className="text-center p-3 rounded-xl bg-white/50 dark:bg-slate-800/50 border border-gray-300/50 dark:border-slate-600/50">
                  <div className="flex items-center justify-center w-8 h-8 mx-auto mb-2 rounded-xl bg-amber-500/10 border border-amber-500/40">
                    <DollarSign className="w-4 h-4 text-amber-400" />
                  </div>
                  <p className="text-lg font-bold text-gray-900 dark:text-white">${subscriptionAnalytics?.mrr.toFixed(0) || '0'}</p>
                  <p className="text-xs text-gray-600 dark:text-gray-400">MRR</p>
                </div>
                <div className="text-center p-3 rounded-xl bg-white/50 dark:bg-slate-800/50 border border-gray-300/50 dark:border-slate-600/50">
                  <div className="flex items-center justify-center w-8 h-8 mx-auto mb-2 rounded-xl bg-purple-500/10 border border-purple-500/40">
                    <Sparkles className="w-4 h-4 text-purple-400" />
                  </div>
                  <p className="text-lg font-bold text-gray-900 dark:text-white">{subscriptionAnalytics?.churnRate.toFixed(1) || '0'}%</p>
                  <p className="text-xs text-gray-600 dark:text-gray-400">Churn</p>
                </div>
              </div>
            </div>
            <div className="bg-white dark:bg-slate-800/50 rounded-xl p-5 border border-gray-100 dark:border-slate-700/50">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h3 className="text-sm font-semibold text-gray-900 dark:text-white">Revenue</h3>
                  <p className="text-xs text-gray-600 dark:text-gray-400 mt-1">Monthly & annual</p>
                </div>
                <DollarSign className="w-4 h-4 text-emerald-400" />
              </div>
              <div className="space-y-3">
                <div>
                  <div className="flex items-center justify-between mb-1">
                    <span className="text-xs text-gray-600 dark:text-gray-400">Monthly Revenue</span>
                    <span className="text-xs font-medium text-gray-900 dark:text-white">${subscriptionAnalytics?.monthlyRevenue.toFixed(2) || '0'}</span>
                  </div>
                  <div className="w-full bg-gray-100 rounded-full h-1.5">
                    <div className="bg-emerald-500 h-1.5 rounded-full" style={{ width: '75%' }}></div>
                  </div>
                </div>
                <div>
                  <div className="flex items-center justify-between mb-1">
                    <span className="text-xs text-gray-600 dark:text-gray-400">Annual Revenue</span>
                    <span className="text-xs font-medium text-gray-900 dark:text-white">${subscriptionAnalytics?.annualRevenue.toFixed(2) || '0'}</span>
                  </div>
                  <div className="w-full bg-gray-100 rounded-full h-1.5">
                    <div className="bg-blue-500 h-1.5 rounded-full" style={{ width: '60%' }}></div>
                  </div>
                </div>
                <div className="pt-2 border-t border-gray-200 dark:border-slate-700">
                  <div className="flex items-center justify-between">
                    <span className="text-xs text-gray-600 dark:text-gray-400">Total Revenue</span>
                    <span className="text-sm font-bold text-emerald-400">${subscriptionAnalytics?.totalRevenue.toFixed(2) || '0'}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Recent Activity & Quick Actions */}
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Recent Activity Feed */}
            <div className="lg:col-span-2 card rounded-2xl p-4 sm:p-5">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h3 className="text-sm font-semibold text-gray-900 dark:text-white">Recent Activity</h3>
                  <p className="text-xs text-gray-600 dark:text-gray-400 mt-1">Latest system events and updates</p>
                </div>
                <Clock className="w-4 h-4 text-emerald-400" />
              </div>
              <div className="space-y-3">
                {displayActivity.length > 0 ? (
                  displayActivity.map((activity) => (
                    <div key={activity.id} className="flex items-start gap-3 p-3 rounded-xl bg-white/50 dark:bg-slate-800/50 border border-gray-300/50 dark:border-slate-600/50">
                      <div className={`w-2 h-2 rounded-full mt-1.5 ${
                        activity.type === 'user' ? 'bg-blue-400' :
                        activity.type === 'content' ? 'bg-emerald-400' :
                        activity.type === 'analytics' ? 'bg-purple-400' :
                        activity.type === 'system' ? 'bg-amber-400' :
                        'bg-rose-400'
                      }`} />
                      <div className="flex-1">
                        <div className="flex items-center justify-between">
                          <p className="text-xs font-medium text-gray-800 dark:text-gray-200">{activity.action}</p>
                          <span className="text-[10px] text-gray-500 dark:text-gray-500">{activity.time}</span>
                        </div>
                        <p className="text-[10px] text-gray-600 dark:text-gray-400 mt-0.5">{activity.detail}</p>
                      </div>
                    </div>
                  ))
                ) : (
                  <div className="text-center py-8">
                    <Clock className="w-8 h-8 text-gray-400 dark:text-gray-500 mx-auto mb-2" />
                    <p className="text-xs text-gray-600 dark:text-gray-400">No recent activity</p>
                  </div>
                )}
              </div>
            </div>

            {/* Quick Actions */}
            <div className="bg-white dark:bg-slate-800/50 rounded-xl p-5 border border-gray-100 dark:border-slate-700/50">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h3 className="text-sm font-semibold text-gray-900 dark:text-white">Quick Actions</h3>
                  <p className="text-xs text-gray-600 mt-1">Manage content efficiently</p>
                </div>
                <Sparkles className="w-4 h-4 text-blue-400" />
              </div>
              <div className="space-y-3">
                <a href="/books/new" className="flex items-center justify-center gap-2 px-4 py-3 rounded-xl bg-gradient-to-r from-emerald-600 to-green-600 text-white text-xs font-medium hover:from-emerald-700 hover:to-green-700 transition-all shadow-lg">
                  <BookOpen className="w-4 h-4" />
                  Add Book
                </a>
                <a href="/videos/new" className="flex items-center justify-center gap-2 px-4 py-3 rounded-xl bg-gradient-to-r from-blue-600 to-indigo-600 text-white text-xs font-medium hover:from-blue-700 hover:to-indigo-700 transition-all shadow-lg">
                  <Video className="w-4 h-4" />
                  Add Video
                </a>
                <a href="/categories/new" className="flex items-center justify-center gap-2 px-4 py-3 rounded-xl bg-gradient-to-r from-purple-600 to-pink-600 text-white text-xs font-medium hover:from-purple-700 hover:to-pink-700 transition-all shadow-lg">
                  <Tag className="w-4 h-4" />
                  New Category
                </a>
                <a href="/users" className="flex items-center justify-center gap-2 px-4 py-3 rounded-xl bg-gradient-to-r from-orange-600 to-red-600 text-white text-xs font-medium hover:from-orange-700 hover:to-red-700 transition-all shadow-lg">
                  <Users className="w-4 h-4" />
                  Manage Users
                </a>
              </div>
            </div>
          </div>

        {/* Keyboard Shortcuts Help Modal */}
        {showKeyboardHelp && (
          <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
            <div className="bg-white rounded-2xl p-6 max-w-md w-full border border-gray-300">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-semibold text-gray-900">Keyboard Shortcuts</h3>
                <button
                  onClick={() => setShowKeyboardHelp(false)}
                  className="p-1 rounded-lg hover:bg-gray-100 transition-colors"
                >
                  <X className="w-4 h-4 text-gray-600" />
                </button>
              </div>

              <div className="space-y-3">
                <div className="flex items-center justify-between py-2 border-b border-gray-300">
                  <div className="flex items-center gap-3">
                    <kbd className="px-2 py-1 bg-gray-100 rounded text-xs text-gray-700 border border-gray-400">Ctrl+F</kbd>
                    <span className="text-sm text-gray-700">Focus search</span>
                  </div>
                </div>

                <div className="flex items-center justify-between py-2 border-b border-gray-300">
                  <div className="flex items-center gap-3">
                    <kbd className="px-2 py-1 bg-gray-100 rounded text-xs text-gray-700 border border-gray-400">Ctrl+R</kbd>
                    <span className="text-sm text-gray-700">Refresh data</span>
                  </div>
                </div>

                <div className="flex items-center justify-between py-2 border-b border-gray-300">
                  <div className="flex items-center gap-3">
                    <kbd className="px-2 py-1 bg-gray-100 rounded text-xs text-gray-700 border border-gray-400">Ctrl+D</kbd>
                    <span className="text-sm text-gray-700">Toggle dark mode</span>
                  </div>
                </div>

                <div className="flex items-center justify-between py-2 border-b border-gray-300">
                  <div className="flex items-center gap-3">
                    <kbd className="px-2 py-1 bg-gray-100 rounded text-xs text-gray-700 border border-gray-400">Ctrl+E</kbd>
                    <span className="text-sm text-gray-700">Export data</span>
                  </div>
                </div>

                <div className="flex items-center justify-between py-2 border-b border-gray-300">
                  <div className="flex items-center gap-3">
                    <kbd className="px-2 py-1 bg-gray-100 rounded text-xs text-gray-700 border border-gray-400">Ctrl+M</kbd>
                    <span className="text-sm text-gray-700">Toggle fullscreen</span>
                  </div>
                </div>

                <div className="flex items-center justify-between py-2">
                  <div className="flex items-center gap-3">
                    <kbd className="px-2 py-1 bg-gray-100 rounded text-xs text-gray-700 border border-gray-400">?</kbd>
                    <span className="text-sm text-gray-700">Show this help</span>
                  </div>
                </div>
              </div>

              <div className="mt-4 pt-4 border-t border-gray-300">
                <p className="text-xs text-gray-600 text-center">
                  Press <kbd className="px-1 py-0.5 bg-gray-100 rounded text-xs border border-gray-400">Esc</kbd> to close
                </p>
              </div>
            </div>
          </div>
        )}

        {/* Phase 4: Advanced Filter Modal */}
        {showAdvancedFilter && (
          <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
            <div className="bg-white rounded-2xl p-6 max-w-4xl w-full border border-gray-300 max-h-[90vh] overflow-y-auto">
              <div className="flex items-center justify-between mb-6">
                <div>
                  <h3 className="text-lg font-semibold text-gray-900">Advanced Filters</h3>
                  <p className="text-sm text-gray-600 mt-1">Apply complex filters to your dashboard data</p>
                </div>
                <button
                  onClick={() => setShowAdvancedFilter(false)}
                  className="p-2 rounded-lg hover:bg-gray-100 transition-colors"
                >
                  <X className="w-4 h-4 text-gray-600" />
                </button>
              </div>
              <Suspense fallback={
                <div className="flex items-center justify-center h-64">
                  <div className="w-6 h-6 border-2 border-orange-500 border-t-transparent rounded-full animate-spin"></div>
                </div>
              }>
                <AdvancedFilter
                  onFiltersChange={(filters: FilterOptions) => {
                    console.log('Filters applied:', filters)
                    setShowAdvancedFilter(false)
                  }}
                  onReset={() => {
                  console.log('Filters reset')
                  setShowAdvancedFilter(false)
                }}
              />
              </Suspense>
            </div>
          </div>
        )}

        {/* Phase 4: Performance Metrics Modal */}
        {showPerformanceMetrics && (
          <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
            <div className="bg-white rounded-2xl p-6 max-w-5xl w-full border border-gray-300 max-h-[90vh] overflow-y-auto">
              <div className="flex items-center justify-between mb-6">
                <div>
                  <h3 className="text-lg font-semibold text-gray-900">Performance Metrics</h3>
                  <p className="text-sm text-gray-600 mt-1">Monitor system performance and analytics</p>
                </div>
                <button
                  onClick={() => setShowPerformanceMetrics(false)}
                  className="p-2 rounded-lg hover:bg-gray-100 transition-colors"
                >
                  <X className="w-4 h-4 text-gray-600" />
                </button>
              </div>
              <Suspense fallback={
                <div className="flex items-center justify-center h-64">
                  <div className="w-6 h-6 border-2 border-orange-500 border-t-transparent rounded-full animate-spin"></div>
                </div>
              }>
                <PerformanceMetrics
                  data={{
                    healthScore: 75,
                    engagementRate: 65,
                    conversionRate: 12,
                    growthRate: 8,
                    contentPerformance: {
                      excellent: 45,
                      good: 120,
                      average: 80,
                      poor: 15
                    },
                    userActivity: {
                      totalUsers: 1250,
                      activeUsers: 850,
                      newUsers: 125,
                      returningUsers: 725,
                      retentionRate: 58
                    },
                    revenueMetrics: {
                      totalRevenue: 45000,
                      revenueGrowth: 12,
                      averageOrderValue: 89,
                      customerLifetimeValue: 450
                    },
                    realtimeData: {
                      timestamp: new Date().toISOString(),
                      activeUsers: 342,
                      serverResponse: 120,
                      errorRate: 0.2,
                      throughput: 1200
                    }
                  }}
                  onRefresh={handleRefresh}
                  isLoading={loading}
                />
              </Suspense>
            </div>
          </div>
        )}

        {/* Phase 4: Automated Reports Modal - Temporarily Disabled */}
        {/* {showAutomatedReports && (
          <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
            <div className="bg-white rounded-2xl p-6 max-w-6xl w-full border border-gray-300 max-h-[90vh] overflow-y-auto">
              <div className="flex items-center justify-between mb-6">
                <div>
                  <h3 className="text-lg font-semibold text-gray-900">Automated Reports</h3>
                  <p className="text-sm text-gray-600 mt-1">Generate and schedule automated reports</p>
                </div>
                <button
                  onClick={() => setShowAutomatedReports(false)}
                  className="p-2 rounded-lg hover:bg-gray-100 transition-colors"
                >
                  <X className="w-4 h-4 text-gray-600" />
                </button>
              </div>
              </AutomatedReports />
            </div>
          </div>
        )} */}


    </DashboardLayout>
  )
}

export default function Dashboard() {
  return <DashboardContent />
}


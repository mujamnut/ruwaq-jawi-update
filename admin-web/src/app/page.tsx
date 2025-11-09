'use client'

import { useState, useEffect } from 'react'
import { supabase } from "@/lib/supabase"
import QueryProvider from "@/components/query-provider"
import Sidebar from "@/components/sidebar"
import Header from "@/components/header"
import AuthGuard from "@/components/auth-guard"
import {
  LineChart,
  Line,
  BarChart,
  Bar,
  PieChart,
  Pie,
  Cell,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  AreaChart,
  Area
} from 'recharts'
import {
  TrendingUp,
  TrendingDown,
  Users,
  BookOpen,
  Video,
  Tag,
  Activity,
  Eye,
  Download,
  Star,
  Calendar,
  Clock
} from 'lucide-react'

function DashboardContent() {
  const [stats, setStats] = useState({
    books: 0,
    categories: 0,
    videos: 0,
    users: 0,
    activeUsers: 0,
    premiumUsers: 0,
    totalViews: 0,
    newUsers: 0
  })
  const [loading, setLoading] = useState(true)
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)
  const [timeRange, setTimeRange] = useState<'7d' | '30d' | '90d'>('30d')
  const [contentGrowth, setContentGrowth] = useState<any[]>([])
  const [categoryDistribution, setCategoryDistribution] = useState<any[]>([])
  const [userActivity, setUserActivity] = useState<any[]>([])
  const [topContent, setTopContent] = useState<any[]>([])
  const [recentActivity, setRecentActivity] = useState<any[]>([])

  useEffect(() => {
    const fetchAnalyticsData = async () => {
      try {
        setLoading(true)

        // Fetch basic stats
        const [booksRes, categoriesRes, videosRes, usersRes] = await Promise.all([
          supabase.from('ebooks').select('id', { count: 'exact' }),
          supabase.from('categories').select('id', { count: 'exact' }),
          supabase.from('video_kitab').select('id', { count: 'exact' }),
          supabase.from('profiles').select('id', { count: 'exact' })
        ])

        // Fetch detailed user stats
        const { data: profiles } = await supabase
          .from('profiles')
          .select('role, is_active, created_at')

        const activeUsers = profiles?.filter(p => p.is_active).length || 0
        const premiumUsers = profiles?.filter(p => p.role === 'premium').length || 0

        // Calculate time-based stats
        const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
        const newUsers = profiles?.filter(p => new Date(p.created_at) > thirtyDaysAgo).length || 0

        // Fetch content by categories
        const { data: categoryData } = await supabase
          .from('categories')
          .select(`
            id,
            name,
            ebooks!inner(id),
            video_kitab!inner(id)
          `)

        // Generate mock analytics data (replace with real analytics later)
        const mockContentGrowth = [
          { date: '2024-01', books: 12, videos: 5, total: 17 },
          { date: '2024-02', books: 15, videos: 8, total: 23 },
          { date: '2024-03', books: 18, videos: 12, total: 30 },
          { date: '2024-04', books: 22, videos: 15, total: 37 },
          { date: '2024-05', books: 28, videos: 18, total: 46 },
          { date: '2024-06', books: 35, videos: 22, total: 57 },
          { date: '2024-07', books: 42, videos: 28, total: 70 },
          { date: '2024-08', books: 48, videos: 35, total: 83 },
          { date: '2024-09', books: 55, videos: 42, total: 97 },
          { date: '2024-10', books: 62, videos: 48, total: 110 },
          { date: '2024-11', books: booksRes.count || 68, videos: videosRes.count || 52, total: (booksRes.count || 0) + (videosRes.count || 0) }
        ]

        const mockUserActivity = [
          { date: 'Mon', activeUsers: 245, newUsers: 12, sessions: 1823 },
          { date: 'Tue', activeUsers: 289, newUsers: 18, sessions: 2156 },
          { date: 'Wed', activeUsers: 312, newUsers: 15, sessions: 2341 },
          { date: 'Thu', activeUsers: 298, newUsers: 22, sessions: 2234 },
          { date: 'Fri', activeUsers: 356, newUsers: 28, sessions: 2678 },
          { date: 'Sat', activeUsers: 412, newUsers: 35, sessions: 3102 },
          { date: 'Sun', activeUsers: 389, newUsers: 31, sessions: 2923 }
        ]

        const mockCategoryDistribution = categoryData?.map(cat => ({
          name: cat.name,
          books: cat.ebooks?.length || 0,
          videos: cat.video_kitab?.length || 0,
          total: (cat.ebooks?.length || 0) + (cat.video_kitab?.length || 0)
        })) || []

        const mockTopContent = [
          { title: 'Al-Quran Basic', type: 'ebook', views: 15234, category: 'Islamic Studies', rating: 4.8 },
          { title: 'Solat Complete Guide', type: 'video', views: 12456, category: 'Prayer', rating: 4.9 },
          { title: 'Hajj & Umrah', type: 'ebook', views: 9876, category: 'Pilgrimage', rating: 4.7 },
          { title: 'Islamic History', type: 'video', views: 8234, category: 'History', rating: 4.6 },
          { title: 'Arabic Language', type: 'ebook', views: 7123, category: 'Language', rating: 4.5 }
        ]

        const mockRecentActivity = [
          { id: 1, action: 'New user registration', detail: '15 new users today', time: '2 hours ago', type: 'user' },
          { id: 2, action: 'Content uploaded', detail: '3 new books added', time: '4 hours ago', type: 'content' },
          { id: 3, action: 'High engagement', detail: 'Video views up 25%', time: '6 hours ago', type: 'analytics' },
          { id: 4, action: 'System update', detail: 'Database optimized', time: '8 hours ago', type: 'system' },
          { id: 5, action: 'Premium upgrade', detail: '8 users upgraded', time: '12 hours ago', type: 'revenue' }
        ]

        setStats({
          books: booksRes.count || 0,
          categories: categoriesRes.count || 0,
          videos: videosRes.count || 0,
          users: usersRes.count || 0,
          activeUsers,
          premiumUsers,
          totalViews: 48293,
          newUsers
        })

        setContentGrowth(mockContentGrowth)
        setCategoryDistribution(mockCategoryDistribution)
        setUserActivity(mockUserActivity)
        setTopContent(mockTopContent)
        setRecentActivity(mockRecentActivity)

      } catch (error) {
        console.error('Error fetching analytics data:', error)
      } finally {
        setLoading(false)
      }
    }

    fetchAnalyticsData()
  }, [timeRange])

  return (
    <div className="flex min-h-screen bg-slate-950 text-slate-100 antialiased">
      {/* Sidebar */}
      <Sidebar isCollapsed={sidebarCollapsed} onToggle={() => setSidebarCollapsed(!sidebarCollapsed)} />

      {/* Main Content */}
      <div className="flex-1 flex flex-col min-h-screen lg:ml-0 ml-0">
        {/* Header */}
        <Header
          onMenuToggle={() => setSidebarCollapsed(!sidebarCollapsed)}
          title="Analytics Dashboard"
          subtitle="Real-time insights & performance metrics"
        />

        {/* Main Dashboard Content */}
        <main className="flex-1 px-4 sm:px-6 pb-8 pt-4 bg-gradient-to-br from-slate-950 via-slate-950 to-slate-900">
          {/* Top Stats Cards */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
            <div className="card rounded-2xl p-4 sm:p-5 border-l-4 border-l-emerald-500">
              <div className="flex items-center justify-between mb-2">
                <div className="p-2 rounded-xl bg-emerald-500/10 border border-emerald-500/40">
                  <BookOpen className="w-5 h-5 text-emerald-400" />
                </div>
                <span className="flex items-center gap-1 text-xs text-emerald-300">
                  <TrendingUp className="w-3 h-3" />
                  +12%
                </span>
              </div>
              <h3 className="text-2xl font-bold mb-1">{loading ? '...' : stats.books}</h3>
              <p className="text-xs text-slate-400">Total Books</p>
            </div>

            <div className="card rounded-2xl p-4 sm:p-5 border-l-4 border-l-blue-500">
              <div className="flex items-center justify-between mb-2">
                <div className="p-2 rounded-xl bg-blue-500/10 border border-blue-500/40">
                  <Video className="w-5 h-5 text-blue-400" />
                </div>
                <span className="flex items-center gap-1 text-xs text-blue-300">
                  <TrendingUp className="w-3 h-3" />
                  +8%
                </span>
              </div>
              <h3 className="text-2xl font-bold mb-1">{loading ? '...' : stats.videos}</h3>
              <p className="text-xs text-slate-400">Video Collections</p>
            </div>

            <div className="card rounded-2xl p-4 sm:p-5 border-l-4 border-l-purple-500">
              <div className="flex items-center justify-between mb-2">
                <div className="p-2 rounded-xl bg-purple-500/10 border border-purple-500/40">
                  <Users className="w-5 h-5 text-purple-400" />
                </div>
                <span className="flex items-center gap-1 text-xs text-purple-300">
                  <TrendingUp className="w-3 h-3" />
                  +15%
                </span>
              </div>
              <h3 className="text-2xl font-bold mb-1">{loading ? '...' : stats.activeUsers}</h3>
              <p className="text-xs text-slate-400">Active Users</p>
            </div>

            <div className="card rounded-2xl p-4 sm:p-5 border-l-4 border-l-amber-500">
              <div className="flex items-center justify-between mb-2">
                <div className="p-2 rounded-xl bg-amber-500/10 border border-amber-500/40">
                  <Eye className="w-5 h-5 text-amber-400" />
                </div>
                <span className="flex items-center gap-1 text-xs text-amber-300">
                  <TrendingUp className="w-3 h-3" />
                  +22%
                </span>
              </div>
              <h3 className="text-2xl font-bold mb-1">{stats.totalViews.toLocaleString()}</h3>
              <p className="text-xs text-slate-400">Total Views</p>
            </div>
          </div>

          {/* Charts Section */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
            {/* Content Growth Chart */}
            <div className="card rounded-2xl p-4 sm:p-5">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h3 className="text-sm font-semibold">Content Growth</h3>
                  <p className="text-xs text-slate-400 mt-1">Monthly content addition trends</p>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => setTimeRange('7d')}
                    className={`px-2 py-1 rounded-lg text-[10px] ${timeRange === '7d' ? 'bg-blue-600/20 border border-blue-500/40 text-blue-300' : 'bg-slate-900/80 border border-slate-700/80 text-slate-300'}`}
                  >
                    7D
                  </button>
                  <button
                    onClick={() => setTimeRange('30d')}
                    className={`px-2 py-1 rounded-lg text-[10px] ${timeRange === '30d' ? 'bg-blue-600/20 border border-blue-500/40 text-blue-300' : 'bg-slate-900/80 border border-slate-700/80 text-slate-300'}`}
                  >
                    30D
                  </button>
                  <button
                    onClick={() => setTimeRange('90d')}
                    className={`px-2 py-1 rounded-lg text-[10px] ${timeRange === '90d' ? 'bg-blue-600/20 border border-blue-500/40 text-blue-300' : 'bg-slate-900/80 border border-slate-700/80 text-slate-300'}`}
                  >
                    90D
                  </button>
                </div>
              </div>
              <ResponsiveContainer width="100%" height={250}>
                <AreaChart data={contentGrowth}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
                  <XAxis dataKey="date" stroke="#64748b" fontSize={10} />
                  <YAxis stroke="#64748b" fontSize={10} />
                  <Tooltip
                    contentStyle={{ backgroundColor: '#1e293b', border: '1px solid #334155', borderRadius: '8px' }}
                    labelStyle={{ color: '#e2e8f0', fontSize: '11px' }}
                  />
                  <Area type="monotone" dataKey="books" stackId="1" stroke="#10b981" fill="#10b981" fillOpacity={0.6} />
                  <Area type="monotone" dataKey="videos" stackId="1" stroke="#3b82f6" fill="#3b82f6" fillOpacity={0.6} />
                </AreaChart>
              </ResponsiveContainer>
            </div>

            {/* User Activity Chart */}
            <div className="card rounded-2xl p-4 sm:p-5">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h3 className="text-sm font-semibold">User Activity</h3>
                  <p className="text-xs text-slate-400 mt-1">Weekly user engagement</p>
                </div>
                <div className="flex items-center gap-1 text-xs text-emerald-300">
                  <Activity className="w-3 h-3" />
                  Live
                </div>
              </div>
              <ResponsiveContainer width="100%" height={250}>
                <LineChart data={userActivity}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
                  <XAxis dataKey="date" stroke="#64748b" fontSize={10} />
                  <YAxis stroke="#64748b" fontSize={10} />
                  <Tooltip
                    contentStyle={{ backgroundColor: '#1e293b', border: '1px solid #334155', borderRadius: '8px' }}
                    labelStyle={{ color: '#e2e8f0', fontSize: '11px' }}
                  />
                  <Line type="monotone" dataKey="activeUsers" stroke="#8b5cf6" strokeWidth={2} dot={{ fill: '#8b5cf6', r: 3 }} />
                  <Line type="monotone" dataKey="newUsers" stroke="#10b981" strokeWidth={2} dot={{ fill: '#10b981', r: 3 }} />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* Category Distribution & Top Content */}
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
            {/* Category Distribution */}
            <div className="card rounded-2xl p-4 sm:p-5">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h3 className="text-sm font-semibold">Content by Category</h3>
                  <p className="text-xs text-slate-400 mt-1">Distribution across categories</p>
                </div>
                <Tag className="w-4 h-4 text-blue-400" />
              </div>
              <ResponsiveContainer width="100%" height={200}>
                <PieChart>
                  <Pie
                    data={categoryDistribution.length > 0 ? categoryDistribution : [
                      { name: 'Islamic Studies', total: 35 },
                      { name: 'Prayer', total: 28 },
                      { name: 'History', total: 22 },
                      { name: 'Language', total: 18 }
                    ]}
                    cx="50%"
                    cy="50%"
                    innerRadius={40}
                    outerRadius={80}
                    paddingAngle={5}
                    dataKey="total"
                  >
                    <Cell fill="#10b981" />
                    <Cell fill="#3b82f6" />
                    <Cell fill="#8b5cf6" />
                    <Cell fill="#f59e0b" />
                  </Pie>
                  <Tooltip
                    contentStyle={{ backgroundColor: '#1e293b', border: '1px solid #334155', borderRadius: '8px' }}
                    labelStyle={{ color: '#e2e8f0', fontSize: '11px' }}
                  />
                </PieChart>
              </ResponsiveContainer>
            </div>

            {/* Top Performing Content */}
            <div className="lg:col-span-2 card rounded-2xl p-4 sm:p-5">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h3 className="text-sm font-semibold">Top Performing Content</h3>
                  <p className="text-xs text-slate-400 mt-1">Most viewed content this month</p>
                </div>
                <Star className="w-4 h-4 text-amber-400" />
              </div>
              <div className="space-y-3">
                {topContent.map((content, index) => (
                  <div key={index} className="flex items-center justify-between p-3 rounded-xl bg-slate-900/50 border border-slate-700/50">
                    <div className="flex items-center gap-3">
                      <div className="flex items-center justify-center w-8 h-8 rounded-lg bg-gradient-to-br from-blue-500 to-purple-600 text-white text-xs font-bold">
                        {index + 1}
                      </div>
                      <div>
                        <p className="text-xs font-medium text-slate-200">{content.title}</p>
                        <p className="text-[10px] text-slate-400">{content.category} • {content.type}</p>
                      </div>
                    </div>
                    <div className="flex items-center gap-4">
                      <div className="text-right">
                        <p className="text-xs font-medium text-slate-200">{content.views.toLocaleString()}</p>
                        <p className="text-[10px] text-slate-400">views</p>
                      </div>
                      <div className="flex items-center gap-1">
                        <Star className="w-3 h-3 text-amber-400" />
                        <span className="text-xs text-amber-300">{content.rating}</span>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Recent Activity & Quick Actions */}
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Recent Activity Feed */}
            <div className="lg:col-span-2 card rounded-2xl p-4 sm:p-5">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h3 className="text-sm font-semibold">Recent Activity</h3>
                  <p className="text-xs text-slate-400 mt-1">Latest system events and updates</p>
                </div>
                <Clock className="w-4 h-4 text-emerald-400" />
              </div>
              <div className="space-y-3">
                {recentActivity.map((activity) => (
                  <div key={activity.id} className="flex items-start gap-3 p-3 rounded-xl bg-slate-900/50 border border-slate-700/50">
                    <div className={`w-2 h-2 rounded-full mt-1.5 ${
                      activity.type === 'user' ? 'bg-blue-400' :
                      activity.type === 'content' ? 'bg-emerald-400' :
                      activity.type === 'analytics' ? 'bg-purple-400' :
                      activity.type === 'system' ? 'bg-amber-400' :
                      'bg-rose-400'
                    }`} />
                    <div className="flex-1">
                      <div className="flex items-center justify-between">
                        <p className="text-xs font-medium text-slate-200">{activity.action}</p>
                        <span className="text-[10px] text-slate-500">{activity.time}</span>
                      </div>
                      <p className="text-[10px] text-slate-400 mt-0.5">{activity.detail}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Quick Actions */}
            <div className="card rounded-2xl p-4 sm:p-5">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h3 className="text-sm font-semibold">Quick Actions</h3>
                  <p className="text-xs text-slate-400 mt-1">Manage content efficiently</p>
                </div>
                <Activity className="w-4 h-4 text-blue-400" />
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
        </main>
      </div>
    </div>
  )
}

export default function Dashboard() {
  return (
    <AuthGuard requireRole="admin">
      <QueryProvider>
        <DashboardContent />
      </QueryProvider>
    </AuthGuard>
  )
}

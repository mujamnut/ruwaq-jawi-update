'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import DashboardLayout from "@/components/dashboard-layout"
import { supabaseAdmin } from '@/lib/supabase'
import {
  Bell,
  Plus,
  Search,
  Filter,
  Check,
  X,
  Trash2,
  Send,
  Mail,
  AlertTriangle,
  Info,
  CheckCircle,
  XCircle,
  Calendar,
  Clock,
  User,
  RefreshCw,
  Users
} from 'lucide-react'

interface Notification {
  id: string
  title: string
  message: string
  type: 'broadcast' | 'personal' | 'group'
  target_type: 'all' | 'user' | 'role'
  target_criteria: Record<string, any>
  metadata: Record<string, any>
  is_active: boolean
  delivered_at?: string
  created_at: string
  expires_at?: string
}

function NotificationsContent() {
  const router = useRouter()
  const [notifications, setNotifications] = useState<Notification[]>([])
  const [searchTerm, setSearchTerm] = useState('')
  const [loading, setLoading] = useState(true)
  const [deleteLoading, setDeleteLoading] = useState<string | null>(null)
  const [typeFilter, setTypeFilter] = useState<'all' | 'broadcast' | 'personal' | 'group'>('all')
  const [refreshKey, setRefreshKey] = useState(0)
  const [selectedNotifications, setSelectedNotifications] = useState<string[]>([])

  useEffect(() => {
    fetchNotifications()
  }, [typeFilter, refreshKey])

  // Refresh data when page becomes visible again
  useEffect(() => {
    const handleVisibilityChange = () => {
      if (document.visibilityState === 'visible') {
        setRefreshKey(prev => prev + 1)
      }
    }

    const handleFocus = () => {
      setRefreshKey(prev => prev + 1)
    }

    document.addEventListener('visibilitychange', handleVisibilityChange)
    window.addEventListener('focus', handleFocus)

    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange)
      window.removeEventListener('focus', handleFocus)
    }
  }, [])

  const fetchNotifications = async () => {
    try {
      setLoading(true)

      // Fetch from database
      const { data, error } = await supabaseAdmin
        .from('notifications')
        .select('*')
        .order('created_at', { ascending: false })

      if (error) {
        console.error('Database error:', error)
        throw error
      }

      // Apply filters
      let filtered = data || []

      if (typeFilter !== 'all') {
        filtered = filtered.filter(n => n.type === typeFilter)
      }

      // Remove expired notifications
      const now = new Date()
      filtered = filtered.filter(n => {
        if (!n.expires_at) return true
        return new Date(n.expires_at) > now
      })

      setNotifications(filtered as Notification[])
    } catch (error) {
      console.error('Error fetching notifications:', error)
      setNotifications([])
    } finally {
      setLoading(false)
    }
  }

  
  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this notification?')) return

    try {
      setDeleteLoading(id)

      // Delete from database
      const { error } = await supabaseAdmin
        .from('notifications')
        .delete()
        .eq('id', id)

      if (error) {
        throw error
      }

      // Update local state
      setNotifications(prev => prev.filter(n => n.id !== id))
    } catch (error) {
      console.error('Error deleting notification:', error)
    } finally {
      setDeleteLoading(null)
    }
  }

  const handleBulkDelete = async () => {
    if (selectedNotifications.length === 0) return
    if (!confirm(`Are you sure you want to delete ${selectedNotifications.length} notifications?`)) return

    try {
      // Delete from database
      const { error } = await supabaseAdmin
        .from('notifications')
        .delete()
        .in('id', selectedNotifications)

      if (error) {
        throw error
      }

      // Update local state
      setNotifications(prev => prev.filter(n => !selectedNotifications.includes(n.id)))
      setSelectedNotifications([])
    } catch (error) {
      console.error('Error deleting notifications:', error)
    }
  }

  
  const handleSelectAll = () => {
    if (selectedNotifications.length === notifications.length) {
      setSelectedNotifications([])
    } else {
      setSelectedNotifications(notifications.map(n => n.id))
    }
  }

  const filteredNotifications = notifications.filter(notification =>
    notification.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
    notification.message.toLowerCase().includes(searchTerm.toLowerCase())
  )

  const getStats = () => {
    const total = notifications.length
    const broadcast = notifications.filter(n => n.type === 'broadcast').length
    const personal = notifications.filter(n => n.type === 'personal').length
    const group = notifications.filter(n => n.type === 'group').length
    const active = notifications.filter(n => n.is_active).length
    const expired = notifications.filter(n => {
      if (!n.expires_at) return false
      return new Date(n.expires_at) <= new Date()
    }).length
    return { total, broadcast, personal, group, active, expired }
  }

  const getNotificationIcon = (type: Notification['type']) => {
    switch (type) {
      case 'broadcast':
        return <Bell className="w-5 h-5 text-blue-500" />
      case 'personal':
        return <User className="w-5 h-5 text-green-500" />
      case 'group':
        return <Users className="w-5 h-5 text-amber-500" />
      default:
        return <Bell className="w-5 h-5 text-gray-500" />
    }
  }

  const getTypeColor = (type: Notification['type']) => {
    switch (type) {
      case 'broadcast':
        return 'bg-blue-500/10 text-blue-300 dark:text-blue-400 border-blue-500/40 dark:border-blue-400/40'
      case 'personal':
        return 'bg-emerald-500/10 text-emerald-300 dark:text-emerald-400 border-emerald-500/40 dark:border-emerald-400/40'
      case 'group':
        return 'bg-amber-500/10 text-amber-300 dark:text-amber-400 border-amber-500/40 dark:border-amber-400/40'
      default:
        return 'bg-slate-500/10 text-gray-700 dark:text-gray-300 border-gray-500/40 dark:border-gray-400/40'
    }
  }

  const formatDate = (dateString: string) => {
    const date = new Date(dateString)
    const now = new Date()
    const diffInHours = (now.getTime() - date.getTime()) / (1000 * 60 * 60)

    if (diffInHours < 1) {
      return 'Just now'
    } else if (diffInHours < 24) {
      return `${Math.floor(diffInHours)}h ago`
    } else {
      return date.toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
        year: date.getFullYear() !== now.getFullYear() ? 'numeric' : undefined
      })
    }
  }

  const stats = getStats()

  return (
    <DashboardLayout title="Notifications" subtitle="Manage system notifications and alerts">
      {/* Main Content */}
      <main className="flex-1 px-4 sm:px-6 pb-8 pt-4 mx-auto max-w-full bg-gray-50 dark:bg-gradient-to-br dark:from-slate-950 dark:via-slate-950 dark:to-slate-900 transition-colors duration-300">
        {/* Page Header */}
        <div className="card rounded-2xl p-4 sm:p-5 mb-4 bg-white dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div>
              <h2 className="text-base sm:text-lg font-semibold mb-1 text-gray-900 dark:text-white">Notification Center</h2>
              <p className="text-xs text-gray-600 dark:text-gray-400">Manage system notifications and alerts</p>
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={() => setRefreshKey(prev => prev + 1)}
                disabled={loading}
                className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-white/90 dark:bg-slate-700/90 border border-gray-300/80 dark:border-slate-600/80 text-[11px] font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-100/90 dark:hover:bg-slate-600/90 disabled:opacity-50 transition-all"
              >
                <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
                Refresh
              </button>
              <button
                onClick={() => router.push('/notifications/new')}
                className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-gradient-to-r from-orange-600 to-red-600 text-white text-xs font-medium hover:from-orange-700 hover:to-red-700 transition-all shadow-lg"
              >
                <Plus className="w-4 h-4" />
                New Notification
              </button>
            </div>
          </div>

          {/* Stats Cards */}
          <div className="grid grid-cols-2 md:grid-cols-6 gap-3 mt-4">
            <div className="rounded-xl border border-gray-300/80 dark:border-slate-600/80 bg-white/80 dark:bg-slate-800/90 p-3">
              <div className="flex items-center justify-between mb-1.5">
                <span className="text-[11px] text-gray-600 dark:text-gray-400">Total</span>
                <span className="px-1.5 py-0.5 rounded-full bg-blue-500/10 text-[10px] text-blue-300 dark:text-blue-400 border border-blue-500/40 dark:border-blue-400/40">
                  {stats.total}
                </span>
              </div>
              <p className="text-lg font-semibold text-gray-900 dark:text-white">{stats.total}</p>
            </div>
            <div className="rounded-xl border border-gray-300/80 dark:border-slate-600/80 bg-white/80 dark:bg-slate-800/90 p-3">
              <div className="flex items-center justify-between mb-1.5">
                <span className="text-[11px] text-gray-600 dark:text-gray-400">Active</span>
                <span className="px-1.5 py-0.5 rounded-full bg-rose-500/10 text-[10px] text-rose-300 dark:text-rose-400 border-rose-500/40 dark:border-rose-400/40">
                  {stats.active}
                </span>
              </div>
              <p className="text-lg font-semibold text-gray-900 dark:text-white">{stats.active}</p>
            </div>
            <div className="rounded-xl border border-gray-300/80 dark:border-slate-600/80 bg-white/80 dark:bg-slate-800/90 p-3">
              <div className="flex items-center justify-between mb-1.5">
                <span className="text-[11px] text-gray-600 dark:text-gray-400">Broadcast</span>
                <span className="px-1.5 py-0.5 rounded-full bg-blue-500/10 text-[10px] text-blue-300 dark:text-blue-400 border border-blue-500/40 dark:border-blue-400/40">
                  {stats.broadcast}
                </span>
              </div>
              <p className="text-lg font-semibold text-gray-900 dark:text-white">{stats.broadcast}</p>
            </div>
            <div className="rounded-xl border border-gray-300/80 dark:border-slate-600/80 bg-white/80 dark:bg-slate-800/90 p-3">
              <div className="flex items-center justify-between mb-1.5">
                <span className="text-[11px] text-gray-600 dark:text-gray-400">Personal</span>
                <span className="px-1.5 py-0.5 rounded-full bg-emerald-500/10 text-[10px] text-emerald-300 dark:text-emerald-400 border-emerald-500/40 dark:border-emerald-400/40">
                  {stats.personal}
                </span>
              </div>
              <p className="text-lg font-semibold text-gray-900 dark:text-white">{stats.personal}</p>
            </div>
            <div className="rounded-xl border border-gray-300/80 dark:border-slate-600/80 bg-white/80 dark:bg-slate-800/90 p-3">
              <div className="flex items-center justify-between mb-1.5">
                <span className="text-[11px] text-gray-600 dark:text-gray-400">Group</span>
                <span className="px-1.5 py-0.5 rounded-full bg-amber-500/10 text-[10px] text-amber-300 dark:text-amber-400 border-amber-500/40 dark:border-amber-400/40">
                  {stats.group}
                </span>
              </div>
              <p className="text-lg font-semibold text-gray-900 dark:text-white">{stats.group}</p>
            </div>
            <div className="rounded-xl border border-gray-300/80 dark:border-slate-600/80 bg-white/80 dark:bg-slate-800/90 p-3">
              <div className="flex items-center justify-between mb-1.5">
                <span className="text-[11px] text-gray-600 dark:text-gray-400">Expired</span>
                <span className="px-1.5 py-0.5 rounded-full bg-rose-500/10 text-[10px] text-rose-300 dark:text-rose-400 border-rose-500/40 dark:border-rose-400/40">
                  {stats.expired}
                </span>
              </div>
              <p className="text-lg font-semibold text-gray-900 dark:text-white">{stats.expired}</p>
            </div>
          </div>
        </div>

        {/* Filters and Search */}
        <div className="card rounded-2xl p-4 sm:p-5 mb-4 bg-white dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div className="flex items-center gap-2 flex-1">
              <div className="relative flex-1 max-w-md">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-600 dark:text-gray-400 w-4 h-4" />
                <input
                  type="text"
                  placeholder="Search notifications..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="pl-10 pr-4 py-2 w-full rounded-xl bg-white/80 dark:bg-slate-700/90 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-orange-500/50 dark:focus:ring-orange-400/50 focus:border-orange-500/50 dark:focus:border-orange-400/50"
                />
              </div>
              <select
                value={typeFilter}
                onChange={(e) => setTypeFilter(e.target.value as any)}
                className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-white/80 dark:bg-slate-700/90 border border-gray-300/80 dark:border-slate-600/80 text-[11px] font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-100/90 dark:hover:bg-slate-600/90"
              >
                <option value="all">All Types</option>
                <option value="broadcast">Broadcast</option>
                <option value="personal">Personal</option>
                <option value="group">Group</option>
              </select>
              </div>
            {selectedNotifications.length > 0 && (
              <div className="flex items-center gap-2">
                <span className="text-[11px] text-gray-600 dark:text-gray-400">
                  {selectedNotifications.length} selected
                </span>
                <button
                  onClick={handleBulkDelete}
                  className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-red-500/10 dark:bg-red-500/20 border border-red-500/40 dark:border-red-400/40 text-[11px] font-medium text-red-600 dark:text-red-400 hover:bg-red-500/20 dark:hover:bg-red-500/30"
                >
                  <Trash2 className="w-3.5 h-3.5" />
                  Delete Selected
                </button>
              </div>
            )}
          </div>
        </div>

        {/* Notifications List */}
        <div className="card rounded-2xl p-4 sm:p-5 bg-white dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80">
          {loading ? (
            <div className="flex items-center justify-center py-12">
              <div className="w-6 h-6 border-2 border-orange-500 border-t-transparent rounded-full animate-spin"></div>
              <span className="ml-2 text-gray-600 dark:text-gray-400">Loading notifications...</span>
            </div>
          ) : filteredNotifications.length === 0 ? (
            <div className="flex flex-col items-center py-12">
              <Bell className="w-12 h-12 text-gray-400 dark:text-gray-600 mb-3" />
              <h3 className="text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">No notifications found</h3>
              <p className="text-[11px] text-gray-500 dark:text-gray-400 mb-4">
                {searchTerm ? 'No notifications match your search criteria' : 'No notifications at this time'}
              </p>
              {!searchTerm && (
                <button
                  onClick={() => router.push('/notifications/new')}
                  className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-gradient-to-r from-orange-600 to-red-600 text-white text-xs font-medium hover:from-orange-700 hover:to-red-700 transition-all shadow-lg"
                >
                  <Plus className="w-4 h-4" />
                  Create First Notification
                </button>
              )}
            </div>
          ) : (
            <div className="space-y-3">
              {/* Select All */}
              <div className="flex items-center gap-3 pb-3 border-b border-gray-200 dark:border-slate-600">
                <input
                  type="checkbox"
                  checked={selectedNotifications.length === notifications.length && notifications.length > 0}
                  onChange={handleSelectAll}
                  className="w-4 h-4 rounded bg-gray-100 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-orange-500 focus:ring-2 focus:ring-orange-500/50"
                />
                <span className="text-[11px] font-medium text-gray-700 dark:text-gray-300">Select All</span>
              </div>

              {filteredNotifications.map((notification) => (
                <div
                  key={notification.id}
                  className="relative p-4 rounded-xl border bg-gray-50/50 dark:bg-slate-700/30 border-gray-200/50 dark:border-slate-600/50 transition-all"
                >
                  <div className="flex items-start gap-3">
                    {/* Checkbox */}
                    <input
                      type="checkbox"
                      checked={selectedNotifications.includes(notification.id)}
                      onChange={(e) => {
                        if (e.target.checked) {
                          setSelectedNotifications(prev => [...prev, notification.id])
                        } else {
                          setSelectedNotifications(prev => prev.filter(id => id !== notification.id))
                        }
                      }}
                      className="mt-1 w-4 h-4 rounded bg-gray-100 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-orange-500 focus:ring-2 focus:ring-orange-500/50"
                    />

                    {/* Icon */}
                    <div className="mt-0.5">
                      {getNotificationIcon(notification.type)}
                    </div>

                    {/* Content */}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-start justify-between gap-2">
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2 mb-1">
                            <h3 className="text-sm font-medium text-gray-900 dark:text-white truncate">
                              {notification.title}
                            </h3>
                            <span className={`px-2 py-0.5 rounded-full text-[10px] border ${getTypeColor(notification.type)}`}>
                              {notification.type}
                            </span>
                            {!notification.is_active && (
                              <span className="px-2 py-0.5 rounded-full bg-gray-500/10 text-[10px] text-gray-600 dark:text-gray-400 border border-gray-500/40 dark:border-gray-400/40">
                                Inactive
                              </span>
                            )}
                            {notification.expires_at && new Date(notification.expires_at) <= new Date() && (
                              <span className="px-2 py-0.5 rounded-full bg-rose-500/10 text-[10px] text-rose-600 dark:text-rose-400 border border-rose-500/40 dark:border-rose-400/40">
                                Expired
                              </span>
                            )}
                          </div>
                          <p className="text-xs text-gray-600 dark:text-gray-400 mb-2">
                            {notification.message}
                          </p>
                          <div className="flex items-center gap-4 text-[10px] text-gray-500 dark:text-gray-400">
                            <div className="flex items-center gap-1">
                              <Calendar className="w-3 h-3" />
                              {formatDate(notification.created_at)}
                            </div>
                            <div className="flex items-center gap-1">
                              <User className="w-3 h-3" />
                              {notification.target_type === 'all' ? 'All Users' :
                               notification.target_type === 'user' ? 'Specific Users' :
                               notification.target_type === 'role' ? 'Role-based' : 'Unknown'}
                            </div>
                            {notification.delivered_at && (
                              <div className="flex items-center gap-1">
                                <CheckCircle className="w-3 h-3" />
                                Delivered {formatDate(notification.delivered_at)}
                              </div>
                            )}
                            {notification.expires_at && (
                              <div className="flex items-center gap-1">
                                <Clock className="w-3 h-3" />
                                Expires {formatDate(notification.expires_at)}
                              </div>
                            )}
                          </div>
                          {notification.metadata?.action_url && (
                            <div className="mt-2">
                              <a
                                href={notification.metadata.action_url}
                                className="inline-flex items-center gap-1 text-xs text-orange-600 dark:text-orange-400 hover:text-orange-700 dark:hover:text-orange-300"
                              >
                                {notification.metadata.action_text || 'View Details'}
                              </a>
                            </div>
                          )}
                        </div>

                        {/* Actions */}
                        <div className="flex items-center gap-1 flex-shrink-0">
                          <button
                            onClick={() => handleDelete(notification.id)}
                            disabled={deleteLoading === notification.id}
                            className="p-1.5 rounded-lg bg-red-100 dark:bg-red-500/20 border border-red-300/50 dark:border-red-500/40 text-[10px] hover:bg-red-200/90 dark:hover:bg-red-500/30 text-red-600 dark:text-red-400 disabled:opacity-50"
                            title="Delete notification"
                          >
                            {deleteLoading === notification.id ? (
                              <div className="w-3.5 h-3.5 border border-current border-t-transparent rounded-full animate-spin"></div>
                            ) : (
                              <Trash2 className="w-3.5 h-3.5" />
                            )}
                          </button>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </main>
    </DashboardLayout>
  )
}

export default function NotificationsPage() {
  return <NotificationsContent />
}
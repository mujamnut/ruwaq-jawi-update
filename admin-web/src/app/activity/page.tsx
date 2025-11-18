'use client'

import { useState, useEffect } from 'react'
import DashboardLayout from "@/components/dashboard-layout"
import {
  Activity,
  Search,
  Filter,
  Download,
  Trash2,
  Eye,
  Calendar,
  User,
  FileText,
  Video,
  Tag,
  Settings,
  Shield,
  Mail,
  Plus,
  Edit,
  Upload,
  XCircle,
  CheckCircle,
  AlertTriangle,
  Info,
  Clock
} from 'lucide-react'
import { supabase } from '@/lib/supabase'
import { formatDistanceToNow } from 'date-fns'

interface ActivityLog {
  id: string
  admin_id: string | null
  admin_name: string | null
  admin_email: string | null
  action: string
  table_name: string | null
  record_id: string | null
  old_values: Record<string, any> | null
  new_values: Record<string, any> | null
  ip_address: string | null
  user_agent: string | null
  created_at: string
}

type ActivityType = 'create' | 'update' | 'delete' | 'login' | 'logout' | 'export' | 'import' | 'backup' | 'settings' | 'error'

const actionIcons: Record<string, React.ComponentType<{ className?: string }>> = {
  create: Plus,
  update: Edit,
  delete: Trash2,
  login: Shield,
  logout: XCircle,
  export: Download,
  import: Upload,
  backup: Settings,
  settings: Settings,
  error: AlertTriangle
}

const actionColors: Record<string, string> = {
  create: 'text-emerald-400 bg-emerald-400/10 border-emerald-400/40',
  update: 'text-blue-400 bg-blue-400/10 border-blue-400/40',
  delete: 'text-rose-400 bg-rose-400/10 border-rose-400/40',
  login: 'text-green-400 bg-green-400/10 border-green-400/40',
  logout: 'text-gray-600 bg-slate-400/10 border-slate-400/40',
  export: 'text-purple-400 bg-purple-400/10 border-purple-400/40',
  import: 'text-amber-400 bg-amber-400/10 border-amber-400/40',
  backup: 'text-indigo-400 bg-indigo-400/10 border-indigo-400/40',
  settings: 'text-cyan-400 bg-cyan-400/10 border-cyan-400/40',
  error: 'text-rose-400 bg-rose-400/10 border-rose-400/40'
}

const entityIcons: Record<string, React.ComponentType<{ className?: string }>> = {
  ebooks: FileText,
  video_kitab: Video,
  video_episodes: Video,
  categories: Tag,
  profiles: User,
  users: User,
  system: Settings,
  settings: Settings,
  admin_logs: Activity,
  payments: Settings,
  notifications: Mail
}

function ActivityLogsContent() {
  const [logs, setLogs] = useState<ActivityLog[]>([])
  const [filteredLogs, setFilteredLogs] = useState<ActivityLog[]>([])
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState('')
  const [actionFilter, setActionFilter] = useState<string>('all')
  const [entityFilter, setEntityFilter] = useState<string>('all')
  const [dateFilter, setDateFilter] = useState<string>('all')
  const [selectedLog, setSelectedLog] = useState<ActivityLog | null>(null)
  const [showDetailModal, setShowDetailModal] = useState(false)

  useEffect(() => {
    fetchActivityLogs()
  }, [])

  useEffect(() => {
    filterLogs()
  }, [logs, searchTerm, actionFilter, entityFilter, dateFilter])

  const fetchActivityLogs = async () => {
    try {
      // Optimized query without expensive JOIN for faster loading
      const { data: logsData, error } = await Promise.race([
        supabase
          .from('admin_logs')
          .select('id, admin_id, action, table_name, record_id, ip_address, created_at')
          .order('created_at', { ascending: false })
          .limit(100), // Limit for faster loading
        new Promise((_, reject) => setTimeout(() => reject(new Error('Query timeout')), 3000))
      ]) as any

      if (error) {
        setLogs([])
        return
      }

      // Simplified log data without JOIN processing
      const formattedLogs: ActivityLog[] = (logsData || []).map((log: any) => ({
        id: log.id,
        admin_id: log.admin_id,
        admin_name: 'System', // Simplified - can fetch later if needed
        admin_email: null,
        action: log.action,
        table_name: log.table_name,
        record_id: log.record_id,
        old_values: null,
        new_values: null,
        ip_address: log.ip_address,
        user_agent: null,
        created_at: log.created_at
      }))

      setLogs(formattedLogs)
    } catch (error) {
      setLogs([])
    } finally {
      setLoading(false)
    }
  }

  const filterLogs = () => {
    let filtered = logs

    if (searchTerm) {
      filtered = filtered.filter(log =>
        log.action.toLowerCase().includes(searchTerm.toLowerCase()) ||
        log.admin_name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        log.table_name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        (log.new_values && JSON.stringify(log.new_values).toLowerCase().includes(searchTerm.toLowerCase())) ||
        (log.old_values && JSON.stringify(log.old_values).toLowerCase().includes(searchTerm.toLowerCase()))
      )
    }

    if (actionFilter !== 'all') {
      filtered = filtered.filter(log => log.action === actionFilter)
    }

    if (entityFilter !== 'all') {
      filtered = filtered.filter(log => log.table_name === entityFilter)
    }

    if (dateFilter !== 'all') {
      const now = new Date()
      const filterDate = new Date()

      switch (dateFilter) {
        case 'today':
          filterDate.setHours(0, 0, 0, 0)
          break
        case 'week':
          filterDate.setDate(now.getDate() - 7)
          break
        case 'month':
          filterDate.setMonth(now.getMonth() - 1)
          break
        case 'year':
          filterDate.setFullYear(now.getFullYear() - 1)
          break
      }

      filtered = filtered.filter(log => new Date(log.created_at) >= filterDate)
    }

    setFilteredLogs(filtered)
  }

  const exportLogs = () => {
    const csvContent = [
      'Timestamp,Admin,Action,Table,Record ID,IP Address,User Agent',
      ...filteredLogs.map(log =>
        `"${log.created_at}","${log.admin_name || 'N/A'}","${log.action}","${log.table_name || 'N/A'}","${log.record_id || 'N/A'}","${log.ip_address || 'N/A'}","${log.user_agent || 'N/A'}"`
      )
    ].join('\n')

    const blob = new Blob([csvContent], { type: 'text/csv' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `activity-logs-${new Date().toISOString().split('T')[0]}.csv`
    a.click()
    URL.revokeObjectURL(url)
  }

  const getActionBadge = (action: string) => {
    const Icon = actionIcons[action] || Info
    const colorClass = actionColors[action] || actionColors.settings

    return (
      <span className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium border ${colorClass}`}>
        <Icon className="w-3 h-3" />
        {action.charAt(0).toUpperCase() + action.slice(1)}
      </span>
    )
  }

  const getEntityBadge = (tableName: string | null) => {
    if (!tableName) {
      return (
        <span className="inline-flex items-center gap-1 px-2 py-1 rounded-lg text-xs font-medium bg-gray-100 dark:bg-slate-700 border border-gray-400 dark:border-slate-600 text-gray-700 dark:text-gray-300">
          <Settings className="w-3 h-3" />
          System
        </span>
      )
    }

    const Icon = entityIcons[tableName] || Settings

    return (
      <span className="inline-flex items-center gap-1 px-2 py-1 rounded-lg text-xs font-medium bg-gray-100 dark:bg-slate-700 border border-gray-400 dark:border-slate-600 text-gray-700 dark:text-gray-300">
        <Icon className="w-3 h-3" />
        {tableName.charAt(0).toUpperCase() + tableName.slice(1).replace('_', ' ')}
      </span>
    )
  }

  if (loading) {
    return (
      <div className="space-y-6">
        {/* Header skeleton */}
        <div className="flex items-center justify-between">
          <div>
            <div className="h-8 w-32 bg-gray-100 dark:bg-slate-700 rounded-lg mb-2 animate-pulse"></div>
            <div className="h-4 w-48 bg-gray-100 dark:bg-slate-700 rounded animate-pulse"></div>
          </div>
          <div className="h-10 w-32 bg-gray-100 dark:bg-slate-700 rounded-lg animate-pulse"></div>
        </div>

        {/* Filters skeleton */}
        <div className="flex flex-col sm:flex-row gap-4">
          <div className="flex-1 h-10 bg-gray-100 dark:bg-slate-700 rounded-lg animate-pulse"></div>
          <div className="h-10 w-32 bg-gray-100 dark:bg-slate-700 rounded-lg animate-pulse"></div>
          <div className="h-10 w-32 bg-gray-100 dark:bg-slate-700 rounded-lg animate-pulse"></div>
          <div className="h-10 w-32 bg-gray-100 dark:bg-slate-700 rounded-lg animate-pulse"></div>
        </div>

        {/* Table skeleton */}
        <div className="bg-white/80 dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80 rounded-xl overflow-hidden">
          <div className="space-y-3 p-4">
            {Array.from({ length: 5 }).map((_, i) => (
              <div key={i} className="flex items-center space-x-4 p-3 border border-gray-200 dark:border-slate-600 rounded-lg">
                <div className="w-8 h-8 bg-gray-100 dark:bg-slate-700 rounded-full animate-pulse"></div>
                <div className="flex-1 space-y-2">
                  <div className="h-4 bg-gray-100 dark:bg-slate-700 rounded animate-pulse"></div>
                  <div className="h-3 w-3/4 bg-gray-100 dark:bg-slate-700 rounded animate-pulse"></div>
                </div>
                <div className="w-16 h-6 bg-gray-100 dark:bg-slate-700 rounded animate-pulse"></div>
              </div>
            ))}
          </div>
        </div>
      </div>
    )
  }

  return (
    <DashboardLayout title="Activity Logs" subtitle="System activity logs">
          <div className="space-y-6 px-4 sm:px-6 pb-8 pt-4">
            {/* Header Actions */}
            <div className="flex items-center justify-between">
              <div>
                <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Activity Logs</h1>
                <p className="text-gray-600 dark:text-gray-400 mt-1">Track all admin actions and system events</p>
              </div>
              <button
                onClick={exportLogs}
                className="inline-flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
              >
                <Download className="w-4 h-4" />
                Export Logs
              </button>
            </div>

            {/* Filters */}
            <div className="flex flex-col sm:flex-row gap-4">
              <div className="flex-1 relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-600 dark:text-gray-400 w-4 h-4" />
                <input
                  type="text"
                  placeholder="Search activity logs..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="w-full pl-10 pr-4 py-2 bg-white/80 dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80 rounded-lg text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
                />
              </div>
              <select
                value={actionFilter}
                onChange={(e) => setActionFilter(e.target.value)}
                className="px-4 py-2 bg-white/80 dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80 rounded-lg text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
              >
                <option value="all">All Actions</option>
                <option value="create">Create</option>
                <option value="update">Update</option>
                <option value="delete">Delete</option>
                <option value="login">Login</option>
                <option value="logout">Logout</option>
                <option value="export">Export</option>
                <option value="backup">Backup</option>
                <option value="settings">Settings</option>
              </select>
              <select
                value={entityFilter}
                onChange={(e) => setEntityFilter(e.target.value)}
                className="px-4 py-2 bg-white/80 dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80 rounded-lg text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
              >
                <option value="all">All Tables</option>
                <option value="ebooks">Ebooks</option>
                <option value="video_kitab">Video Kitab</option>
                <option value="video_episodes">Video Episodes</option>
                <option value="categories">Categories</option>
                <option value="profiles">User Profiles</option>
                <option value="payments">Payments</option>
                <option value="notifications">Notifications</option>
                <option value="admin_logs">System Logs</option>
              </select>
              <select
                value={dateFilter}
                onChange={(e) => setDateFilter(e.target.value)}
                className="px-4 py-2 bg-white/80 dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80 rounded-lg text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
              >
                <option value="all">All Time</option>
                <option value="today">Today</option>
                <option value="week">This Week</option>
                <option value="month">This Month</option>
                <option value="year">This Year</option>
              </select>
            </div>

            {/* Logs Table */}
            <div className="bg-white/80 dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80 rounded-xl overflow-hidden">
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="border-b border-gray-300/80 dark:border-slate-600/80">
                      <th className="text-left p-4 text-sm font-medium text-gray-700 dark:text-gray-300">Time</th>
                      <th className="text-left p-4 text-sm font-medium text-gray-700 dark:text-gray-300">Admin</th>
                      <th className="text-left p-4 text-sm font-medium text-gray-700 dark:text-gray-300">Action</th>
                      <th className="text-left p-4 text-sm font-medium text-gray-700 dark:text-gray-300">Table</th>
                      <th className="text-left p-4 text-sm font-medium text-gray-700 dark:text-gray-300">Details</th>
                      <th className="text-left p-4 text-sm font-medium text-gray-700 dark:text-gray-300">IP Address</th>
                      <th className="text-left p-4 text-sm font-medium text-gray-700 dark:text-gray-300">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredLogs.map((log) => (
                      <tr key={log.id} className="border-b border-gray-200/50 dark:border-slate-700/50 hover:bg-gray-100/30 dark:hover:bg-slate-700/30 transition-colors">
                        <td className="p-4">
                          <div className="flex items-center gap-2 text-sm text-gray-700 dark:text-gray-300">
                            <Clock className="w-4 h-4 text-gray-500 dark:text-gray-400" />
                            <div>
                              <div>{formatDistanceToNow(new Date(log.created_at), { addSuffix: true })}</div>
                              <div className="text-xs text-gray-500 dark:text-gray-400">
                                {new Date(log.created_at).toLocaleDateString()}
                              </div>
                            </div>
                          </div>
                        </td>
                        <td className="p-4">
                          <div className="flex items-center gap-3">
                            <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-blue-500 to-indigo-500 flex items-center justify-center text-xs font-semibold">
                              {log.admin_name?.charAt(0) || 'S'}
                            </div>
                            <div>
                              <div className="text-sm font-medium text-gray-900 dark:text-white">{log.admin_name || 'System'}</div>
                              <div className="text-xs text-gray-600 dark:text-gray-400">{log.admin_email || 'N/A'}</div>
                            </div>
                          </div>
                        </td>
                        <td className="p-4">
                          {getActionBadge(log.action)}
                        </td>
                        <td className="p-4">
                          {getEntityBadge(log.table_name)}
                        </td>
                        <td className="p-4">
                          <div className="max-w-xs">
                            <p className="text-sm text-gray-700 truncate">
                              {log.new_values ? JSON.stringify(log.new_values).substring(0, 50) + '...' : 'No details'}
                            </p>
                            {log.record_id && (
                              <p className="text-xs text-gray-500 mt-1">ID: {log.record_id.substring(0, 8)}...</p>
                            )}
                          </div>
                        </td>
                        <td className="p-4">
                          <div className="text-sm text-gray-700 font-mono">{log.ip_address || 'N/A'}</div>
                        </td>
                        <td className="p-4">
                          <button
                            onClick={() => {
                              setSelectedLog(log)
                              setShowDetailModal(true)
                            }}
                            className="p-1 text-gray-600 hover:text-blue-400 transition-colors"
                            title="Eye Details"
                          >
                            <Eye className="w-4 h-4" />
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {filteredLogs.length === 0 && (
                <div className="text-center py-12">
                  <div className="w-12 h-12 rounded-full bg-gray-100 flex items-center justify-center mx-auto mb-4">
                    <Activity className="w-6 h-6 text-gray-600" />
                  </div>
                  <h3 className="text-sm font-medium text-gray-700 mb-1">No activity logs found</h3>
                  <p className="text-xs text-gray-500">
                    {searchTerm || actionFilter !== 'all' || entityFilter !== 'all' || dateFilter !== 'all'
                      ? 'Try adjusting your search or filters'
                      : 'Activity logs will appear here when admins perform actions'
                    }
                  </p>
                </div>
              )}
            </div>

            {/* Detail Modal */}
            {showDetailModal && selectedLog && (
              <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
                <div className="w-full max-w-2xl bg-white rounded-xl border border-gray-300/80 p-6">
                  <div className="flex items-center justify-between mb-6">
                    <h2 className="text-xl font-bold text-white">Activity Log Details</h2>
                    <button
                      onClick={() => setShowDetailModal(false)}
                      className="text-gray-600 hover:text-white transition-colors"
                    >
                      <XCircle className="w-5 h-5" />
                    </button>
                  </div>

                  <div className="space-y-4">
                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <label className="block text-xs font-medium text-gray-600 mb-1">Timestamp</label>
                        <p className="text-sm text-gray-700">
                          {new Date(selectedLog.created_at).toLocaleString()}
                        </p>
                      </div>
                      <div>
                        <label className="block text-xs font-medium text-gray-600 mb-1">Admin</label>
                        <p className="text-sm text-gray-700">
                          {selectedLog.admin_name || 'System'} ({selectedLog.admin_email || 'N/A'})
                        </p>
                      </div>
                      <div>
                        <label className="block text-xs font-medium text-gray-600 mb-1">Action</label>
                        <div>{getActionBadge(selectedLog.action)}</div>
                      </div>
                      <div>
                        <label className="block text-xs font-medium text-gray-600 mb-1">Table</label>
                        <div>{getEntityBadge(selectedLog.table_name)}</div>
                      </div>
                    </div>

                    {selectedLog.record_id && (
                      <div>
                        <label className="block text-xs font-medium text-gray-600 mb-1">Record ID</label>
                        <p className="text-sm text-gray-700 font-mono">{selectedLog.record_id}</p>
                      </div>
                    )}

                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <label className="block text-xs font-medium text-gray-600 mb-1">IP Address</label>
                        <p className="text-sm text-gray-700 font-mono">{selectedLog.ip_address || 'N/A'}</p>
                      </div>
                      <div>
                        <label className="block text-xs font-medium text-gray-600 mb-1">User Agent</label>
                        <p className="text-sm text-gray-700 truncate" title={selectedLog.user_agent || 'N/A'}>
                          {selectedLog.user_agent || 'N/A'}
                        </p>
                      </div>
                    </div>

                    {selectedLog.old_values && Object.keys(selectedLog.old_values).length > 0 && (
                      <div>
                        <label className="block text-xs font-medium text-gray-600 mb-1">Old Values</label>
                        <div className="bg-gray-100 rounded-lg p-3">
                          <pre className="text-xs text-gray-700">
                            {JSON.stringify(selectedLog.old_values, null, 2)}
                          </pre>
                        </div>
                      </div>
                    )}

                    {selectedLog.new_values && Object.keys(selectedLog.new_values).length > 0 && (
                      <div>
                        <label className="block text-xs font-medium text-gray-600 mb-1">New Values</label>
                        <div className="bg-gray-100 rounded-lg p-3">
                          <pre className="text-xs text-gray-700">
                            {JSON.stringify(selectedLog.new_values, null, 2)}
                          </pre>
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            )}
          </div>
    </DashboardLayout>
  )
}

export default function ActivityLogsPage() {
  return <ActivityLogsContent />
}
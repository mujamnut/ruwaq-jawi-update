'use client'

import { useState, useEffect } from 'react'
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
  admin_id: string
  admin_name: string
  admin_email: string
  action: string
  entity_type: 'book' | 'video' | 'category' | 'user' | 'system' | 'settings'
  entity_id?: string
  entity_name?: string
  description: string
  ip_address: string
  user_agent: string
  created_at: string
  metadata?: Record<string, any>
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
  logout: 'text-slate-400 bg-slate-400/10 border-slate-400/40',
  export: 'text-purple-400 bg-purple-400/10 border-purple-400/40',
  import: 'text-amber-400 bg-amber-400/10 border-amber-400/40',
  backup: 'text-indigo-400 bg-indigo-400/10 border-indigo-400/40',
  settings: 'text-cyan-400 bg-cyan-400/10 border-cyan-400/40',
  error: 'text-rose-400 bg-rose-400/10 border-rose-400/40'
}

const entityIcons: Record<string, React.ComponentType<{ className?: string }>> = {
  book: FileText,
  video: Video,
  category: Tag,
  user: User,
  system: Settings,
  settings: Settings
}

export default function ActivityLogsPage() {
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
      // Since we don't have an activity_logs table yet, we'll simulate some data
      // In a real implementation, you would fetch from the database
      const mockLogs: ActivityLog[] = [
        {
          id: '1',
          admin_id: 'admin-1',
          admin_name: 'Admin User',
          admin_email: 'admin@ruwaq.app',
          action: 'create',
          entity_type: 'book',
          entity_id: 'book-1',
          entity_name: 'Islamic Studies Guide',
          description: 'Created new ebook "Islamic Studies Guide"',
          ip_address: '192.168.1.100',
          user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          created_at: new Date(Date.now() - 1000 * 60 * 15).toISOString(),
          metadata: { file_size: '2.5MB', category: 'Education' }
        },
        {
          id: '2',
          admin_id: 'admin-1',
          admin_name: 'Admin User',
          admin_email: 'admin@ruwaq.app',
          action: 'update',
          entity_type: 'category',
          entity_id: 'cat-1',
          entity_name: 'Quran Studies',
          description: 'Updated category "Quran Studies" sort order',
          ip_address: '192.168.1.100',
          user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          created_at: new Date(Date.now() - 1000 * 60 * 60 * 2).toISOString(),
          metadata: { old_order: 3, new_order: 1 }
        },
        {
          id: '3',
          admin_id: 'admin-1',
          admin_name: 'Admin User',
          admin_email: 'admin@ruwaq.app',
          action: 'delete',
          entity_type: 'video',
          entity_id: 'video-1',
          entity_name: 'Introduction to Tajweed',
          description: 'Deleted video "Introduction to Tajweed"',
          ip_address: '192.168.1.100',
          user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          created_at: new Date(Date.now() - 1000 * 60 * 60 * 4).toISOString()
        },
        {
          id: '4',
          admin_id: 'admin-1',
          admin_name: 'Admin User',
          admin_email: 'admin@ruwaq.app',
          action: 'login',
          entity_type: 'system',
          description: 'Admin logged in successfully',
          ip_address: '192.168.1.100',
          user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          created_at: new Date(Date.now() - 1000 * 60 * 60 * 8).toISOString()
        },
        {
          id: '5',
          admin_id: 'admin-1',
          admin_name: 'Admin User',
          admin_email: 'admin@ruwaq.app',
          action: 'create',
          entity_type: 'user',
          entity_id: 'user-1',
          entity_name: 'John Student',
          description: 'Created new admin user "John Student"',
          ip_address: '192.168.1.100',
          user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          created_at: new Date(Date.now() - 1000 * 60 * 60 * 24).toISOString(),
          metadata: { role: 'admin', email: 'john@example.com' }
        }
      ]

      setLogs(mockLogs)
    } catch (error) {
      console.error('Error fetching activity logs:', error)
    } finally {
      setLoading(false)
    }
  }

  const filterLogs = () => {
    let filtered = logs

    if (searchTerm) {
      filtered = filtered.filter(log =>
        log.description.toLowerCase().includes(searchTerm.toLowerCase()) ||
        log.admin_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
        log.entity_name?.toLowerCase().includes(searchTerm.toLowerCase())
      )
    }

    if (actionFilter !== 'all') {
      filtered = filtered.filter(log => log.action === actionFilter)
    }

    if (entityFilter !== 'all') {
      filtered = filtered.filter(log => log.entity_type === entityFilter)
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
      'Timestamp,Admin,Action,Entity,Description,IP Address',
      ...filteredLogs.map(log =>
        `"${log.created_at}","${log.admin_name}","${log.action}","${log.entity_type}","${log.description}","${log.ip_address}"`
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

  const getEntityBadge = (entityType: string) => {
    const Icon = entityIcons[entityType] || Settings

    return (
      <span className="inline-flex items-center gap-1 px-2 py-1 rounded-lg text-xs font-medium bg-slate-800 border border-slate-600 text-slate-300">
        <Icon className="w-3 h-3" />
        {entityType.charAt(0).toUpperCase() + entityType.slice(1)}
      </span>
    )
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Activity Logs</h1>
          <p className="text-slate-400 mt-1">Track all admin actions and system events</p>
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
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-slate-400 w-4 h-4" />
          <input
            type="text"
            placeholder="Search activity logs..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-10 pr-4 py-2 bg-slate-900/80 border border-slate-700/80 rounded-lg text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
          />
        </div>
        <select
          value={actionFilter}
          onChange={(e) => setActionFilter(e.target.value)}
          className="px-4 py-2 bg-slate-900/80 border border-slate-700/80 rounded-lg text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
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
          className="px-4 py-2 bg-slate-900/80 border border-slate-700/80 rounded-lg text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
        >
          <option value="all">All Entities</option>
          <option value="book">Books</option>
          <option value="video">Videos</option>
          <option value="category">Categories</option>
          <option value="user">Users</option>
          <option value="system">System</option>
          <option value="settings">Settings</option>
        </select>
        <select
          value={dateFilter}
          onChange={(e) => setDateFilter(e.target.value)}
          className="px-4 py-2 bg-slate-900/80 border border-slate-700/80 rounded-lg text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
        >
          <option value="all">All Time</option>
          <option value="today">Today</option>
          <option value="week">This Week</option>
          <option value="month">This Month</option>
          <option value="year">This Year</option>
        </select>
      </div>

      {/* Logs Table */}
      <div className="bg-slate-900/80 border border-slate-700/80 rounded-xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-slate-700/80">
                <th className="text-left p-4 text-sm font-medium text-slate-300">Time</th>
                <th className="text-left p-4 text-sm font-medium text-slate-300">Admin</th>
                <th className="text-left p-4 text-sm font-medium text-slate-300">Action</th>
                <th className="text-left p-4 text-sm font-medium text-slate-300">Entity</th>
                <th className="text-left p-4 text-sm font-medium text-slate-300">Description</th>
                <th className="text-left p-4 text-sm font-medium text-slate-300">IP Address</th>
                <th className="text-left p-4 text-sm font-medium text-slate-300">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredLogs.map((log) => (
                <tr key={log.id} className="border-b border-slate-800/50 hover:bg-slate-800/30 transition-colors">
                  <td className="p-4">
                    <div className="flex items-center gap-2 text-sm text-slate-300">
                      <Clock className="w-4 h-4 text-slate-500" />
                      <div>
                        <div>{formatDistanceToNow(new Date(log.created_at), { addSuffix: true })}</div>
                        <div className="text-xs text-slate-500">
                          {new Date(log.created_at).toLocaleDateString()}
                        </div>
                      </div>
                    </div>
                  </td>
                  <td className="p-4">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-blue-500 to-indigo-500 flex items-center justify-center text-xs font-semibold">
                        {log.admin_name.charAt(0)}
                      </div>
                      <div>
                        <div className="text-sm font-medium text-white">{log.admin_name}</div>
                        <div className="text-xs text-slate-400">{log.admin_email}</div>
                      </div>
                    </div>
                  </td>
                  <td className="p-4">
                    {getActionBadge(log.action)}
                  </td>
                  <td className="p-4">
                    {getEntityBadge(log.entity_type)}
                  </td>
                  <td className="p-4">
                    <div className="max-w-xs">
                      <p className="text-sm text-slate-300 truncate">{log.description}</p>
                      {log.entity_name && (
                        <p className="text-xs text-slate-500 mt-1">{log.entity_name}</p>
                      )}
                    </div>
                  </td>
                  <td className="p-4">
                    <div className="text-sm text-slate-300 font-mono">{log.ip_address}</div>
                  </td>
                  <td className="p-4">
                    <button
                      onClick={() => {
                        setSelectedLog(log)
                        setShowDetailModal(true)
                      }}
                      className="p-1 text-slate-400 hover:text-blue-400 transition-colors"
                      title="View Details"
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
            <div className="w-12 h-12 rounded-full bg-slate-800 flex items-center justify-center mx-auto mb-4">
              <Activity className="w-6 h-6 text-slate-400" />
            </div>
            <h3 className="text-sm font-medium text-slate-300 mb-1">No activity logs found</h3>
            <p className="text-xs text-slate-500">
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
          <div className="w-full max-w-2xl bg-slate-900 rounded-xl border border-slate-700/80 p-6">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-xl font-bold text-white">Activity Log Details</h2>
              <button
                onClick={() => setShowDetailModal(false)}
                className="text-slate-400 hover:text-white transition-colors"
              >
                <XCircle className="w-5 h-5" />
              </button>
            </div>

            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-medium text-slate-400 mb-1">Timestamp</label>
                  <p className="text-sm text-slate-300">
                    {new Date(selectedLog.created_at).toLocaleString()}
                  </p>
                </div>
                <div>
                  <label className="block text-xs font-medium text-slate-400 mb-1">Admin</label>
                  <p className="text-sm text-slate-300">
                    {selectedLog.admin_name} ({selectedLog.admin_email})
                  </p>
                </div>
                <div>
                  <label className="block text-xs font-medium text-slate-400 mb-1">Action</label>
                  <div>{getActionBadge(selectedLog.action)}</div>
                </div>
                <div>
                  <label className="block text-xs font-medium text-slate-400 mb-1">Entity Type</label>
                  <div>{getEntityBadge(selectedLog.entity_type)}</div>
                </div>
              </div>

              <div>
                <label className="block text-xs font-medium text-slate-400 mb-1">Description</label>
                <p className="text-sm text-slate-300">{selectedLog.description}</p>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-medium text-slate-400 mb-1">IP Address</label>
                  <p className="text-sm text-slate-300 font-mono">{selectedLog.ip_address}</p>
                </div>
                <div>
                  <label className="block text-xs font-medium text-slate-400 mb-1">User Agent</label>
                  <p className="text-sm text-slate-300 truncate" title={selectedLog.user_agent}>
                    {selectedLog.user_agent}
                  </p>
                </div>
              </div>

              {selectedLog.metadata && Object.keys(selectedLog.metadata).length > 0 && (
                <div>
                  <label className="block text-xs font-medium text-slate-400 mb-1">Additional Metadata</label>
                  <div className="bg-slate-800 rounded-lg p-3">
                    <pre className="text-xs text-slate-300">
                      {JSON.stringify(selectedLog.metadata, null, 2)}
                    </pre>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
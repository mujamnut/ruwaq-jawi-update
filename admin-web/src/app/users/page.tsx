'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import DashboardLayout from "@/components/dashboard-layout"
import {
  Plus,
  Edit,
  Trash2,
  Search,
  Filter,
  Users,
  UserCheck,
  Mail,
  Calendar,
  Activity,
  Shield,
  Ban,
  Eye,
  Download,
  RefreshCw
} from 'lucide-react'
import { supabase } from "@/lib/supabase"

interface User {
  id: string
  email: string | null
  full_name: string | null
  role: 'student' | 'admin'
  subscription_status: string
  phone_number: string | null
  avatar_url: string | null
  created_at: string
  updated_at: string
  last_seen_at: string | null
}

function UsersContent() {
  const [users, setUsers] = useState<User[]>([])
  const [searchTerm, setSearchTerm] = useState('')
  const [loading, setLoading] = useState(true)
  const [deleteLoading, setDeleteLoading] = useState<string | null>(null)
  const [roleFilter, setRoleFilter] = useState<'all' | 'student' | 'admin'>('all')
  const [refreshKey, setRefreshKey] = useState(0)

  useEffect(() => {
    fetchUsers()
  }, [roleFilter, refreshKey])

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

  const fetchUsers = async () => {
    try {
      setLoading(true)
      let query = supabase
        .from('profiles')
        .select('*')
        .order('created_at', { ascending: false })

      // Apply role filter
      if (roleFilter !== 'all') {
        query = query.eq('role', roleFilter)
      }

      const { data, error } = await query

      // Handle empty error objects and RLS issues
      if (error) {
        const errorMsg = error?.message || JSON.stringify(error) || 'Unknown error'
        console.error('Error fetching users:', errorMsg)
        return
      }

      setUsers(data || [])
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : JSON.stringify(error) || 'Unknown error'
      console.error('Error fetching users:', errorMsg)
    } finally {
      setLoading(false)
    }
  }

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this user? This action cannot be undone.')) return

    try {
      setDeleteLoading(id)
      const { error } = await supabase
        .from('profiles')
        .delete()
        .eq('id', id)

      // Handle empty error objects and RLS issues
      if (error) {
        const errorMsg = error?.message || JSON.stringify(error) || 'Unknown error'
        console.error('Error deleting user:', errorMsg)
        return
      }

      await fetchUsers()
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : JSON.stringify(error) || 'Unknown error'
      console.error('Error deleting user:', errorMsg)
    } finally {
      setDeleteLoading(null)
    }
  }

  const changeUserRole = async (id: string, newRole: 'student' | 'admin') => {
    try {
      const { error } = await supabase
        .from('profiles')
        .update({ role: newRole })
        .eq('id', id)

      // Handle empty error objects and RLS issues
      if (error) {
        const errorMsg = error?.message || JSON.stringify(error) || 'Unknown error'
        console.error('Error changing user role:', errorMsg)
        return
      }

      await fetchUsers()
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : JSON.stringify(error) || 'Unknown error'
      console.error('Error changing user role:', errorMsg)
    }
  }

  const exportUsers = async () => {
    try {
      const { data } = await supabase
        .from('profiles')
        .select('*')
        .order('created_at', { ascending: true })

      if (data) {
        const csv = [
          ['Email', 'Full Name', 'Role', 'Subscription Status', 'Phone Number', 'Created At', 'Last Seen'].join(','),
          ...data.map(user => [
            user.email || 'N/A',
            user.full_name || 'N/A',
            user.role || 'student',
            user.subscription_status || 'inactive',
            user.phone_number || 'N/A',
            new Date(user.created_at).toLocaleDateString(),
            user.last_seen_at ? new Date(user.last_seen_at).toLocaleDateString() : 'Never'
          ])
        ].join('\n')

        const blob = new Blob([csv], { type: 'text/csv' })
        const url = window.URL.createObjectURL(blob)
        const a = document.createElement('a')
        a.href = url
        a.download = `users_${new Date().toISOString().split('T')[0]}.csv`
        a.click()
        window.URL.revokeObjectURL(url)
      }
    } catch (error) {
      console.error('Error exporting users:', error)
    }
  }

  const filteredUsers = users.filter(user =>
    user.email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    user.full_name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    user.phone_number?.toLowerCase().includes(searchTerm.toLowerCase())
  )

  const formatRole = (role: string) => {
    if (!role) return 'User'
    return role.charAt(0).toUpperCase() + role.slice(1)
  }

  const formatDate = (dateString: string) => {
    if (!dateString) return 'Never'
    return new Date(dateString).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric'
    })
  }

  const getStats = () => {
    const total = users.length
    const admins = users.filter(u => u.role === 'admin').length
    const students = users.filter(u => u.role === 'student').length
    const withSubscription = users.filter(u => u.subscription_status === 'active').length
    return { total, admins, students, withSubscription }
  }

  const stats = getStats()

  return (
    <DashboardLayout title="Students" subtitle="Student account management">
          {/* Main Content */}
          <main className="flex-1 px-4 sm:px-6 pb-8 pt-4 mx-auto max-w-full bg-gray-50 dark:bg-gradient-to-br dark:from-slate-950 dark:via-slate-950 dark:to-slate-900 transition-colors duration-300">
          {/* Page Header */}
          <div className="card rounded-2xl p-4 sm:p-5 mb-4 bg-white dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <h2 className="text-base sm:text-lg font-semibold mb-1 text-gray-900 dark:text-white">User Management</h2>
                <p className="text-xs text-gray-600 dark:text-gray-400">Manage app users and permissions</p>
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
                  onClick={exportUsers}
                  className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-white/90 dark:bg-slate-700/90 border border-gray-300/80 dark:border-slate-600/80 text-[11px] font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-100/90 dark:hover:bg-slate-600/90"
                >
                  <Download className="w-4 h-4" />
                  Export
                </button>
                <Link href="/users/new" className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-gradient-to-r from-orange-600 to-red-600 text-white text-xs font-medium hover:from-orange-700 hover:to-red-700 transition-all shadow-lg">
                  <Plus className="w-4 h-4" />
                  Add User
                </Link>
              </div>
            </div>

            {/* Stats Cards */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mt-4">
              <div className="rounded-xl border border-gray-300/80 dark:border-slate-600/80 bg-white/80 dark:bg-slate-800/90 p-3">
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-[11px] text-gray-600 dark:text-gray-400">Total Users</span>
                  <span className="px-1.5 py-0.5 rounded-full bg-blue-500/10 text-[10px] text-blue-300 dark:text-blue-400 border border-blue-500/40 dark:border-blue-400/40">
                    {stats.total}
                  </span>
                </div>
                <p className="text-lg font-semibold text-gray-900 dark:text-white">{stats.total}</p>
                <p className="mt-0.5 text-[11px] text-gray-500 dark:text-gray-400">Registered users</p>
              </div>
              <div className="rounded-xl border border-gray-300/80 dark:border-slate-600/80 bg-white/80 dark:bg-slate-800/90 p-3">
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-[11px] text-gray-600 dark:text-gray-400">Admins</span>
                  <span className="px-1.5 py-0.5 rounded-full bg-rose-500/10 text-[10px] text-rose-300 dark:text-rose-400 border border-rose-500/40 dark:border-rose-400/40">
                    {stats.admins}
                  </span>
                </div>
                <p className="text-lg font-semibold text-gray-900 dark:text-white">{stats.admins}</p>
                <p className="mt-0.5 text-[11px] text-gray-500 dark:text-gray-400">System admins</p>
              </div>
              <div className="rounded-xl border border-gray-300/80 dark:border-slate-600/80 bg-white/80 dark:bg-slate-800/90 p-3">
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-[11px] text-gray-600 dark:text-gray-400">Students</span>
                  <span className="px-1.5 py-0.5 rounded-full bg-emerald-500/10 text-[10px] text-emerald-300 dark:text-emerald-400 border border-emerald-500/40 dark:border-emerald-400/40">
                    {stats.students}
                  </span>
                </div>
                <p className="text-lg font-semibold text-gray-900 dark:text-white">{stats.students}</p>
                <p className="mt-0.5 text-[11px] text-gray-500 dark:text-gray-400">Regular users</p>
              </div>
              <div className="rounded-xl border border-gray-300/80 dark:border-slate-600/80 bg-white/80 dark:bg-slate-800/90 p-3">
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-[11px] text-gray-600 dark:text-gray-400">Subscribed</span>
                  <span className="px-1.5 py-0.5 rounded-full bg-amber-500/10 text-[10px] text-amber-300 dark:text-amber-400 border border-amber-500/40 dark:border-amber-400/40">
                    {stats.withSubscription}
                  </span>
                </div>
                <p className="text-lg font-semibold text-gray-900 dark:text-white">{stats.withSubscription}</p>
                <p className="mt-0.5 text-[11px] text-gray-500 dark:text-gray-400">Active subscriptions</p>
              </div>
            </div>
          </div>

          {/* Filters and Search */}
          <div className="card rounded-2xl p-4 sm:p-5 mb-4 bg-white dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div className="flex items-center gap-2">
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-600 dark:text-gray-400 w-4 h-4" />
                  <input
                    type="text"
                    placeholder="Search users by name, email, or phone..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="pl-10 pr-4 py-2 w-full sm:w-80 rounded-xl bg-white/80 dark:bg-slate-700/90 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-orange-500/50 dark:focus:ring-orange-400/50 focus:border-orange-500/50 dark:focus:border-orange-400/50"
                  />
                </div>
                <select
                  value={roleFilter}
                  onChange={(e) => setRoleFilter(e.target.value as 'all' | 'student' | 'admin')}
                  className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-white/80 dark:bg-slate-700/90 border border-gray-300/80 dark:border-slate-600/80 text-[11px] font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-100/90 dark:hover:bg-slate-600/90"
                >
                  <option value="all">All Users</option>
                  <option value="admin">Admins Only</option>
                  <option value="student">Students Only</option>
                </select>
                <button className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-white/80 dark:bg-slate-700/90 border border-gray-300/80 dark:border-slate-600/80 text-[11px] font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-100/90 dark:hover:bg-slate-600/90">
                  <Filter className="w-3.5 h-3.5" />
                  More Filters
                </button>
              </div>
              <div className="text-[11px] text-gray-600 dark:text-gray-400">
                Showing {filteredUsers.length} of {users.length} users
              </div>
            </div>
          </div>

          {/* Users Table */}
          <div className="card rounded-2xl p-4 sm:p-5 bg-white dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80">
            <div className="overflow-x-auto no-scrollbar">
              <table className="w-full text-left border-separate border-spacing-y-1.5">
                <thead className="text-[10px] uppercase tracking-[.18em] text-gray-500 dark:text-gray-400">
                  <tr>
                    <th className="px-2 py-1.5">User</th>
                    <th className="px-2 py-1.5 whitespace-nowrap">Role</th>
                    <th className="px-2 py-1.5 whitespace-nowrap">Subscription</th>
                    <th className="px-2 py-1.5 whitespace-nowrap">Last Seen</th>
                    <th className="px-2 py-1.5 whitespace-nowrap">Joined</th>
                    <th className="px-2 py-1.5 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="text-xs">
                  {loading ? (
                    <tr>
                      <td colSpan={7} className="text-center py-8">
                        <div className="flex items-center justify-center">
                          <div className="w-6 h-6 border-2 border-orange-500 border-t-transparent rounded-full animate-spin"></div>
                          <span className="ml-2 text-gray-600 dark:text-gray-400">Loading users...</span>
                        </div>
                      </td>
                    </tr>
                  ) : filteredUsers.length === 0 ? (
                    <tr>
                      <td colSpan={7} className="text-center py-8">
                        <div className="flex flex-col items-center">
                          <Users className="w-12 h-12 text-gray-400 dark:text-gray-600 mb-3" />
                          <h3 className="text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">No users found</h3>
                          <p className="text-[11px] text-gray-500 dark:text-gray-400">
                            {searchTerm ? 'No users match your search criteria' : 'Start by adding your first user'}
                          </p>
                        </div>
                      </td>
                    </tr>
                  ) : (
                    filteredUsers.map((user) => (
                      <tr key={user.id} className="bg-white/90 dark:bg-slate-700/90 hover:bg-white dark:hover:bg-slate-700 transition border border-gray-200/80 dark:border-slate-600/80">
                        <td className="px-2 py-3">
                          <div className="flex items-center gap-3">
                            <div className="w-10 h-10 rounded-xl bg-white dark:bg-slate-600 flex items-center justify-center border border-gray-300/80 dark:border-slate-500/80">
                              {user.avatar_url ? (
                                <img
                                  src={user.avatar_url || ''}
                                  alt={user.full_name || user.email || ''}
                                  className="w-full h-full object-cover rounded-xl"
                                />
                              ) : (
                                <UserCheck className="w-4 h-4 text-orange-400 dark:text-orange-300" />
                              )}
                            </div>
                            <div className="flex-1 min-w-0">
                              <p className="text-xs font-medium text-gray-900 dark:text-white truncate">
                                {user.full_name || 'No name'}
                              </p>
                              <p className="text-[10px] text-gray-600 dark:text-gray-400 truncate">
                                {user.email}
                              </p>
                              {user.phone_number && (
                                <p className="text-[10px] text-gray-500 dark:text-gray-400">
                                  {user.phone_number}
                                </p>
                              )}
                            </div>
                          </div>
                        </td>
                        <td className="px-2 py-3">
                          <span className={`px-2 py-0.5 rounded-full text-[10px] border ${
                            user.role === 'admin'
                              ? 'bg-rose-500/10 text-rose-300 dark:text-rose-400 border-rose-500/40 dark:border-rose-400/40'
                              : 'bg-blue-500/10 text-blue-300 dark:text-blue-400 border-blue-500/40 dark:border-blue-400/40'
                          }`}>
                            {formatRole(user.role)}
                          </span>
                        </td>
                        <td className="px-2 py-3">
                          <span className={`px-2 py-0.5 rounded-full text-[10px] border ${
                            user.subscription_status === 'active'
                              ? 'bg-emerald-500/10 text-emerald-300 dark:text-emerald-400 border-emerald-500/40 dark:border-emerald-400/40'
                              : 'bg-slate-500/10 text-gray-700 dark:text-gray-300 border-gray-500/40 dark:border-gray-400/40'
                          }`}>
                            {user.subscription_status === 'active' ? 'Premium' : 'Free'}
                          </span>
                        </td>
                        <td className="px-2 py-3">
                          <div className="flex items-center gap-1 text-[11px] text-gray-600 dark:text-gray-400">
                            <Activity className="w-3.5 h-3.5" />
                            {formatDate(user.last_seen_at || '')}
                          </div>
                        </td>
                        <td className="px-2 py-3">
                          <div className="flex items-center gap-1 text-[11px] text-gray-600 dark:text-gray-400">
                            <Calendar className="w-3.5 h-3.5" />
                            {formatDate(user.created_at)}
                          </div>
                        </td>
                        <td className="px-2 py-3">
                          <div className="flex items-center justify-end gap-1">
                            <button className="p-1.5 rounded-lg bg-white dark:bg-slate-600 border border-gray-300/80 dark:border-slate-500/80 text-[10px] hover:bg-gray-100/90 dark:hover:bg-slate-500/90 text-gray-700 dark:text-gray-300">
                              <Eye className="w-3.5 h-3.5" />
                            </button>
                            <button className="p-1.5 rounded-lg bg-white dark:bg-slate-600 border border-gray-300/80 dark:border-slate-500/80 text-[10px] hover:bg-gray-100/90 dark:hover:bg-slate-500/90 text-gray-700 dark:text-gray-300">
                              <Edit className="w-3.5 h-3.5" />
                            </button>
                            <button
                              onClick={() => changeUserRole(user.id, user.role === 'admin' ? 'student' : 'admin')}
                              className="p-1.5 rounded-lg bg-white dark:bg-slate-600 border border-gray-300/80 dark:border-slate-500/80 text-[10px] hover:bg-gray-100/90 dark:hover:bg-slate-500/90 text-gray-700 dark:text-gray-300"
                              title={`Change role from ${user.role} to ${user.role === 'admin' ? 'student' : 'admin'}`}
                            >
                              <Shield className="w-3.5 h-3.5" />
                            </button>
                            <button
                              onClick={() => handleDelete(user.id)}
                              disabled={deleteLoading === user.id}
                              className="p-1.5 rounded-lg bg-white dark:bg-slate-600 border border-gray-300/80 dark:border-slate-500/80 text-[10px] hover:bg-rose-600/20 dark:hover:bg-rose-600/30 hover:border-rose-500/40 dark:hover:border-rose-400/40 text-gray-700 dark:text-gray-300 hover:text-rose-300 dark:hover:text-rose-400 disabled:opacity-50"
                            >
                              {deleteLoading === user.id ? (
                                <div className="w-3.5 h-3.5 border border-current border-t-transparent rounded-full animate-spin"></div>
                              ) : (
                                <Trash2 className="w-3.5 h-3.5" />
                              )}
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
      </main>
    </DashboardLayout>
  )
}

export default function UsersPage() {
  return <UsersContent />
}
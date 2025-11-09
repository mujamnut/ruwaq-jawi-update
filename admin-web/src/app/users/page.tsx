'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import QueryProvider from "@/components/query-provider"
import Sidebar from "@/components/sidebar"
import Header from "@/components/header"
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
  Download
} from "lucide-react"
import { supabase } from "@/lib/supabase"

interface User {
  id: string
  email: string
  full_name: string
  avatar_url: string
  role: string
  is_active: boolean
  last_sign_in: string
  created_at: string
  updated_at: string
  user_metadata?: {
    phone?: string
    bio?: string
  }
}

function UsersContent() {
  const [users, setUsers] = useState<User[]>([])
  const [searchTerm, setSearchTerm] = useState('')
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)
  const [loading, setLoading] = useState(true)
  const [deleteLoading, setDeleteLoading] = useState<string | null>(null)
  const [statusFilter, setStatusFilter] = useState<'all' | 'active' | 'inactive'>('all')

  useEffect(() => {
    fetchUsers()
  }, [statusFilter])

  const fetchUsers = async () => {
    try {
      setLoading(true)
      let query = supabase
        .from('profiles')
        .select('*')
        .order('created_at', { ascending: false })

      // Apply status filter
      if (statusFilter !== 'all') {
        query = query.eq('is_active', statusFilter === 'active')
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

  const toggleUserStatus = async (id: string, currentStatus: boolean) => {
    try {
      const { error } = await supabase
        .from('profiles')
        .update({ is_active: !currentStatus })
        .eq('id', id)

      // Handle empty error objects and RLS issues
      if (error) {
        const errorMsg = error?.message || JSON.stringify(error) || 'Unknown error'
        console.error('Error toggling user status:', errorMsg)
        return
      }

      await fetchUsers()
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : JSON.stringify(error) || 'Unknown error'
      console.error('Error toggling user status:', errorMsg)
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
          ['Email', 'Full Name', 'Role', 'Status', 'Created At', 'Last Sign In'].join(','),
          ...data.map(user => [
            user.email,
            user.full_name || 'N/A',
            user.role || 'user',
            user.is_active ? 'Active' : 'Inactive',
            new Date(user.created_at).toLocaleDateString(),
            user.last_sign_in ? new Date(user.last_sign_in).toLocaleDateString() : 'Never'
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
    user.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
    user.full_name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    user.user_metadata?.phone?.toLowerCase().includes(searchTerm.toLowerCase())
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

  const getStatusStats = () => {
    const total = users.length
    const active = users.filter(u => u.is_active).length
    const inactive = total - active
    return { total, active, inactive }
  }

  const stats = getStatusStats()

  return (
    <div className="flex min-h-screen bg-slate-950 text-slate-100 antialiased">
      {/* Sidebar */}
      <Sidebar isCollapsed={sidebarCollapsed} onToggle={() => setSidebarCollapsed(!sidebarCollapsed)} />

      {/* Main Content */}
      <div className="flex-1 flex flex-col min-h-screen lg:ml-0 ml-0">
        {/* Header */}
        <Header
          onMenuToggle={() => setSidebarCollapsed(!sidebarCollapsed)}
          title="Users Management"
          subtitle="User Administration"
        />

        {/* Main Content */}
        <main className="flex-1 px-4 sm:px-6 pb-8 pt-4 bg-gradient-to-br from-slate-950 via-slate-950 to-slate-900">
          {/* Page Header */}
          <div className="card rounded-2xl p-4 sm:p-5 mb-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <h2 className="text-base sm:text-lg font-semibold mb-1">User Management</h2>
                <p className="text-xs text-slate-400">Manage app users and permissions</p>
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={exportUsers}
                  className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-slate-900/90 border border-slate-700/80 text-[11px] font-medium hover:bg-slate-800/90"
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
              <div className="rounded-xl border border-slate-700/80 bg-slate-950/80 p-3">
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-[11px] text-slate-400">Total Users</span>
                  <span className="px-1.5 py-0.5 rounded-full bg-orange-500/10 text-[10px] text-orange-300 border border-orange-500/40">
                    {stats.total}
                  </span>
                </div>
                <p className="text-lg font-semibold">{stats.total}</p>
                <p className="mt-0.5 text-[11px] text-slate-500">Registered users</p>
              </div>
              <div className="rounded-xl border border-slate-700/80 bg-slate-950/80 p-3">
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-[11px] text-slate-400">Active</span>
                  <span className="px-1.5 py-0.5 rounded-full bg-emerald-500/10 text-[10px] text-emerald-300 border border-emerald-500/40">
                    {stats.active}
                  </span>
                </div>
                <p className="text-lg font-semibold">{stats.active}</p>
                <p className="mt-0.5 text-[11px] text-slate-500">Currently active</p>
              </div>
              <div className="rounded-xl border border-slate-700/80 bg-slate-950/80 p-3">
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-[11px] text-slate-400">Inactive</span>
                  <span className="px-1.5 py-0.5 rounded-full bg-rose-500/10 text-[10px] text-rose-300 border border-rose-500/40">
                    {stats.inactive}
                  </span>
                </div>
                <p className="text-lg font-semibold">{stats.inactive}</p>
                <p className="mt-0.5 text-[11px] text-slate-500">Deactivated</p>
              </div>
              <div className="rounded-xl border border-slate-700/80 bg-slate-950/80 p-3">
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-[11px] text-slate-400">Growth</span>
                  <span className="px-1.5 py-0.5 rounded-full bg-indigo-500/10 text-[10px] text-indigo-300 border border-indigo-500/40">
                    +{stats.total}
                  </span>
                </div>
                <p className="text-lg font-semibold">100%</p>
                <p className="mt-0.5 text-[11px] text-slate-500">This month</p>
              </div>
            </div>
          </div>

          {/* Filters and Search */}
          <div className="card rounded-2xl p-4 sm:p-5 mb-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div className="flex items-center gap-2">
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-slate-400 w-4 h-4" />
                  <input
                    type="text"
                    placeholder="Search users by name, email, or phone..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="pl-10 pr-4 py-2 w-full sm:w-80 rounded-xl bg-slate-900/80 border border-slate-700/80 text-xs text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-orange-500/50 focus:border-orange-500/50"
                  />
                </div>
                <select
                  value={statusFilter}
                  onChange={(e) => setStatusFilter(e.target.value as any)}
                  className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-slate-900/80 border border-slate-700/80 text-[11px] font-medium hover:bg-slate-800/90"
                >
                  <option value="all">All Users</option>
                  <option value="active">Active Only</option>
                  <option value="inactive">Inactive Only</option>
                </select>
                <button className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-slate-900/80 border border-slate-700/80 text-[11px] font-medium hover:bg-slate-800/90">
                  <Filter className="w-3.5 h-3.5" />
                  More Filters
                </button>
              </div>
              <div className="text-[11px] text-slate-400">
                Showing {filteredUsers.length} of {users.length} users
              </div>
            </div>
          </div>

          {/* Users Table */}
          <div className="card rounded-2xl p-4 sm:p-5">
            <div className="overflow-x-auto no-scrollbar">
              <table className="w-full text-left border-separate border-spacing-y-1.5">
                <thead className="text-[10px] uppercase tracking-[.18em] text-slate-500">
                  <tr>
                    <th className="px-2 py-1.5">User</th>
                    <th className="px-2 py-1.5 whitespace-nowrap">Role</th>
                    <th className="px-2 py-1.5 whitespace-nowrap">Status</th>
                    <th className="px-2 py-1.5 whitespace-nowrap">Last Active</th>
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
                          <span className="ml-2 text-slate-400">Loading users...</span>
                        </div>
                      </td>
                    </tr>
                  ) : filteredUsers.length === 0 ? (
                    <tr>
                      <td colSpan={7} className="text-center py-8">
                        <div className="flex flex-col items-center">
                          <Users className="w-12 h-12 text-slate-600 mb-3" />
                          <h3 className="text-sm font-medium text-slate-300 mb-1">No users found</h3>
                          <p className="text-[11px] text-slate-500">
                            {searchTerm ? 'No users match your search criteria' : 'Start by adding your first user'}
                          </p>
                        </div>
                      </td>
                    </tr>
                  ) : (
                    filteredUsers.map((user) => (
                      <tr key={user.id} className="bg-slate-950/90 hover:bg-slate-900/90 transition border border-slate-800/80">
                        <td className="px-2 py-3">
                          <div className="flex items-center gap-3">
                            <div className="w-10 h-10 rounded-xl bg-slate-900 flex items-center justify-center border border-slate-700/80">
                              {user.avatar_url ? (
                                <img
                                  src={user.avatar_url}
                                  alt={user.full_name || user.email}
                                  className="w-full h-full object-cover rounded-xl"
                                />
                              ) : (
                                <UserCheck className="w-4 h-4 text-orange-400" />
                              )}
                            </div>
                            <div className="flex-1 min-w-0">
                              <p className="text-xs font-medium text-slate-100 truncate">
                                {user.full_name || 'No name'}
                              </p>
                              <p className="text-[10px] text-slate-400 truncate">
                                {user.email}
                              </p>
                              {user.user_metadata?.phone && (
                                <p className="text-[10px] text-slate-500">
                                  {user.user_metadata.phone}
                                </p>
                              )}
                            </div>
                          </div>
                        </td>
                        <td className="px-2 py-3">
                          <span className={`px-2 py-0.5 rounded-full text-[10px] border ${
                            user.role === 'admin'
                              ? 'bg-rose-500/10 text-rose-300 border-rose-500/40'
                              : user.role === 'premium'
                              ? 'bg-amber-500/10 text-amber-300 border-amber-500/40'
                              : 'bg-blue-500/10 text-blue-300 border-blue-500/40'
                          }`}>
                            {formatRole(user.role)}
                          </span>
                        </td>
                        <td className="px-2 py-3">
                          <span className={`px-2 py-0.5 rounded-full text-[10px] border ${
                            user.is_active
                              ? 'bg-emerald-500/10 text-emerald-300 border-emerald-500/40'
                              : 'bg-rose-500/10 text-rose-300 border-rose-500/40'
                          }`}>
                            {user.is_active ? 'Active' : 'Inactive'}
                          </span>
                        </td>
                        <td className="px-2 py-3">
                          <div className="flex items-center gap-1 text-[11px] text-slate-400">
                            <Activity className="w-3.5 h-3.5" />
                            {formatDate(user.last_sign_in)}
                          </div>
                        </td>
                        <td className="px-2 py-3">
                          <div className="flex items-center gap-1 text-[11px] text-slate-400">
                            <Calendar className="w-3.5 h-3.5" />
                            {formatDate(user.created_at)}
                          </div>
                        </td>
                        <td className="px-2 py-3">
                          <div className="flex items-center justify-end gap-1">
                            <button className="p-1.5 rounded-lg bg-slate-900 border border-slate-700/80 text-[10px] hover:bg-slate-800/90 text-slate-300">
                              <Eye className="w-3.5 h-3.5" />
                            </button>
                            <button className="p-1.5 rounded-lg bg-slate-900 border border-slate-700/80 text-[10px] hover:bg-slate-800/90 text-slate-300">
                              <Edit className="w-3.5 h-3.5" />
                            </button>
                            <button
                              onClick={() => toggleUserStatus(user.id, user.is_active)}
                              className={`p-1.5 rounded-lg border text-[10px] hover:${
                                user.is_active
                                  ? 'bg-rose-600/20 border-rose-500/40 text-rose-300'
                                  : 'bg-emerald-600/20 border-emerald-500/40 text-emerald-300'
                              }`}
                            >
                              {user.is_active ? (
                                <Ban className="w-3.5 h-3.5" />
                              ) : (
                                <Shield className="w-3.5 h-3.5" />
                              )}
                            </button>
                            <button
                              onClick={() => handleDelete(user.id)}
                              disabled={deleteLoading === user.id}
                              className="p-1.5 rounded-lg bg-slate-900 border border-slate-700/80 text-[10px] hover:bg-rose-600/20 hover:border-rose-500/40 text-slate-300 hover:text-rose-300 disabled:opacity-50"
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
      </div>
    </div>
  )
}

export default function UsersPage() {
  return (
    <QueryProvider>
      <UsersContent />
    </QueryProvider>
  )
}
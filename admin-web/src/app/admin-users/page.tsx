'use client'

import { useState, useEffect } from 'react'
import DashboardLayout from "@/components/dashboard-layout"
import { Shield, Plus, Search, Filter, MoreHorizontal, User, Mail, Calendar, CheckCircle, XCircle, AlertTriangle, Edit, Trash2, Key } from 'lucide-react'
import { supabase } from '@/lib/supabase'
import { formatDistanceToNow } from 'date-fns'
import { BulkOperations, BulkCheckbox } from '@/components/bulk-operations'

interface AdminUser {
  id: string
  email: string | null
  full_name: string | null
  role: 'admin' | 'student'
  subscription_status: string | null
  created_at: string
  updated_at: string
  last_seen_at: string | null
  phone_number: string | null
  avatar_url: string | null
}

function AdminUsersContent() {
  const [users, setUsers] = useState<AdminUser[]>([])
  const [filteredUsers, setFilteredUsers] = useState<AdminUser[]>([])
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState('')
  const [statusFilter, setStatusFilter] = useState<string>('all')
  const [roleFilter, setRoleFilter] = useState<string>('all')
  const [showCreateModal, setShowCreateModal] = useState(false)
  const [showResetPasswordModal, setShowResetPasswordModal] = useState(false)
  const [selectedUser, setSelectedUser] = useState<AdminUser | null>(null)
  const [selectedItems, setSelectedItems] = useState<string[]>([])
  const [isLoading, setIsLoading] = useState(false)

  useEffect(() => {
    fetchUsers()
  }, [])

  useEffect(() => {
    filterUsers()
  }, [users, searchTerm, statusFilter, roleFilter])

  const fetchUsers = async () => {
    try {
      // Optimized query with timeout and selected fields only
      const { data, error } = await Promise.race([
        supabase
          .from('profiles')
          .select('id, email, full_name, role, subscription_status, created_at, updated_at, last_seen_at, phone_number, avatar_url')
          .in('role', ['admin', 'student'])
          .order('created_at', { ascending: false }),
        new Promise((_, reject) => setTimeout(() => reject(new Error('Query timeout')), 3000))
      ]) as any

      // Handle empty error objects and RLS issues
      if (error) {
        // Set empty state immediately instead of hanging
        setUsers([])
        return
      }

      setUsers(data || [])
    } catch (error) {
      // Set empty state on error
      setUsers([])
    } finally {
      setLoading(false)
    }
  }

  const filterUsers = () => {
    let filtered = users

    if (searchTerm) {
      filtered = filtered.filter(user =>
        user.email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        user.full_name?.toLowerCase().includes(searchTerm.toLowerCase())
      )
    }

    if (statusFilter !== 'all') {
      filtered = filtered.filter(user => user.subscription_status === statusFilter)
    }

    if (roleFilter !== 'all') {
      filtered = filtered.filter(user => user.role === roleFilter)
    }

    setFilteredUsers(filtered)
  }

  const handleCreateUser = async (formData: {
    email: string
    fullName: string
    role: 'admin' | 'student'
    password: string
  }) => {
    try {
      setIsLoading(true)

      // Create user in Supabase Auth
      const { data: authData, error: authError } = await supabase.auth.admin.createUser({
        email: formData.email,
        password: formData.password,
        email_confirm: true,
        user_metadata: {
          full_name: formData.fullName,
          role: formData.role
        }
      })

      if (authError) throw authError

      // Create profile record
      if (authData.user) {
        const { error: profileError } = await supabase
          .from('profiles')
          .insert({
            id: authData.user.id,
            email: formData.email,
            full_name: formData.fullName,
            role: formData.role,
            subscription_status: 'active'
          })

        if (profileError) throw profileError
      }

      await fetchUsers()
      setShowCreateModal(false)
    } catch (error) {
      console.error('Error creating user:', error)
      alert('Failed to create user. Please try again.')
    } finally {
      setIsLoading(false)
    }
  }

  const handleResetPassword = async (email: string) => {
    try {
      const { error } = await supabase.auth.resetPasswordForEmail(email)

      // Handle empty error objects and RLS issues
      if (error) {
        const errorMsg = error?.message || JSON.stringify(error) || 'Unknown error'
        console.error('Error sending password reset:', errorMsg)
        alert('Failed to send password reset email.')
        return
      }

      alert('Password reset email sent successfully!')
      setShowResetPasswordModal(false)
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : JSON.stringify(error) || 'Unknown error'
      console.error('Error sending password reset:', errorMsg)
      alert('Failed to send password reset email.')
    }
  }

  const handleUpdateSubscriptionStatus = async (userId: string, newStatus: string) => {
    try {
      const { error } = await supabase
        .from('profiles')
        .update({ subscription_status: newStatus })
        .eq('id', userId)

      // Handle empty error objects and RLS issues
      if (error) {
        const errorMsg = error?.message || JSON.stringify(error) || 'Unknown error'
        console.error('Error updating user subscription status:', errorMsg)
        alert('Failed to update user subscription status.')
        return
      }

      await fetchUsers()
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : JSON.stringify(error) || 'Unknown error'
      console.error('Error updating user subscription status:', errorMsg)
      alert('Failed to update user subscription status.')
    }
  }

  const getRoleBadgeColor = (role: string) => {
    switch (role) {
      case 'admin':
        return 'bg-purple-500/10 text-purple-300 dark:text-purple-400 border-purple-500/40 dark:border-purple-400/40'
      case 'student':
        return 'bg-blue-500/10 text-blue-300 dark:text-blue-400 border-blue-500/40 dark:border-blue-400/40'
      default:
        return 'bg-slate-500/10 text-gray-700 dark:text-gray-300 border-gray-500/40 dark:border-slate-500/40'
    }
  }

  const getStatusBadgeColor = (status: string | null) => {
    switch (status) {
      case 'active':
        return 'bg-emerald-500/10 text-emerald-300 dark:text-emerald-400 border-emerald-500/40 dark:border-emerald-400/40'
      case 'inactive':
        return 'bg-slate-500/10 text-gray-700 dark:text-gray-300 border-gray-500/40 dark:border-slate-500/40'
      case 'expired':
        return 'bg-amber-500/10 text-amber-300 dark:text-amber-400 border-amber-500/40 dark:border-amber-400/40'
      default:
        return 'bg-slate-500/10 text-gray-700 dark:text-gray-300 border-gray-500/40 dark:border-slate-500/40'
    }
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
          <div className="h-10 w-24 bg-gray-100 dark:bg-slate-700 rounded-lg animate-pulse"></div>
        </div>

        {/* Filters skeleton */}
        <div className="flex flex-col sm:flex-row gap-4">
          <div className="flex-1 h-10 bg-gray-100 dark:bg-slate-700 rounded-lg animate-pulse"></div>
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
              </div>
            ))}
          </div>
        </div>
      </div>
    )
  }

  return (
    <DashboardLayout title="Admin Users" subtitle="Admin account management">
          <div className="space-y-6 px-4 sm:px-6 pb-8 pt-4">
            {/* Header */}
            <div className="flex items-center justify-between">
              <div>
                <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Admin Users</h1>
                <p className="text-gray-600 dark:text-gray-400 mt-1">Manage administrator and student accounts</p>
              </div>
              <button
                onClick={() => setShowCreateModal(true)}
                className="inline-flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
              >
                <Plus className="w-4 h-4" />
                Add User
              </button>
            </div>

            {/* Filters */}
            <div className="flex flex-col sm:flex-row gap-4">
              <div className="flex-1 relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-600 dark:text-gray-400 w-4 h-4" />
                <input
                  type="text"
                  placeholder="Search users by name or email..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="w-full pl-10 pr-4 py-2 bg-white/80 dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80 rounded-lg text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
                />
              </div>
              <select
                value={roleFilter}
                onChange={(e) => setRoleFilter(e.target.value)}
                className="px-4 py-2 bg-white/80 dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80 rounded-lg text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
              >
                <option value="all">All Roles</option>
                <option value="admin">Admins</option>
                <option value="student">Students</option>
              </select>
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className="px-4 py-2 bg-white/80 dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80 rounded-lg text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
              >
                <option value="all">All Status</option>
                <option value="active">Active</option>
                <option value="inactive">Inactive</option>
                <option value="expired">Expired</option>
              </select>
            </div>

            {/* Users Table */}
            <div className="bg-white/80 dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80 rounded-xl overflow-hidden">
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="border-b border-gray-300/80 dark:border-slate-600/80">
                      <th className="text-left p-4 text-sm font-medium text-gray-700 dark:text-gray-300">User</th>
                      <th className="text-left p-4 text-sm font-medium text-gray-700 dark:text-gray-300">Role</th>
                      <th className="text-left p-4 text-sm font-medium text-gray-700 dark:text-gray-300">Status</th>
                      <th className="text-left p-4 text-sm font-medium text-gray-700 dark:text-gray-300">Last Seen</th>
                      <th className="text-left p-4 text-sm font-medium text-gray-700 dark:text-gray-300">Created</th>
                      <th className="text-left p-4 text-sm font-medium text-gray-700 dark:text-gray-300">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredUsers.map((user) => (
                      <tr key={user.id} className="border-b border-gray-200/50 dark:border-slate-700/50 hover:bg-gray-100/30 dark:hover:bg-slate-700/30 transition-colors">
                        <td className="p-4">
                          <div className="flex items-center gap-3">
                            <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-blue-500 to-indigo-500 flex items-center justify-center">
                              <User className="w-4 h-4 text-white" />
                            </div>
                            <div>
                              <div className="text-sm font-medium text-gray-900 dark:text-white">{user.full_name || 'Unknown User'}</div>
                              <div className="text-xs text-gray-600 dark:text-gray-400">{user.email}</div>
                            </div>
                          </div>
                        </td>
                        <td className="p-4">
                          <span className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium border ${getRoleBadgeColor(user.role)}`}>
                            <Shield className="w-3 h-3" />
                            {user.role}
                          </span>
                        </td>
                        <td className="p-4">
                          <span className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium border ${getStatusBadgeColor(user.subscription_status)}`}>
                            {user.subscription_status || 'inactive'}
                          </span>
                        </td>
                        <td className="p-4">
                          <div className="text-sm text-gray-700 dark:text-gray-300">
                            {user.last_seen_at
                              ? formatDistanceToNow(new Date(user.last_seen_at), { addSuffix: true })
                              : 'Never'
                            }
                          </div>
                        </td>
                        <td className="p-4">
                          <div className="text-sm text-gray-700 dark:text-gray-300">
                            {formatDistanceToNow(new Date(user.created_at), { addSuffix: true })}
                          </div>
                        </td>
                        <td className="p-4">
                          <div className="flex items-center gap-2">
                            <button
                              onClick={() => {
                                setSelectedUser(user)
                                setShowResetPasswordModal(true)
                              }}
                              className="p-1 text-gray-600 hover:text-blue-400 transition-colors"
                              title="Reset Password"
                            >
                              <Key className="w-4 h-4" />
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {filteredUsers.length === 0 && (
                <div className="text-center py-12">
                  <div className="w-12 h-12 rounded-full bg-gray-100 flex items-center justify-center mx-auto mb-4">
                    <User className="w-6 h-6 text-gray-600" />
                  </div>
                  <h3 className="text-sm font-medium text-gray-700 mb-1">No users found</h3>
                  <p className="text-xs text-gray-500">
                    {searchTerm || statusFilter !== 'all' || roleFilter !== 'all'
                      ? 'Try adjusting your search or filters'
                      : 'Get started by adding your first admin user'
                    }
                  </p>
                </div>
              )}
            </div>

            {/* Create User Modal */}
            {showCreateModal && (
              <CreateUserModal
                onClose={() => setShowCreateModal(false)}
                onSubmit={handleCreateUser}
                isLoading={isLoading}
              />
            )}

            {/* Reset Password Modal */}
            {showResetPasswordModal && selectedUser && (
              <ResetPasswordModal
                user={selectedUser}
                onClose={() => setShowResetPasswordModal(false)}
                onConfirm={() => selectedUser.email && handleResetPassword(selectedUser.email)}
              />
            )}
          </div>
    </DashboardLayout>
  )
}

function CreateUserModal({
  onClose,
  onSubmit,
  isLoading
}: {
  onClose: () => void
  onSubmit: (data: {
    email: string
    fullName: string
    role: 'admin' | 'student'
    password: string
  }) => void
  isLoading: boolean
}) {
  const [formData, setFormData] = useState({
    email: '',
    fullName: '',
    role: 'admin' as 'admin' | 'student',
    password: '',
    confirmPassword: ''
  })
  const [errors, setErrors] = useState<Record<string, string>>({})

  const validateForm = () => {
    const newErrors: Record<string, string> = {}

    if (!formData.email) newErrors.email = 'Email is required'
    else if (!/\S+@\S+\.\S+/.test(formData.email)) newErrors.email = 'Email is invalid'

    if (!formData.fullName) newErrors.fullName = 'Full name is required'

    if (!formData.password) newErrors.password = 'Password is required'
    else if (formData.password.length < 6) newErrors.password = 'Password must be at least 6 characters'

    if (formData.password !== formData.confirmPassword) {
      newErrors.confirmPassword = 'Passwords do not match'
    }

    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (validateForm()) {
      onSubmit({
        email: formData.email,
        fullName: formData.fullName,
        role: formData.role,
        password: formData.password
      })
    }
  }

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="w-full max-w-md bg-white rounded-xl border border-gray-300/80 p-6">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-xl font-bold text-white">Create New User</h2>
          <button
            onClick={onClose}
            className="text-gray-600 hover:text-white transition-colors"
          >
            <XCircle className="w-5 h-5" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Email Address
            </label>
            <input
              type="email"
              value={formData.email}
              onChange={(e) => setFormData({ ...formData, email: e.target.value })}
              className={`w-full px-3 py-2 bg-gray-100 border rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50 ${
                errors.email ? 'border-rose-500' : 'border-gray-400'
              }`}
              placeholder="user@example.com"
            />
            {errors.email && <p className="mt-1 text-xs text-rose-400">{errors.email}</p>}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Full Name
            </label>
            <input
              type="text"
              value={formData.fullName}
              onChange={(e) => setFormData({ ...formData, fullName: e.target.value })}
              className={`w-full px-3 py-2 bg-gray-100 border rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50 ${
                errors.fullName ? 'border-rose-500' : 'border-gray-400'
              }`}
              placeholder="John Doe"
            />
            {errors.fullName && <p className="mt-1 text-xs text-rose-400">{errors.fullName}</p>}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Role
            </label>
            <select
              value={formData.role}
              onChange={(e) => setFormData({ ...formData, role: e.target.value as 'admin' | 'student' })}
              className="w-full px-3 py-2 bg-gray-100 border border-gray-400 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50"
            >
              <option value="admin">Administrator</option>
              <option value="student">Student</option>
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Password
            </label>
            <input
              type="password"
              value={formData.password}
              onChange={(e) => setFormData({ ...formData, password: e.target.value })}
              className={`w-full px-3 py-2 bg-gray-100 border rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50 ${
                errors.password ? 'border-rose-500' : 'border-gray-400'
              }`}
              placeholder="••••••••"
            />
            {errors.password && <p className="mt-1 text-xs text-rose-400">{errors.password}</p>}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Confirm Password
            </label>
            <input
              type="password"
              value={formData.confirmPassword}
              onChange={(e) => setFormData({ ...formData, confirmPassword: e.target.value })}
              className={`w-full px-3 py-2 bg-gray-100 border rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50 ${
                errors.confirmPassword ? 'border-rose-500' : 'border-gray-400'
              }`}
              placeholder="••••••••"
            />
            {errors.confirmPassword && <p className="mt-1 text-xs text-rose-400">{errors.confirmPassword}</p>}
          </div>

          <div className="flex gap-3 pt-4">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 px-4 py-2 bg-gray-200 text-white rounded-lg hover:bg-gray-300 transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isLoading}
              className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isLoading ? 'Creating...' : 'Create User'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

function ResetPasswordModal({
  user,
  onClose,
  onConfirm
}: {
  user: AdminUser
  onClose: () => void
  onConfirm: () => void
}) {
  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="w-full max-w-md bg-white rounded-xl border border-gray-300/80 p-6">
        <div className="flex items-center gap-3 mb-4">
          <div className="w-10 h-10 rounded-full bg-amber-500/20 border border-amber-500/40 flex items-center justify-center">
            <Key className="w-5 h-5 text-amber-400" />
          </div>
          <div>
            <h2 className="text-lg font-bold text-white">Reset Password</h2>
            <p className="text-sm text-gray-600">Send password reset email</p>
          </div>
        </div>

        <div className="mb-6">
          <p className="text-sm text-gray-700">
            Send a password reset email to <span className="font-medium text-white">{user.email}</span>?
          </p>
          <p className="text-xs text-gray-500 mt-2">
            The user will receive an email with instructions to reset their password.
          </p>
        </div>

        <div className="flex gap-3">
          <button
            onClick={onClose}
            className="flex-1 px-4 py-2 bg-gray-200 text-white rounded-lg hover:bg-gray-300 transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={onConfirm}
            className="flex-1 px-4 py-2 bg-amber-600 text-white rounded-lg hover:bg-amber-700 transition-colors"
          >
            Send Reset Email
          </button>
        </div>
      </div>
    </div>
  )
}

export default function AdminUsersPage() {
  return <AdminUsersContent />
}

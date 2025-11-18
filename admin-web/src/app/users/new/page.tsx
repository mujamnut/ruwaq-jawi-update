'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import DashboardLayout from "@/components/dashboard-layout"
import { ArrowLeft, User, Mail, Phone, Shield, Check, X, Save, Users, Key, Lock, UserCheck } from 'lucide-react'
import { supabaseAdmin } from '@/lib/supabase'

interface FormData {
  email: string
  full_name: string
  password: string
  phone_number: string
  role: 'student' | 'admin'
  subscription_status: 'active' | 'inactive'
}

export default function AddUserPage() {
  const router = useRouter()
  const [loading, setLoading] = useState(false)
  const [formData, setFormData] = useState<FormData>({
    email: '',
    full_name: '',
    password: '',
    phone_number: '',
    role: 'student',
    subscription_status: 'inactive'
  })
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState(false)
  const [showPassword, setShowPassword] = useState(false)

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target
    setFormData(prev => ({
      ...prev,
      [name]: value
    }))

    // Clear error when user starts typing
    if (error) {
      setError(null)
    }
  }

  const validateForm = () => {
    if (!formData.email.trim()) {
      setError('Email is required')
      return false
    }

    if (!formData.email.includes('@')) {
      setError('Please enter a valid email address')
      return false
    }

    if (!formData.full_name.trim()) {
      setError('Full name is required')
      return false
    }

    if (!formData.password || formData.password.length < 6) {
      setError('Password must be at least 6 characters long')
      return false
    }

    return true
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    if (!validateForm()) {
      return
    }

    setLoading(true)
    setError(null)

    try {
      // Create user in Supabase Auth
      const { data: authData, error: authError } = await supabaseAdmin.auth.signUp({
        email: formData.email.trim().toLowerCase(),
        password: formData.password,
        options: {
          data: {
            full_name: formData.full_name.trim(),
            role: formData.role,
            phone_number: formData.phone_number?.trim() || null
          }
        }
      })

      if (authError) {
        if (authError.message.includes('already registered')) {
          setError('This email is already registered. Please use a different email.')
        } else if (authError.message.includes('Password should be')) {
          setError('Password must be at least 6 characters long.')
        } else {
          setError(`Error creating user: ${authError.message}`)
        }
        return
      }

      if (authData.user) {
        // Additional profile data can be stored in profiles table if needed
        // The auth.signUp already creates the profile with the metadata
        setSuccess(true)

        // Reset form after successful submission
        setFormData({
          email: '',
          full_name: '',
          password: '',
          phone_number: '',
          role: 'student',
          subscription_status: 'inactive'
        })

        // Redirect after a delay to show success message
        setTimeout(() => {
          router.push('/users')
        }, 2000)
      }
    } catch (err) {
      console.error('Error creating user:', err)
      setError('An unexpected error occurred while creating the user. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <DashboardLayout title="Add New User" subtitle="Create a new user account">
      <main className="flex-1 px-4 sm:px-6 pb-8 pt-4 mx-auto max-w-full bg-gray-50 dark:bg-gradient-to-br dark:from-slate-950 dark:via-slate-950 dark:to-slate-900 transition-colors duration-300">
        {/* Header */}
        <div className="mb-6">
          <button
            onClick={() => router.back()}
            className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-white dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80 text-[11px] font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-100/90 dark:hover:bg-slate-700/90 transition-all"
          >
            <ArrowLeft className="w-4 h-4" />
            Back to Users
          </button>
        </div>

        <div className="max-w-2xl mx-auto">
          {/* Success Message */}
          {success && (
            <div className="mb-6 p-4 rounded-xl bg-emerald-50 dark:bg-emerald-500/10 border border-emerald-200 dark:border-emerald-500/40">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-emerald-500/20 dark:bg-emerald-500/30 flex items-center justify-center">
                  <Check className="w-5 h-5 text-emerald-600 dark:text-emerald-400" />
                </div>
                <div>
                  <h3 className="font-medium text-emerald-900 dark:text-emerald-300">User Created Successfully!</h3>
                  <p className="text-sm text-emerald-700 dark:text-emerald-400 mt-0.5">
                    The new user has been created and will be redirected to the users list.
                  </p>
                </div>
              </div>
            </div>
          )}

          {/* Error Message */}
          {error && (
            <div className="mb-6 p-4 rounded-xl bg-rose-50 dark:bg-rose-500/10 border border-rose-200 dark:border-rose-500/40">
              <div className="flex items-start gap-3">
                <div className="w-10 h-10 rounded-xl bg-rose-500/20 dark:bg-rose-500/30 flex items-center justify-center flex-shrink-0 mt-0.5">
                  <X className="w-5 h-5 text-rose-600 dark:text-rose-400" />
                </div>
                <div>
                  <h3 className="font-medium text-rose-900 dark:text-rose-300">Error</h3>
                  <p className="text-sm text-rose-700 dark:text-rose-400 mt-0.5">{error}</p>
                </div>
              </div>
            </div>
          )}

          {/* Form Card */}
          <div className="card rounded-2xl p-6 sm:p-8 bg-white dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80">
            <form onSubmit={handleSubmit} className="space-y-6">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {/* Email */}
                <div>
                  <label className="block text-xs font-semibold text-gray-900 dark:text-white mb-1.5">
                    <Mail className="w-3.5 h-3.5 inline mr-1.5 text-orange-500 dark:text-orange-400" />
                    Email Address
                  </label>
                  <input
                    type="email"
                    name="email"
                    value={formData.email}
                    onChange={handleInputChange}
                    placeholder="user@example.com"
                    disabled={loading}
                    className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-orange-500/50 dark:focus:ring-orange-400/50 focus:border-orange-500/50 dark:focus:border-orange-400/50 disabled:opacity-50"
                    required
                  />
                </div>

                {/* Full Name */}
                <div>
                  <label className="block text-xs font-semibold text-gray-900 dark:text-white mb-1.5">
                    <User className="w-3.5 h-3.5 inline mr-1.5 text-orange-500 dark:text-orange-400" />
                    Full Name
                  </label>
                  <input
                    type="text"
                    name="full_name"
                    value={formData.full_name}
                    onChange={handleInputChange}
                    placeholder="John Doe"
                    disabled={loading}
                    className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-orange-500/50 dark:focus:ring-orange-400/50 focus:border-orange-500/50 dark:focus:border-orange-400/50 disabled:opacity-50"
                    required
                  />
                </div>

                {/* Password */}
                <div>
                  <label className="block text-xs font-semibold text-gray-900 dark:text-white mb-1.5">
                    <Key className="w-3.5 h-3.5 inline mr-1.5 text-orange-500 dark:text-orange-400" />
                    Password
                  </label>
                  <div className="relative">
                    <input
                      type={showPassword ? "text" : "password"}
                      name="password"
                      value={formData.password}
                      onChange={handleInputChange}
                      placeholder="••••••••"
                      disabled={loading}
                      className="w-full px-3 py-2 pr-10 rounded-xl bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-orange-500/50 dark:focus:ring-orange-400/50 focus:border-orange-500/50 dark:focus:border-orange-400/50 disabled:opacity-50"
                      required
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword(!showPassword)}
                      className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
                    >
                      {showPassword ? <X className="w-4 h-4" /> : <UserCheck className="w-4 h-4" />}
                    </button>
                  </div>
                  <p className="mt-1 text-[10px] text-gray-500 dark:text-gray-400">Minimum 6 characters</p>
                </div>

                {/* Phone Number */}
                <div>
                  <label className="block text-xs font-semibold text-gray-900 dark:text-white mb-1.5">
                    <Phone className="w-3.5 h-3.5 inline mr-1.5 text-orange-500 dark:text-orange-400" />
                    Phone Number (Optional)
                  </label>
                  <input
                    type="tel"
                    name="phone_number"
                    value={formData.phone_number}
                    onChange={handleInputChange}
                    placeholder="+60 12-345 6789"
                    disabled={loading}
                    className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-orange-500/50 dark:focus:ring-orange-400/50 focus:border-orange-500/50 dark:focus:border-orange-400/50 disabled:opacity-50"
                  />
                </div>

                {/* Role */}
                <div>
                  <label className="block text-xs font-semibold text-gray-900 dark:text-white mb-1.5">
                    <Shield className="w-3.5 h-3.5 inline mr-1.5 text-orange-500 dark:text-orange-400" />
                    User Role
                  </label>
                  <select
                    name="role"
                    value={formData.role}
                    onChange={handleInputChange}
                    disabled={loading}
                    className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-orange-500/50 dark:focus:ring-orange-400/50 focus:border-orange-500/50 dark:focus:border-orange-400/50 disabled:opacity-50"
                  >
                    <option value="student">Student</option>
                    <option value="admin">Admin</option>
                  </select>
                  <p className="mt-1 text-[10px] text-gray-500 dark:text-gray-400">
                    {formData.role === 'admin' ? 'Full system access' : 'Limited student access'}
                  </p>
                </div>

                {/* Subscription Status */}
                <div>
                  <label className="block text-xs font-semibold text-gray-900 dark:text-white mb-1.5">
                    <Lock className="w-3.5 h-3.5 inline mr-1.5 text-orange-500 dark:text-orange-400" />
                    Subscription Status
                  </label>
                  <select
                    name="subscription_status"
                    value={formData.subscription_status}
                    onChange={handleInputChange}
                    disabled={loading}
                    className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-orange-500/50 dark:focus:ring-orange-400/50 focus:border-orange-500/50 dark:focus:border-orange-400/50 disabled:opacity-50"
                  >
                    <option value="inactive">Free</option>
                    <option value="active">Premium</option>
                  </select>
                  <p className="mt-1 text-[10px] text-gray-500 dark:text-gray-400">
                    {formData.subscription_status === 'active' ? 'Premium features access' : 'Basic features only'}
                  </p>
                </div>
              </div>

              {/* Form Actions */}
              <div className="flex items-center justify-between pt-6 border-t border-gray-200 dark:border-slate-600">
                <button
                  type="button"
                  onClick={() => router.back()}
                  disabled={loading}
                  className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-[11px] font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-100/90 dark:hover:bg-slate-600/80 disabled:opacity-50 transition-all"
                >
                  <X className="w-4 h-4" />
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={loading}
                  className="inline-flex items-center gap-2 px-6 py-2 rounded-xl bg-gradient-to-r from-orange-600 to-red-600 text-white text-xs font-medium hover:from-orange-700 hover:to-red-700 transition-all shadow-lg disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {loading ? (
                    <>
                      <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                      Creating User...
                    </>
                  ) : (
                    <>
                      <Save className="w-4 h-4" />
                      Create User
                    </>
                  )}
                </button>
              </div>
            </form>
          </div>

          {/* Info Card */}
          <div className="mt-6 p-4 rounded-xl bg-blue-50 dark:bg-blue-500/10 border border-blue-200 dark:border-blue-500/40">
            <div className="flex items-start gap-3">
              <div className="w-8 h-8 rounded-lg bg-blue-500/20 dark:bg-blue-500/30 flex items-center justify-center flex-shrink-0 mt-0.5">
                <Users className="w-4 h-4 text-blue-600 dark:text-blue-400" />
              </div>
              <div>
                <h4 className="text-sm font-medium text-blue-900 dark:text-blue-300 mb-1">New User Information</h4>
                <p className="text-xs text-blue-700 dark:text-blue-400">
                  The new user will receive an email confirmation to verify their account. They can log in immediately after creation.
                </p>
              </div>
            </div>
          </div>
        </div>
      </main>
    </DashboardLayout>
  )
}
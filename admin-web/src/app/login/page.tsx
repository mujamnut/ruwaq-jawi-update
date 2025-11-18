'use client'

import { useState } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { Shield, Eye, EyeOff, Mail, Lock, AlertTriangle } from 'lucide-react'
import { supabase } from '@/lib/supabase'

export default function LoginPage() {
  const router = useRouter()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError('')

    try {
      // Validate inputs
      if (!email || !password) {
        setError('Please enter both email and password.')
        return
      }

      // Use real Supabase authentication
      const { data, error: signInError } = await supabase.auth.signInWithPassword({
        email: email.trim().toLowerCase(),
        password,
      })

      if (signInError) {
        // Simplified error handling
        let errorMessage = 'Login failed. Please try again.'

        if (signInError.message === 'Invalid login credentials') {
          errorMessage = 'Invalid email or password. Please check your credentials.'
        } else if (signInError.message.includes('Email not confirmed')) {
          errorMessage = 'Please verify your email address before logging in.'
        } else if (signInError.message.includes('rate limit')) {
          errorMessage = 'Too many login attempts. Please try again later.'
        } else if (signInError.message.includes('failed to fetch') || signInError.message.includes('network')) {
          errorMessage = 'Network error. Please check your internet connection and try again.'
        } else if (signInError.message) {
          errorMessage = `Login failed: ${signInError.message}`
        }

        setError(errorMessage)
        return
      }

      if (!data?.user) {
        setError('Login successful but no user data received. Please try again.')
        return
      }

      // Redirect to dashboard (auth context will handle verification)
      router.push('/')
      router.refresh()
    } catch (error) {
      setError('An unexpected error occurred. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-950 via-slate-950 to-slate-900 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        {/* Logo and Title */}
        <div className="text-center mb-8">
          <div className="w-16 h-16 rounded-2xl bg-gradient-to-tr from-green-500 via-blue-500 to-indigo-500 flex items-center justify-center shadow-lg shadow-green-500/40 mx-auto mb-4">
            <span className="font-bold text-2xl text-white">R</span>
          </div>
          <h1 className="text-2xl font-bold text-white mb-2">Admin Login</h1>
          <p className="text-sm text-gray-600">Maktabah Ruwaq Jawi Management Console</p>
        </div>

        {/* Login Form */}
        <div className="card rounded-2xl p-6 sm:p-8">
          <form onSubmit={handleSubmit} className="space-y-6">
            {error && (
              <div className="flex items-center gap-3 p-3 rounded-xl bg-rose-500/10 border border-rose-500/40">
                <AlertTriangle className="w-4 h-4 text-rose-400" />
                <span className="text-sm text-rose-300">{error}</span>
              </div>
            )}

            {/* Email Field */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Email Address
              </label>
              <div className="relative">
                <Mail className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-600 w-4 h-4" />
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="w-full pl-10 pr-4 py-3 rounded-xl bg-white/80 border border-gray-300/80 text-sm text-gray-900 placeholder:text-gray-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
                  placeholder="Enter your email"
                  required
                />
              </div>
            </div>

            {/* Password Field */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Password
              </label>
              <div className="relative">
                <Lock className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-600 w-4 h-4" />
                <input
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="w-full pl-10 pr-12 py-3 rounded-xl bg-white/80 border border-gray-300/80 text-sm text-gray-900 placeholder:text-gray-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
                  placeholder="Enter your password"
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-600 hover:text-gray-800 transition-colors"
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
            </div>

            {/* Remember Me & Forgot Password */}
            <div className="flex items-center justify-between">
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  className="w-4 h-4 rounded bg-white border border-gray-300 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
                />
                <span className="text-sm text-gray-700">Remember me</span>
              </label>
              <Link href="/forgot-password" className="text-sm text-blue-400 hover:text-blue-300 transition-colors">
                Forgot password?
              </Link>
            </div>

            {/* Submit Button */}
            <button
              type="submit"
              disabled={loading}
              className="w-full py-3 rounded-xl bg-gradient-to-r from-blue-600 to-indigo-600 text-white font-medium hover:from-blue-700 hover:to-indigo-700 transition-all shadow-lg disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? (
                <div className="flex items-center justify-center gap-2">
                  <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                  Signing in...
                </div>
              ) : (
                'Sign In'
              )}
            </button>
          </form>

          {/* Admin Setup Info */}
          <div className="mt-6 p-4 rounded-xl bg-blue-500/10 border border-blue-500/40">
            <div className="flex items-center gap-2 mb-2">
              <Shield className="w-4 h-4 text-blue-400" />
              <h3 className="text-sm font-medium text-gray-800">Admin Access</h3>
            </div>
            <div className="space-y-2 text-xs text-gray-700">
              <p>• Account must have admin role in profiles table</p>
              <p>• Account must have active subscription status</p>
            </div>
            <div className="mt-3 pt-3 border-t border-gray-300/50">
              <p className="text-xs text-gray-600 font-medium mb-2">Account Access:</p>
              <div className="space-y-1 text-xs text-gray-600">
                <p>• Use your registered admin account credentials</p>
                <p>• Contact administrator if you need access</p>
              </div>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="text-center mt-6">
          <p className="text-xs text-gray-500">
            © 2024 Maktabah Ruwaq Jawi. All rights reserved.
          </p>
        </div>
      </div>
    </div>
  )
}
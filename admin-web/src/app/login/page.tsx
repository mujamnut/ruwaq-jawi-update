'use client'

import { useState } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { Shield, Eye, EyeOff, Mail, Lock, AlertCircle } from 'lucide-react'
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

    // Debug: Check if we have the required values
    console.log('Login attempt:', { email: email.substring(0, 5) + '...', hasPassword: !!password })
    console.log('Supabase client available:', !!supabase)
    console.log('Supabase URL:', process.env.NEXT_PUBLIC_SUPABASE_URL?.substring(0, 30) + '...')

    try {
      // Validate inputs
      if (!email || !password) {
        setError('Please enter both email and password.')
        return
      }

      console.log('Attempting Supabase authentication...')

      // Use real Supabase authentication
      const { data, error: signInError } = await supabase.auth.signInWithPassword({
        email: email.trim().toLowerCase(),
        password,
      })

      console.log('Auth response:', {
        hasData: !!data,
        hasUser: !!data?.user,
        hasSession: !!data?.session,
        error: signInError?.message
      })

      if (signInError) {
        console.error('Sign in error details:', {
          message: signInError.message,
          status: signInError.status,
          code: signInError.code,
          fullError: signInError
        })

        // Handle different types of error structures
        let errorMessage = 'Login failed. Please try again.'

        if (signInError.message) {
          if (signInError.message === 'Invalid login credentials') {
            errorMessage = 'Invalid email or password. Please check your credentials.'
          } else if (signInError.message.includes('Email not confirmed')) {
            errorMessage = 'Please verify your email address before logging in.'
          } else if (signInError.message.includes('rate limit')) {
            errorMessage = 'Too many login attempts. Please try again later.'
          } else if (signInError.message.includes('failed to fetch') || signInError.message.includes('network')) {
            errorMessage = 'Network error. Please check your internet connection and try again.'
          } else if (signInError.message.includes('User not found')) {
            errorMessage = 'Account not found. Please check your email address.'
          } else {
            errorMessage = `Login failed: ${signInError.message}`
          }
        } else if (signInError.code) {
          // Handle cases where message is empty but we have a code
          switch (signInError.code) {
            case 'invalid_credentials':
              errorMessage = 'Invalid email or password. Please check your credentials.'
              break
            case 'email_not_confirmed':
              errorMessage = 'Please verify your email address before logging in.'
              break
            case 'too_many_requests':
              errorMessage = 'Too many login attempts. Please try again later.'
              break
            case 'user_not_found':
              errorMessage = 'Account not found. Please check your email address.'
              break
            default:
              errorMessage = `Authentication error (${signInError.code}). Please try again.`
          }
        } else {
          // Fallback for empty error objects
          errorMessage = 'Authentication failed. Please check your credentials and try again.'
        }

        setError(errorMessage)
        return
      }

      if (!data?.user) {
        setError('Login successful but no user data received. Please try again.')
        return
      }

      // Let auth context handle admin verification
      console.log('Login successful - redirecting to auth context for admin verification')
      console.log('User data:', {
        id: data.user.id,
        email: data.user.email,
        aud: data.user.aud,
        app_metadata: data.user.app_metadata
      })

      // Redirect to dashboard (admin verification complete)
      router.push('/')
      router.refresh()
    } catch (error) {
      console.error('Unexpected login error:', {
        error: error,
        message: error instanceof Error ? error.message : 'Unknown error',
        stack: error instanceof Error ? error.stack : undefined
      })
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
          <p className="text-sm text-slate-400">Maktabah Ruwaq Jawi Management Console</p>
        </div>

        {/* Login Form */}
        <div className="card rounded-2xl p-6 sm:p-8">
          <form onSubmit={handleSubmit} className="space-y-6">
            {error && (
              <div className="flex items-center gap-3 p-3 rounded-xl bg-rose-500/10 border border-rose-500/40">
                <AlertCircle className="w-4 h-4 text-rose-400" />
                <span className="text-sm text-rose-300">{error}</span>
              </div>
            )}

            {/* Email Field */}
            <div>
              <label className="block text-sm font-medium text-slate-300 mb-2">
                Email Address
              </label>
              <div className="relative">
                <Mail className="absolute left-3 top-1/2 transform -translate-y-1/2 text-slate-400 w-4 h-4" />
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="w-full pl-10 pr-4 py-3 rounded-xl bg-slate-900/80 border border-slate-700/80 text-sm text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
                  placeholder="Enter your email"
                  required
                />
              </div>
            </div>

            {/* Password Field */}
            <div>
              <label className="block text-sm font-medium text-slate-300 mb-2">
                Password
              </label>
              <div className="relative">
                <Lock className="absolute left-3 top-1/2 transform -translate-y-1/2 text-slate-400 w-4 h-4" />
                <input
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="w-full pl-10 pr-12 py-3 rounded-xl bg-slate-900/80 border border-slate-700/80 text-sm text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
                  placeholder="Enter your password"
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3 top-1/2 transform -translate-y-1/2 text-slate-400 hover:text-slate-200 transition-colors"
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
                  className="w-4 h-4 rounded bg-slate-900 border border-slate-700 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
                />
                <span className="text-sm text-slate-300">Remember me</span>
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
              <h3 className="text-sm font-medium text-slate-200">Admin Access</h3>
            </div>
            <div className="space-y-2 text-xs text-slate-300">
              <p>• Account must have admin role in profiles table</p>
              <p>• Account must have active subscription status</p>
            </div>
            <div className="mt-3 pt-3 border-t border-slate-700/50">
              <p className="text-xs text-slate-400 font-medium mb-2">Account Access:</p>
              <div className="space-y-1 text-xs text-slate-400">
                <p>• Use your registered admin account credentials</p>
                <p>• Contact administrator if you need access</p>
              </div>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="text-center mt-6">
          <p className="text-xs text-slate-500">
            © 2024 Maktabah Ruwaq Jawi. All rights reserved.
          </p>
        </div>
      </div>
    </div>
  )
}
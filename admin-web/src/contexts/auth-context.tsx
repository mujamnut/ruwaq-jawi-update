'use client'

import { createContext, useContext, useState, useEffect, ReactNode, useMemo, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import { supabase } from '@/lib/supabase'
import { User as SupabaseUser } from '@supabase/supabase-js'
import { toast } from 'sonner'

interface User {
  id: string
  email: string
  name?: string
  role: 'student' | 'admin'
  subscription_status?: string
}

interface AuthContextType {
  user: User | null
  supabaseUser: SupabaseUser | null
  login: (email: string, password: string) => Promise<{ success: boolean; error?: string }>
  logout: () => Promise<void>
  isAuthenticated: boolean
  isLoading: boolean
  refreshUser: () => Promise<void>
}

const AuthContext = createContext<AuthContextType | undefined>(undefined)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [supabaseUser, setSupabaseUser] = useState<SupabaseUser | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const router = useRouter()

  // Fetch user profile with admin verification
  const fetchUserProfile = async (supabaseUser: SupabaseUser): Promise<User | null> => {
    try {
      // First check if user is in admin_users table
      const { data: adminUser, error: adminError } = await Promise.race([
        supabase
          .from('admin_users')
          .select('id, email, name, role, permissions, is_active')
          .eq('email', supabaseUser.email || '')
          .eq('is_active', true)
          .single(),
        new Promise((_, reject) =>
          setTimeout(() => reject(new Error('Admin query timeout')), 3000)
        )
      ]) as any

      if (!adminError && adminUser) {
        return {
          id: adminUser.id,
          email: adminUser.email,
          name: adminUser.name,
          role: 'admin',
          subscription_status: 'active'
        }
      }

      // If not admin, check profiles table for potential admin role
      const { data: profile, error } = await Promise.race([
        supabase
          .from('profiles')
          .select('id, email, full_name, role, subscription_status')
          .eq('id', supabaseUser.id)
          .single(),
        new Promise((_, reject) =>
          setTimeout(() => reject(new Error('Profile query timeout')), 3000)
        )
      ]) as any

      if (error || !profile) {
        // Default fallback for non-admin users
        return {
          id: supabaseUser.id,
          email: supabaseUser.email || '',
          name: supabaseUser.user_metadata?.full_name || supabaseUser.email?.split('@')[0] || 'User',
          role: 'student',
          subscription_status: 'inactive'
        }
      }

      return {
        id: profile.id,
        email: profile.email || supabaseUser.email || '',
        name: profile.full_name || supabaseUser.user_metadata?.full_name || 'User',
        role: profile.role || 'student',
        subscription_status: profile.subscription_status || 'inactive'
      }
    } catch (error) {
      // Silent fallback for better performance
      return {
        id: supabaseUser.id,
        email: supabaseUser.email || '',
        name: supabaseUser.user_metadata?.full_name || 'User',
        role: 'student',
        subscription_status: 'inactive'
      }
    }
  }

  // Initialize auth state on mount
  useEffect(() => {
    let mounted = true

    const initializeAuth = async () => {
      try {
        // Get current session from Supabase
        const { data: { session }, error } = await supabase.auth.getSession()

        if (error) {
          setIsLoading(false)
          return
        }

        if (session?.user) {
          setSupabaseUser(session.user)

          // Fetch user profile
          const userProfile = await fetchUserProfile(session.user)

          if (userProfile && mounted) {
            // Only set user if they have admin role
            if (userProfile.role === 'admin') {
              setUser(userProfile)
            } else {
              await supabase.auth.signOut()
            }
          }
        }
      } catch (error) {
        // Silent error handling
      } finally {
        if (mounted) {
          setIsLoading(false)
        }
      }
    }

    initializeAuth()

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, session) => {
      if (!mounted) return

      if (event === 'SIGNED_IN' && session?.user) {
        setSupabaseUser(session.user)

        const userProfile = await fetchUserProfile(session.user)

        if (userProfile) {
          if (userProfile.role === 'admin') {
            setUser(userProfile)
          } else {
            await supabase.auth.signOut()
            router.push('/login')
          }
        } else {
          await supabase.auth.signOut()
          router.push('/login')
        }
      } else if (event === 'SIGNED_OUT') {
        setUser(null)
        setSupabaseUser(null)
        router.push('/login')
      }
    })

    return () => {
      mounted = false
      subscription.unsubscribe()
    }
  }, [router])

  const login = useCallback(async (email: string, password: string): Promise<{ success: boolean; error?: string }> => {
    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      })

      if (error) {
        let errorMessage = 'Login failed. Please try again.'

        if (error.message === 'Invalid login credentials') {
          errorMessage = 'Invalid email or password.'
          toast.error('Invalid email or password')
        } else if (error.message.includes('Email not confirmed')) {
          errorMessage = 'Please verify your email address first.'
          toast.error('Please verify your email address first')
        } else if (error.message.includes('rate limit')) {
          errorMessage = 'Too many login attempts. Please try again later.'
          toast.error('Too many login attempts. Please try again later')
        } else {
          toast.error('Login failed. Please try again')
        }

        return { success: false, error: errorMessage }
      }

      toast.success('Login successful!')
      // Auth state change listener will handle setting the user
      return { success: true }
    } catch (error) {
      toast.error('An unexpected error occurred')
      return { success: false, error: 'An unexpected error occurred.' }
    }
  }, [])

  const logout = useCallback(async () => {
    try {
      await supabase.auth.signOut()
      toast.success('Logged out successfully')
      // The auth state change listener will handle redirect
    } catch (error) {
      // Force redirect even if sign out fails
      setUser(null)
      setSupabaseUser(null)
      router.push('/login')
      toast.error('Error logging out')
    }
  }, [router])

  const refreshUser = useCallback(async () => {
    if (supabaseUser) {
      const userProfile = await fetchUserProfile(supabaseUser)
      if (userProfile) {
        setUser(userProfile)
      }
    }
  }, [supabaseUser])

  const value: AuthContextType = useMemo(() => ({
    user,
    supabaseUser,
    login,
    logout,
    isAuthenticated: !!user && user.role === 'admin',
    isLoading,
    refreshUser
  }), [user, supabaseUser, login, logout, isLoading, refreshUser])

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const context = useContext(AuthContext)
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider')
  }
  return context
}
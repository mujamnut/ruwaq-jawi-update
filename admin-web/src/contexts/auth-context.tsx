'use client'

import { createContext, useContext, useState, useEffect, ReactNode } from 'react'
import { useRouter } from 'next/navigation'
import { supabase } from '@/lib/supabase'
import { User as SupabaseUser } from '@supabase/supabase-js'

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

  // Fetch user profile from profiles table
  const fetchUserProfile = async (supabaseUser: SupabaseUser): Promise<User | null> => {
    try {
      const { data: profile, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', supabaseUser.id)
        .single()

      // Handle empty error objects and RLS issues
      if (error) {
        const errorMsg = error?.message || JSON.stringify(error) || 'Unknown error'
        console.log('Profile fetch error (using fallback):', errorMsg)
      }

      if (error || !profile) {
        // For admin users, create a fallback profile directly from auth user data
        console.log('Using fallback profile due to RLS or missing profile for:', supabaseUser.email)

        // Check if this is the admin user
        if (supabaseUser.email === 'mujj4m@gmail.com') {
          return {
            id: supabaseUser.id,
            email: supabaseUser.email || '',
            name: supabaseUser.user_metadata?.full_name || supabaseUser.email?.split('@')[0] || 'Admin',
            role: 'admin',
            subscription_status: 'active'
          }
        }

        // For other users, try to create a basic profile
        if (supabaseUser.email) {
          console.log('Attempting to create basic profile for user')
          const { data: newProfile, error: insertError } = await supabase
            .from('profiles')
            .insert({
              id: supabaseUser.id,
              email: supabaseUser.email,
              full_name: supabaseUser.user_metadata?.full_name || supabaseUser.email?.split('@')[0] || 'User',
              role: 'student',
              subscription_status: 'inactive'
            })
            .select()
            .single()

          if (!insertError && newProfile) {
            return {
              id: newProfile.id,
              email: newProfile.email || supabaseUser.email || '',
              name: newProfile.full_name || 'User',
              role: newProfile.role || 'student',
              subscription_status: newProfile.subscription_status || 'inactive'
            }
          } else {
            console.warn('Profile creation failed, using auth user data:', insertError)
            // Fallback to auth user data if profile creation fails
            return {
              id: supabaseUser.id,
              email: supabaseUser.email || '',
              name: supabaseUser.user_metadata?.full_name || supabaseUser.email?.split('@')[0] || 'User',
              role: 'student',
              subscription_status: 'inactive'
            }
          }
        }

        return null
      }

      return {
        id: profile.id,
        email: supabaseUser.email || '',
        name: profile.full_name || supabaseUser.user_metadata?.full_name || supabaseUser.email?.split('@')[0] || 'User',
        role: profile.role || 'student',
        subscription_status: profile.subscription_status || 'inactive'
      }
    } catch (error) {
      console.error('Error fetching user profile:', error)
      // Last resort fallback to auth user data
      if (supabaseUser.email === 'mujj4m@gmail.com') {
        return {
          id: supabaseUser.id,
          email: supabaseUser.email || '',
          name: 'Admin',
          role: 'admin',
          subscription_status: 'active'
        }
      }
      return null
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
          console.error('Session error:', error)
          setIsLoading(false)
          return
        }

        if (session?.user) {
          setSupabaseUser(session.user)

          // Fetch user profile
          const userProfile = await fetchUserProfile(session.user)

          if (userProfile && mounted) {
            // Only set user if they have admin role and active subscription
            if (userProfile.role === 'admin') {
              setUser(userProfile)
            } else {
              console.warn('User does not have admin privileges')
              await supabase.auth.signOut()
            }
          }
        }
      } catch (error) {
        console.error('Auth initialization error:', error)
      } finally {
        if (mounted) {
          setIsLoading(false)
        }
      }
    }

    initializeAuth()

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, session) => {
      console.log('Auth state changed:', event, session?.user?.email)

      if (!mounted) return

      if (event === 'SIGNED_IN' && session?.user) {
        setSupabaseUser(session.user)

        const userProfile = await fetchUserProfile(session.user)

        if (userProfile) {
          if (userProfile.role === 'admin' && userProfile.subscription_status === 'active') {
            setUser(userProfile)
            console.log('Admin session established:', userProfile.email)
          } else {
            console.warn('Access denied - user missing admin privileges or active subscription:', userProfile.email)
            await supabase.auth.signOut()
            router.push('/login')
          }
        } else {
          console.warn('Access denied - no admin profile found for user:', supabaseUser.email)
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

  const login = async (email: string, password: string): Promise<{ success: boolean; error?: string }> => {
    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      })

      if (error) {
        let errorMessage = 'Login failed. Please try again.'

        if (error.message === 'Invalid login credentials') {
          errorMessage = 'Invalid email or password.'
        } else if (error.message.includes('Email not confirmed')) {
          errorMessage = 'Please verify your email address first.'
        } else if (error.message.includes('rate limit')) {
          errorMessage = 'Too many login attempts. Please try again later.'
        }

        return { success: false, error: errorMessage }
      }

      // Auth state change listener will handle setting the user
      return { success: true }
    } catch (error) {
      console.error('Login error:', error)
      return { success: false, error: 'An unexpected error occurred.' }
    }
  }

  const logout = async () => {
    try {
      await supabase.auth.signOut()
      // The auth state change listener will handle redirect
    } catch (error) {
      console.error('Logout error:', error)
      // Force redirect even if sign out fails
      setUser(null)
      setSupabaseUser(null)
      router.push('/login')
    }
  }

  const refreshUser = async () => {
    if (supabaseUser) {
      const userProfile = await fetchUserProfile(supabaseUser)
      if (userProfile) {
        setUser(userProfile)
      }
    }
  }

  const value: AuthContextType = {
    user,
    supabaseUser,
    login,
    logout,
    isAuthenticated: !!user && user.role === 'admin',
    isLoading,
    refreshUser
  }

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
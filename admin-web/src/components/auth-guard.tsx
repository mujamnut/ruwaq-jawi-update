'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { useAuth } from '@/contexts/auth-context'
import { Shield } from 'lucide-react'

interface AuthGuardProps {
  children: React.ReactNode
  requireRole?: 'admin' | 'student'
}

export default function AuthGuard({ children, requireRole }: AuthGuardProps) {
  const { user, isAuthenticated, isLoading } = useAuth()
  const router = useRouter()

  useEffect(() => {
    if (!isLoading && !isAuthenticated) {
      router.push('/login')
    }
  }, [isAuthenticated, isLoading, router])

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-950 via-slate-950 to-slate-900 flex items-center justify-center">
        <div className="text-center">
          <div className="w-16 h-16 rounded-2xl bg-gradient-to-tr from-green-500 via-blue-500 to-indigo-500 flex items-center justify-center shadow-lg shadow-green-500/40 mx-auto mb-4">
            <Shield className="w-8 h-8 text-white" />
          </div>
          <div className="w-8 h-8 border-2 border-blue-500 border-t-transparent rounded-full animate-spin mx-auto"></div>
          <p className="text-sm text-slate-400 mt-4">Loading...</p>
        </div>
      </div>
    )
  }

  if (!isAuthenticated) {
    return null // Will redirect
  }

  // Check role requirements
  if (requireRole && user && !hasRequiredRole(user.role, requireRole)) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-950 via-slate-950 to-slate-900 flex items-center justify-center">
        <div className="text-center max-w-md mx-auto p-6">
          <div className="w-16 h-16 rounded-2xl bg-rose-500/20 border border-rose-500/40 flex items-center justify-center mx-auto mb-4">
            <Shield className="w-8 h-8 text-rose-400" />
          </div>
          <h2 className="text-xl font-bold text-white mb-2">Access Denied</h2>
          <p className="text-sm text-slate-400 mb-4">
            You don't have permission to access this page.
          </p>
          <button
            onClick={() => router.push('/')}
            className="px-4 py-2 rounded-xl bg-slate-900/80 border border-slate-700/80 text-sm text-slate-300 hover:bg-slate-800/90 transition-colors"
          >
            Go to Dashboard
          </button>
        </div>
      </div>
    )
  }

  return <>{children}</>
}

function hasRequiredRole(userRole: string, requiredRole: string): boolean {
  const roleHierarchy = {
    'admin': 2,
    'student': 1
  }

  return roleHierarchy[userRole as keyof typeof roleHierarchy] >=
         roleHierarchy[requiredRole as keyof typeof roleHierarchy]
}
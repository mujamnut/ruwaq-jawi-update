'use client'

import { useState, useEffect } from 'react'
import { usePathname } from 'next/navigation'
import Sidebar from '@/components/sidebar'
import Header from '@/components/header'
import AuthGuard from '@/components/auth-guard'
import QueryProvider from '@/components/query-provider'

interface DashboardLayoutProps {
  children: React.ReactNode
  title?: string
  subtitle?: string | React.ReactNode
  headerExtra?: React.ReactNode
  extraIcons?: React.ReactNode
  requireAuth?: boolean
  requireRole?: 'admin' | 'student' | any
}

export default function DashboardLayout({
  children,
  title,
  subtitle,
  headerExtra,
  extraIcons,
  requireAuth = true,
  requireRole = 'admin'
}: DashboardLayoutProps) {
  // Start collapsed by default so the sidebar only shows icons on initial load
  const [sidebarCollapsed, setSidebarCollapsed] = useState(true)
  const pathname = usePathname()

  // Get page title based on pathname
  const getPageTitle = () => {
    if (title) return title

    const pathTitles: Record<string, string> = {
      '/': 'Dashboard',
      '/books': 'Ebooks',
      '/videos': 'Videos',
      '/categories': 'Categories',
      '/users': 'Students',
      '/admin-users': 'Admin Users',
      '/activity': 'Activity Logs',
      '/subscriptions': 'Subscriptions',
      '/subscription-plans': 'Subscription Plans',
      '/payments': 'Payments',
      '/settings': 'Settings',
      '/search': 'Search'
    }

    // Handle dynamic routes
    if (pathname?.startsWith('/books/')) return 'Edit Book'
    if (pathname?.startsWith('/videos/')) return 'Edit Video'
    if (pathname?.startsWith('/categories/')) return 'Edit Category'
    if (pathname?.includes('/new')) return 'Create New'

    return pathTitles[pathname || ''] || 'Admin Dashboard'
  }

  const getPageSubtitle = () => {
    if (subtitle) return subtitle

    const pathSubtitles: Record<string, string> = {
      '/': 'Real-time insights & performance metrics',
      '/books': 'Manage ebook library',
      '/videos': 'Manage video collections',
      '/categories': 'Content categories & organization',
      '/users': 'Student account management',
      '/admin-users': 'Admin account management',
      '/activity': 'System activity logs',
      '/subscriptions': 'User subscription management',
      '/subscription-plans': 'Subscription plan configuration',
      '/payments': 'Payment transaction history',
      '/settings': 'System configuration',
      '/search': 'Advanced content search'
    }

    return pathSubtitles[pathname || ''] || ''
  }

  const pageContent = (
    <div className="flex min-h-screen bg-white dark:bg-slate-950 text-gray-900 dark:text-gray-100 antialiased transition-colors duration-300">
      {/* Fixed Sidebar */}
      <Sidebar
        isCollapsed={sidebarCollapsed}
        onToggle={() => setSidebarCollapsed(!sidebarCollapsed)}
      />

      {/* Mobile overlay: shown when sidebar is open on small screens; clicking closes sidebar */}
      {!sidebarCollapsed && (
        <div
          className="lg:hidden fixed inset-0 bg-black/40 z-20 transition-opacity"
          onClick={() => setSidebarCollapsed(true)}
          aria-hidden="true"
        />
      )}

      {/* Main Content Area - rapat ke sidebar tanpa margin */}
      <div className="flex-1 flex flex-col min-h-screen">
        {/* Standardized Header */}
        <div className={`transition-all duration-300 ${sidebarCollapsed ? 'lg:pl-24' : 'lg:pl-72'}`}>
          <Header
            title={getPageTitle()}
            subtitle={getPageSubtitle()}
            extra={headerExtra}
            extraIcons={extraIcons}
          />
        </div>

        {/* Page Content */}
        <main className={`flex-1 px-4 sm:px-6 lg:px-8 py-6 bg-gray-50 dark:bg-gradient-to-br dark:from-slate-950 dark:via-slate-950 dark:to-slate-900 transition-all duration-300 ${sidebarCollapsed ? 'lg:pl-24' : 'lg:pl-72'}`}>
          <div className="max-w-full">
            {children}
          </div>
        </main>
      </div>
    </div>
  )

  if (requireAuth) {
    return (
      <AuthGuard requireRole={requireRole}>
        <QueryProvider>
          {pageContent}
        </QueryProvider>
      </AuthGuard>
    )
  }

  return (
    <QueryProvider>
      {pageContent}
    </QueryProvider>
  )
}
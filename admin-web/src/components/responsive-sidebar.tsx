'use client'

import { useState, useEffect } from 'react'
import { usePathname } from 'next/navigation'
import Link from 'next/link'
import { useScreenWidth } from '@/hooks/use-screen-width'
import {
  LayoutDashboard,
  BookOpen,
  Video,
  Tag,
  Users,
  UserCog,
  Activity,
  CreditCard,
  DollarSign,
  Settings,
  X,
  Menu,
  ChevronLeft,
  ChevronRight
} from 'lucide-react'

const navItems = [
  { icon: LayoutDashboard, label: 'Dashboard', href: '/', badge: null },
  { icon: BookOpen, label: 'Books', href: '/books', badge: null },
  { icon: Video, label: 'Videos', href: '/videos', badge: null },
  { icon: Tag, label: 'Categories', href: '/categories', badge: null },
  { icon: Users, label: 'Students', href: '/users', badge: null },
  { icon: UserCog, label: 'Admin', href: '/admin-users', badge: null },
  { icon: CreditCard, label: 'Subscriptions', href: '/subscriptions', badge: null },
  { icon: DollarSign, label: 'Payments', href: '/payments', badge: null },
  { icon: Activity, label: 'Activity', href: '/activity', badge: null },
  { icon: Settings, label: 'Plans', href: '/subscription-plans', badge: null },
]

interface ResponsiveSidebarProps {
  isCollapsed?: boolean
  onToggle?: () => void
}

export default function ResponsiveSidebar({ isCollapsed = false, onToggle }: ResponsiveSidebarProps) {
  const pathname = usePathname()
  const [isMobileOpen, setIsMobileOpen] = useState(false)
  const [isAnimating, setIsAnimating] = useState(false)
  const screenWidth = useScreenWidth()

  const isMobile = screenWidth < 768
  const isTablet = screenWidth >= 768 && screenWidth < 1024

  // Auto-collapse on tablet, manual toggle on desktop
  const shouldShowCollapsed = isMobile ? false : (isTablet ? true : isCollapsed)

  // Add smooth animation for mobile sidebar
  useEffect(() => {
    if (isMobileOpen) {
      setIsAnimating(true)
    }
  }, [isMobileOpen])

  const handleToggle = () => {
    if (isMobile) {
      setIsMobileOpen(!isMobileOpen)
    } else if (onToggle) {
      onToggle()
    }
  }

  const sidebarContent = (
    <div className={`flex flex-col h-full bg-white dark:bg-slate-900/95 backdrop-blur-sm border-r border-gray-200/50 dark:border-slate-700/50 ${
      isMobile
        ? `fixed inset-y-0 left-0 z-50 w-64 transform transition-all duration-300 ease-in-out ${
            isMobileOpen ? 'translate-x-0' : '-translate-x-full'
          }`
        : `fixed inset-y-0 left-0 z-40 transition-all duration-300 ease-in-out ${
            shouldShowCollapsed ? 'w-20' : 'w-64'
          }`
    }`}>
      {/* Header */}
      <div className="flex items-center justify-between p-4 border-b border-gray-200/50 dark:border-slate-700/50">
        <div className={`transition-all duration-300 ease-in-out ${
          shouldShowCollapsed ? 'opacity-0 w-0 overflow-hidden' : 'opacity-100'
        }`}>
          <h2 className="text-lg font-semibold text-gray-900 dark:text-white">Ruwaq Jawi</h2>
          <p className="text-xs text-gray-600 dark:text-gray-400">Admin Panel</p>
        </div>

        <button
          onClick={handleToggle}
          className="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-slate-800 transition-colors"
          aria-label={isMobile ? 'Close sidebar' : shouldShowCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}
        >
          {isMobile ? (
            <X className="w-5 h-5 text-gray-600 dark:text-gray-400" />
          ) : shouldShowCollapsed ? (
            <ChevronRight className="w-5 h-5 text-gray-600 dark:text-gray-400" />
          ) : (
            <ChevronLeft className="w-5 h-5 text-gray-600 dark:text-gray-400" />
          )}
        </button>
      </div>

      {/* Navigation */}
      <nav className="flex-1 overflow-y-auto p-4">
        <div className="space-y-2">
          {navItems.map((item) => {
            const Icon = item.icon
            const isActive = pathname === item.href

            return (
              <Link
                key={item.href}
                href={item.href}
                onClick={() => {
                  if (isMobile) {
                    setIsMobileOpen(false)
                  }
                }}
                className={`flex items-center gap-3 px-3 py-2.5 rounded-lg transition-all duration-200 ease-in-out ${
                  isActive
                    ? 'text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-500/10'
                    : 'text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-300 hover:bg-gray-100 dark:hover:bg-slate-800/50'
                } ${shouldShowCollapsed ? 'justify-center' : ''}`}
                title={shouldShowCollapsed ? item.label : undefined}
              >
                <Icon className="w-5 h-5 flex-shrink-0 transition-transform duration-200 hover:scale-110" />
                <span className={`text-sm font-medium truncate transition-all duration-300 ease-in-out ${
                  shouldShowCollapsed ? 'opacity-0 w-0 overflow-hidden' : 'opacity-100'
                }`}>{item.label}</span>
                {shouldShowCollapsed && isActive && (
                  <div className="absolute left-1/2 transform -translate-x-1/2 w-0.5 h-6 bg-blue-600 dark:bg-blue-400 rounded-full" />
                )}
              </Link>
            )
          })}
        </div>
      </nav>

      {/* Footer */}
      <div className={`p-4 border-t border-gray-200/50 dark:border-slate-700/50 transition-all duration-300 ease-in-out ${
        shouldShowCollapsed ? 'opacity-0 h-0 overflow-hidden' : 'opacity-100'
      }`}>
        <div className="text-xs text-gray-500 dark:text-gray-400 text-center">
          © 2024 Ruwaq Jawi
        </div>
      </div>
    </div>
  )

  return (
    <>
      {/* Desktop sidebar - Fixed */}
      {!isMobile && sidebarContent}

      {/* Mobile sidebar with overlay */}
      {isMobile && (
        <>
          {/* Mobile menu button */}
          <button
            onClick={() => setIsMobileOpen(true)}
            className="fixed top-4 left-4 z-30 p-2 bg-white dark:bg-slate-800 rounded-lg shadow-md border border-gray-200 dark:border-slate-700"
            aria-label="Open sidebar"
          >
            <Menu className="w-5 h-5 text-gray-600 dark:text-gray-400" />
          </button>

          {/* Mobile sidebar */}
          {isMobileOpen && (
            <>
              {/* Overlay */}
              <div
                className="fixed inset-0 bg-black/50 backdrop-blur-sm z-40"
                onClick={() => setIsMobileOpen(false)}
              />

              {/* Sidebar */}
              {sidebarContent}
            </>
          )}
        </>
      )}
    </>
  )
}
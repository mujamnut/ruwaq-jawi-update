'use client'

import { useState, useEffect, memo } from 'react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { useAuth } from '@/contexts/auth-context'
import {
  LayoutDashboard,
  BookOpen,
  Video,
  Tag,
  Users,
  Shield,
  Settings,
  Activity,
  Search,
  CreditCard,
  DollarSign,
  Star,
  Bell
} from 'lucide-react'

interface SidebarProps {
  isCollapsed: boolean
  onToggle: () => void
}

const menuItems = [
  {
    section: 'dashboard',
    icon: LayoutDashboard,
    label: 'Dashboard',
    description: 'Insights & KPIs',
    href: '/'
  },
  {
    section: 'search',
    icon: Search,
    label: 'Search',
    description: 'Advanced search',
    href: '/search'
  },
  {
    section: 'content',
    icon: BookOpen,
    label: 'Ebooks',
    description: 'Manage books',
    href: '/books'
  },
  {
    section: 'videos',
    icon: Video,
    label: 'Videos',
    description: 'Manage videos',
    href: '/videos'
  },
  {
    section: 'categories',
    icon: Tag,
    label: 'Categories',
    description: 'Content categories',
    href: '/categories'
  },
  {
    section: 'users',
    icon: Users,
    label: 'Students',
    description: 'Student accounts',
    href: '/users'
  },
  {
    section: 'admin-users',
    icon: Shield,
    label: 'Admin Users',
    description: 'Admin accounts',
    href: '/admin-users'
  },
  {
    section: 'activity',
    icon: Activity,
    label: 'Activity Logs',
    description: 'Admin actions',
    href: '/activity'
  },
  {
    section: 'notifications',
    icon: Bell,
    label: 'Notifications',
    description: 'System notifications',
    href: '/notifications'
  },
  {
    section: 'subscriptions',
    icon: CreditCard,
    label: 'Subscriptions',
    description: 'User subscriptions',
    href: '/subscriptions'
  },
  {
    section: 'subscription-plans',
    icon: Star,
    label: 'Subscription Plans',
    description: 'Plan management',
    href: '/subscription-plans'
  },
  {
    section: 'payments',
    icon: DollarSign,
    label: 'Payments',
    description: 'Payment transactions',
    href: '/payments'
  }
]

function Sidebar({ isCollapsed, onToggle }: SidebarProps) {
  const pathname = usePathname()
  const { user } = useAuth()

  // Calculate initial active section based on current pathname
  const getInitialActiveSection = () => {
    if (pathname) {
      return menuItems.find(item => item.href === pathname)?.section || 'dashboard'
    }
    return 'dashboard'
  }

  const [activeSection, setActiveSection] = useState(getInitialActiveSection())

  // Auto-detect active section based on current pathname
  useEffect(() => {
    const currentSection = getInitialActiveSection()
    setActiveSection(currentSection)
  }, [pathname])

  return (
    <aside data-collapsed={isCollapsed} className={`
      fixed z-30 inset-y-0 left-0 h-screen bg-white dark:bg-slate-900 border-r border-gray-200 dark:border-slate-700 shadow-lg
      flex flex-col group hover:shadow-xl
      transition-all duration-300 ease-in-out overflow-hidden
      ${isCollapsed ? 'w-16 lg:w-20 hover:w-64' : 'w-56 lg:w-64'}
    `}>
      {/* Logo */}
      <div className="flex items-center gap-3 px-6 pt-5 pb-4 border-b border-gray-200 dark:border-slate-700">
        <div className={`h-9 w-9 rounded-2xl bg-gradient-to-tr from-blue-600 to-indigo-600 flex items-center justify-center shadow-lg flex-shrink-0`}>
          <span className="font-bold text-lg text-white">R</span>
        </div>
        <div className={`flex flex-col transition-all duration-300 ease-in-out overflow-hidden ${isCollapsed ? 'w-0 opacity-0 group-hover:w-auto group-hover:opacity-100' : 'w-auto opacity-100'}`}>
          <span className="text-sm font-semibold tracking-wide text-gray-900 dark:text-white whitespace-nowrap">
            Ruwaq Jawi
          </span>
          <span className="text-[11px] uppercase tracking-[.18em] text-gray-500 dark:text-gray-400 whitespace-nowrap">
            Admin Console
          </span>
        </div>
      </div>

      {/* Nav */}
      <nav className="flex-1 overflow-y-auto no-scrollbar px-3 py-4 space-y-4 text-sm">
        <div>
          <div className="space-y-1">
            {menuItems.map((item) => {
              const Icon = item.icon
              const isActive = activeSection === item.section

              return (
                <Link
                  key={item.section}
                  href={item.href}
                  prefetch={isActive ? false : true}
                  className={`
                    sidebar-link flex w-full items-center gap-2 px-2 py-2 h-10 rounded-xl transition-all
                    focus:outline-none text-left
                    ${isActive
                      ? 'bg-gray-100 dark:bg-slate-800 border border-gray-300 dark:border-slate-600'
                      : 'text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-slate-800 hover:text-gray-900 dark:hover:text-white'
                    }
                  `}
                  aria-label={`${item.label} - ${item.description}`}
                  aria-current={isActive ? 'page' : undefined}
                  >
                  <Icon
                      size={20}
                      className={isActive ? "text-gray-900 dark:text-white" : "text-gray-600 dark:text-gray-400"}
                    />
                  <div className={`flex flex-col transition-all duration-300 ease-in-out overflow-hidden ${isCollapsed ? 'w-0 opacity-0 group-hover:w-auto group-hover:opacity-100' : 'w-auto opacity-100'}`}>
                    <span className="font-medium text-[13px] text-gray-900 dark:text-white whitespace-nowrap">
                      {item.label}
                    </span>
                  </div>
                </Link>
              )
            })}
          </div>
        </div>
      </nav>

          </aside>
  )
}

export default memo(Sidebar)
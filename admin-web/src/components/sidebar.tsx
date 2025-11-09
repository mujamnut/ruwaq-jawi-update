'use client'

import { useState } from 'react'
import Link from 'next/link'
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
  Menu,
  Plus,
  LogOut,
  Search
} from 'lucide-react'

interface SidebarProps {
  isCollapsed: boolean
  onToggle: () => void
}

export default function Sidebar({ isCollapsed, onToggle }: SidebarProps) {
  const [activeSection, setActiveSection] = useState('dashboard')
  const { user, logout } = useAuth()

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
      label: 'Video Kitab',
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
      section: 'settings',
      icon: Settings,
      label: 'Settings',
      description: 'System settings',
      href: '/settings'
    }
  ]

  return (
    <aside className={`
      fixed z-30 inset-y-0 left-0 bg-slate-950/95 border-r border-slate-800/80 backdrop-blur-xl
      flex flex-col transition-all duration-300 ease-out lg:translate-x-0 -translate-x-full lg:static
      ${isCollapsed ? 'lg:w-20 w-72' : 'lg:w-72 w-72'}
    `}>
      {/* Logo */}
      <div className="flex items-center gap-3 px-6 pt-5 pb-4 border-b border-slate-800/80">
        <div className="h-9 w-9 rounded-2xl bg-gradient-to-tr from-green-500 via-blue-500 to-indigo-500 flex items-center justify-center shadow-lg shadow-green-500/40">
          <span className="font-bold text-lg">R</span>
        </div>
        {!isCollapsed && (
          <div className="flex flex-col">
            <span className="text-sm font-semibold tracking-wide gradient-text">Ruwaq Jawi</span>
            <span className="text-[11px] uppercase tracking-[.18em] text-slate-400">Admin Console</span>
          </div>
        )}
      </div>

      {/* Nav */}
      <nav className="flex-1 overflow-y-auto no-scrollbar px-3 py-4 space-y-4 text-sm">
        <div>
          {!isCollapsed && (
            <p className="px-3 mb-2 text-[11px] font-medium tracking-[.18em] uppercase text-slate-500">Main Menu</p>
          )}
          <div className="space-y-1">
            {menuItems.map((item) => {
              const Icon = item.icon
              const isActive = activeSection === item.section

              return (
                <Link
                  key={item.section}
                  href={item.href}
                  onClick={() => setActiveSection(item.section)}
                  className={`
                    flex w-full items-center gap-3 px-3 py-2.5 rounded-xl transition-all
                    ${isActive
                      ? 'text-slate-100 bg-slate-900/80 border border-slate-700 shadow-sm shadow-blue-500/20'
                      : 'text-slate-300 hover:bg-slate-900/70 hover:text-slate-50'
                    }
                  `}
                >
                  <span className={`
                    inline-flex items-center justify-center w-8 h-8 rounded-xl text-xs flex-shrink-0
                    ${isActive
                      ? 'bg-gradient-to-br from-green-500 to-blue-500'
                      : 'bg-slate-900 border border-slate-700/80'
                    }
                  `}>
                    <Icon className="w-4 h-4" />
                  </span>
                  {!isCollapsed && (
                    <div className="flex flex-col items-start">
                      <span className="font-medium text-[13px]">{item.label}</span>
                      <span className="text-[11px] text-slate-400">{item.description}</span>
                    </div>
                  )}
                </Link>
              )
            })}
          </div>
        </div>
      </nav>

      {/* Bottom user section */}
      <div className="border-t border-slate-800/80 px-4 py-4 flex items-center justify-between gap-3">
        {!isCollapsed ? (
          <>
            <div className="flex items-center gap-3">
              <div className="relative">
                <div className="w-9 h-9 rounded-2xl bg-gradient-to-tr from-blue-500 via-indigo-500 to-emerald-400 flex items-center justify-center text-xs font-semibold">
                  {user?.name?.charAt(0)?.toUpperCase() || 'A'}
                </div>
                <span className="absolute -bottom-0.5 -right-0.5 w-3 h-3 rounded-full bg-emerald-400 ring-2 ring-slate-950/95"></span>
              </div>
              <div className="flex flex-col">
                <span className="text-xs font-medium">{user?.name || 'Admin User'}</span>
                <span className="text-[11px] text-slate-400">{user?.email || 'admin@ruwaq.app'}</span>
              </div>
            </div>
            <button
              onClick={logout}
              className="p-2 rounded-xl bg-slate-900/90 hover:bg-slate-800/90 border border-slate-700/80 transition"
              title="Logout"
            >
              <LogOut className="w-4 h-4 text-slate-300" />
            </button>
          </>
        ) : (
          <button
            onClick={logout}
            className="p-2 rounded-xl bg-slate-900/90 hover:bg-slate-800/90 border border-slate-700/80 transition mx-auto"
            title="Logout"
          >
            <LogOut className="w-4 h-4 text-slate-300" />
          </button>
        )}
      </div>
    </aside>
  )
}
'use client'

import { usePathname } from 'next/navigation'
import Link from 'next/link'
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
  Settings
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

export default function BottomNav() {
  const pathname = usePathname()

  return (
    <nav className="fixed bottom-0 left-0 right-0 h-16 bg-white dark:bg-slate-900/95 backdrop-blur-sm border-t border-gray-200/50 dark:border-slate-700/50 flex items-center justify-center overflow-x-auto transition-colors duration-300 z-40">
      <div className="flex items-center justify-between gap-1 px-2 w-full max-w-full">
        {navItems.map((item) => {
          const Icon = item.icon
          const isActive = pathname === item.href
          
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex flex-col items-center justify-center gap-0.5 px-3 py-2 rounded-lg transition-all min-h-14 min-w-[50px] flex-shrink-0 ${
                isActive
                  ? 'text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-500/10'
                  : 'text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-300 hover:bg-gray-100 dark:hover:bg-slate-800/50'
              }`}
              title={item.label}
            >
              <Icon className="w-5 h-5" />
              <span className="text-xs font-medium truncate">{item.label}</span>
            </Link>
          )
        })}
      </div>
    </nav>
  )
}

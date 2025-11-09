'use client'

import { useState } from 'react'
import {
  Search,
  Bell,
  Plus,
  Menu
} from 'lucide-react'

interface HeaderProps {
  onMenuToggle: () => void
  title: string
  subtitle: string
}

export default function Header({ onMenuToggle, title, subtitle }: HeaderProps) {
  const [searchValue, setSearchValue] = useState('')

  return (
    <header className="sticky top-0 z-20 glass border-b border-slate-800/80">
      <div className="flex items-center justify-between px-4 sm:px-6 py-3 gap-3">
        {/* Left */}
        <div className="flex items-center gap-3">
          <button
            onClick={onMenuToggle}
            className="lg:hidden p-2 rounded-xl bg-slate-900/90 border border-slate-700/80 text-slate-200"
          >
            <Menu className="w-4 h-4" />
          </button>
          <div className="flex flex-col">
            <span className="text-xs uppercase tracking-[.18em] text-slate-400">{subtitle}</span>
            <h1 className="text-sm sm:text-base font-semibold">{title}</h1>
          </div>
        </div>

        {/* Center search */}
        <div className="flex-1 max-w-xl hidden md:flex items-center px-3 py-1.5 rounded-full border border-slate-700/80 bg-slate-900/80 shadow-sm shadow-slate-900/60">
          <Search className="w-4 h-4 text-slate-400 mr-2" />
          <input
            type="text"
            placeholder="Search content, tags..."
            value={searchValue}
            onChange={(e) => setSearchValue(e.target.value)}
            className="w-full bg-transparent border-0 focus:ring-0 text-xs text-slate-100 placeholder:text-slate-500"
          />
          <div className="flex items-center gap-1 text-[10px] text-slate-400">
            <span className="px-1.5 py-0.5 rounded bg-slate-800 border border-slate-700">Ctrl</span>
            <span>+</span>
            <span className="px-1.5 py-0.5 rounded bg-slate-800 border border-slate-700">K</span>
          </div>
        </div>

        {/* Right */}
        <div className="flex items-center gap-2">
          <button className="relative p-2 rounded-xl bg-slate-900/80 border border-slate-700/80 hover:bg-slate-800/90 transition">
            <Bell className="w-4 h-4 text-slate-300" />
            <span className="absolute -top-0.5 -right-0.5 w-3 h-3 rounded-full bg-rose-500 border-2 border-slate-950/90"></span>
          </button>
          <button className="hidden sm:inline-flex items-center gap-2 px-3 py-1.5 rounded-xl btn-primary text-xs font-medium shadow-lg shadow-blue-500/30">
            <Plus className="w-3.5 h-3.5" />
            New Content
          </button>
        </div>
      </div>
    </header>
  )
}
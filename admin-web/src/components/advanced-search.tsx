'use client'

import { useState, useEffect } from 'react'
import { Search, Filter, X, Calendar, Tag, User, Clock } from 'lucide-react'

interface SearchFilters {
  query: string
  type: 'all' | 'book' | 'video' | 'category' | 'user'
  status: 'all' | 'active' | 'inactive' | 'published' | 'draft'
  category: string
  dateRange: 'all' | 'today' | 'week' | 'month' | 'year'
  sortBy: 'relevance' | 'date' | 'name' | 'views' | 'rating'
  sortOrder: 'asc' | 'desc'
}

interface AdvancedSearchProps {
  onSearch: (filters: SearchFilters) => void
  placeholder?: string
  showFilters?: boolean
  className?: string
}

export default function AdvancedSearch({
  onSearch,
  placeholder = "Search content...",
  showFilters = true,
  className = ""
}: AdvancedSearchProps) {
  const [filters, setFilters] = useState<SearchFilters>({
    query: '',
    type: 'all',
    status: 'all',
    category: '',
    dateRange: 'all',
    sortBy: 'relevance',
    sortOrder: 'desc'
  })

  const [isFilterOpen, setIsFilterOpen] = useState(false)
  const [categories, setCategories] = useState<string[]>([])

  useEffect(() => {
    // Fetch categories for filter dropdown
    const fetchCategories = async () => {
      try {
        const response = await fetch('/api/categories')
        if (response.ok) {
          const data = await response.json()
          setCategories(data.map((cat: any) => cat.name))
        }
      } catch (error) {
        console.error('Error fetching categories:', error)
      }
    }
    fetchCategories()
  }, [])

  const handleSearch = () => {
    onSearch(filters)
  }

  const handleReset = () => {
    setFilters({
      query: '',
      type: 'all',
      status: 'all',
      category: '',
      dateRange: 'all',
      sortBy: 'relevance',
      sortOrder: 'desc'
    })
    onSearch({
      query: '',
      type: 'all',
      status: 'all',
      category: '',
      dateRange: 'all',
      sortBy: 'relevance',
      sortOrder: 'desc'
    })
  }

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleSearch()
    }
  }

  const hasActiveFilters = filters.type !== 'all' ||
                          filters.status !== 'all' ||
                          filters.category !== '' ||
                          filters.dateRange !== 'all' ||
                          filters.sortBy !== 'relevance' ||
                          filters.sortOrder !== 'desc'

  return (
    <div className={`w-full ${className}`}>
      {/* Main Search Bar */}
      <div className="relative">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-slate-400 w-4 h-4" />
          <input
            type="text"
            value={filters.query}
            onChange={(e) => setFilters(prev => ({ ...prev, query: e.target.value }))}
            onKeyPress={handleKeyPress}
            placeholder={placeholder}
            className="w-full pl-10 pr-24 py-3 rounded-xl bg-slate-900/80 border border-slate-700/80 text-sm text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
          />
          <div className="absolute right-2 top-1/2 transform -translate-y-1/2 flex items-center gap-1">
            {filters.query && (
              <button
                onClick={() => setFilters(prev => ({ ...prev, query: '' }))}
                className="p-1.5 rounded-lg hover:bg-slate-800/90 text-slate-400 hover:text-slate-200"
              >
                <X className="w-3.5 h-3.5" />
              </button>
            )}
            {showFilters && (
              <button
                onClick={() => setIsFilterOpen(!isFilterOpen)}
                className={`p-1.5 rounded-lg transition-colors ${
                  hasActiveFilters
                    ? 'bg-blue-600/20 border border-blue-500/40 text-blue-300'
                    : 'hover:bg-slate-800/90 text-slate-400 hover:text-slate-200'
                }`}
              >
                <Filter className="w-3.5 h-3.5" />
              </button>
            )}
            <button
              onClick={handleSearch}
              className="px-3 py-1.5 rounded-lg bg-blue-600 hover:bg-blue-700 text-white text-xs font-medium transition-colors"
            >
              Search
            </button>
          </div>
        </div>
      </div>

      {/* Advanced Filters Panel */}
      {showFilters && isFilterOpen && (
        <div className="mt-4 p-4 rounded-xl bg-slate-900/80 border border-slate-700/80">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-sm font-semibold text-slate-200">Advanced Filters</h3>
            <button
              onClick={handleReset}
              className="text-xs text-slate-400 hover:text-slate-200 transition-colors"
            >
              Reset all
            </button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            {/* Content Type Filter */}
            <div>
              <label className="block text-xs font-medium text-slate-300 mb-2">
                Content Type
              </label>
              <select
                value={filters.type}
                onChange={(e) => setFilters(prev => ({ ...prev, type: e.target.value as any }))}
                className="w-full px-3 py-2 rounded-lg bg-slate-800/80 border border-slate-600/60 text-xs text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
              >
                <option value="all">All Types</option>
                <option value="book">Books</option>
                <option value="video">Videos</option>
                <option value="category">Categories</option>
                <option value="user">Users</option>
              </select>
            </div>

            {/* Status Filter */}
            <div>
              <label className="block text-xs font-medium text-slate-300 mb-2">
                Status
              </label>
              <select
                value={filters.status}
                onChange={(e) => setFilters(prev => ({ ...prev, status: e.target.value as any }))}
                className="w-full px-3 py-2 rounded-lg bg-slate-800/80 border border-slate-600/60 text-xs text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
              >
                <option value="all">All Status</option>
                <option value="active">Active</option>
                <option value="inactive">Inactive</option>
                <option value="published">Published</option>
                <option value="draft">Draft</option>
              </select>
            </div>

            {/* Category Filter */}
            <div>
              <label className="block text-xs font-medium text-slate-300 mb-2">
                Category
              </label>
              <select
                value={filters.category}
                onChange={(e) => setFilters(prev => ({ ...prev, category: e.target.value }))}
                className="w-full px-3 py-2 rounded-lg bg-slate-800/80 border border-slate-600/60 text-xs text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
              >
                <option value="">All Categories</option>
                {categories.map((category) => (
                  <option key={category} value={category}>
                    {category}
                  </option>
                ))}
              </select>
            </div>

            {/* Date Range Filter */}
            <div>
              <label className="block text-xs font-medium text-slate-300 mb-2">
                Date Range
              </label>
              <select
                value={filters.dateRange}
                onChange={(e) => setFilters(prev => ({ ...prev, dateRange: e.target.value as any }))}
                className="w-full px-3 py-2 rounded-lg bg-slate-800/80 border border-slate-600/60 text-xs text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
              >
                <option value="all">All Time</option>
                <option value="today">Today</option>
                <option value="week">This Week</option>
                <option value="month">This Month</option>
                <option value="year">This Year</option>
              </select>
            </div>

            {/* Sort By Filter */}
            <div>
              <label className="block text-xs font-medium text-slate-300 mb-2">
                Sort By
              </label>
              <select
                value={filters.sortBy}
                onChange={(e) => setFilters(prev => ({ ...prev, sortBy: e.target.value as any }))}
                className="w-full px-3 py-2 rounded-lg bg-slate-800/80 border border-slate-600/60 text-xs text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
              >
                <option value="relevance">Relevance</option>
                <option value="date">Date</option>
                <option value="name">Name</option>
                <option value="views">Views</option>
                <option value="rating">Rating</option>
              </select>
            </div>

            {/* Sort Order Filter */}
            <div>
              <label className="block text-xs font-medium text-slate-300 mb-2">
                Sort Order
              </label>
              <select
                value={filters.sortOrder}
                onChange={(e) => setFilters(prev => ({ ...prev, sortOrder: e.target.value as any }))}
                className="w-full px-3 py-2 rounded-lg bg-slate-800/80 border border-slate-600/60 text-xs text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
              >
                <option value="desc">Descending</option>
                <option value="asc">Ascending</option>
              </select>
            </div>
          </div>

          {/* Active Filter Tags */}
          {hasActiveFilters && (
            <div className="mt-4 pt-4 border-t border-slate-700/60">
              <div className="flex flex-wrap gap-2">
                {filters.type !== 'all' && (
                  <div className="inline-flex items-center gap-1 px-2 py-1 rounded-full bg-blue-500/10 border border-blue-500/40 text-xs text-blue-300">
                    <Tag className="w-3 h-3" />
                    Type: {filters.type}
                    <button
                      onClick={() => setFilters(prev => ({ ...prev, type: 'all' }))}
                      className="ml-1 hover:text-blue-200"
                    >
                      <X className="w-3 h-3" />
                    </button>
                  </div>
                )}
                {filters.status !== 'all' && (
                  <div className="inline-flex items-center gap-1 px-2 py-1 rounded-full bg-emerald-500/10 border border-emerald-500/40 text-xs text-emerald-300">
                    <Clock className="w-3 h-3" />
                    Status: {filters.status}
                    <button
                      onClick={() => setFilters(prev => ({ ...prev, status: 'all' }))}
                      className="ml-1 hover:text-emerald-200"
                    >
                      <X className="w-3 h-3" />
                    </button>
                  </div>
                )}
                {filters.category && (
                  <div className="inline-flex items-center gap-1 px-2 py-1 rounded-full bg-purple-500/10 border border-purple-500/40 text-xs text-purple-300">
                    <Tag className="w-3 h-3" />
                    {filters.category}
                    <button
                      onClick={() => setFilters(prev => ({ ...prev, category: '' }))}
                      className="ml-1 hover:text-purple-200"
                    >
                      <X className="w-3 h-3" />
                    </button>
                  </div>
                )}
                {filters.dateRange !== 'all' && (
                  <div className="inline-flex items-center gap-1 px-2 py-1 rounded-full bg-amber-500/10 border border-amber-500/40 text-xs text-amber-300">
                    <Calendar className="w-3 h-3" />
                    {filters.dateRange}
                    <button
                      onClick={() => setFilters(prev => ({ ...prev, dateRange: 'all' }))}
                      className="ml-1 hover:text-amber-200"
                    >
                      <X className="w-3 h-3" />
                    </button>
                  </div>
                )}
              </div>
            </div>
          )}
        </div>
      )}

      {/* Quick Search Suggestions */}
      {filters.query && (
        <div className="mt-2 text-xs text-slate-400">
          Press Enter to search or click the Search button
        </div>
      )}
    </div>
  )
}
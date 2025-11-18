'use client'

import { useState, useEffect } from 'react'
import {
  Filter,
  Calendar,
  Users,
  BookOpen,
  Video,
  CreditCard,
  DollarSign,
  TrendingUp,
  TrendingDown,
  X,
  Check,
  ChevronDown,
  RotateCw
} from 'lucide-react'

export interface FilterOptions {
  dateRange: {
    start: string
    end: string
    preset?: '7d' | '30d' | '90d' | '1y' | 'custom'
  }
  categories: string[]
  contentType: 'all' | 'books' | 'videos' | 'both'
  status: 'all' | 'active' | 'inactive' | 'premium' | 'free'
  performance: 'all' | 'high' | 'medium' | 'low'
  sortBy: 'date' | 'views' | 'revenue' | 'rating' | 'name'
  sortOrder: 'asc' | 'desc'
  searchTerm?: string
}

interface AdvancedFilterProps {
  onFiltersChange: (filters: FilterOptions) => void
  onReset: () => void
  initialFilters?: Partial<FilterOptions>
  availableCategories?: Array<{ id: string; name: string }>
  isLoading?: boolean
}

const defaultFilters: FilterOptions = {
  dateRange: {
    start: '',
    end: '',
    preset: '30d'
  },
  categories: [],
  contentType: 'all',
  status: 'all',
  performance: 'all',
  sortBy: 'date',
  sortOrder: 'desc',
  searchTerm: ''
}

export default function AdvancedFilter({
  onFiltersChange,
  onReset,
  initialFilters = {},
  availableCategories = [],
  isLoading = false
}: AdvancedFilterProps) {
  const [filters, setFilters] = useState<FilterOptions>({
    ...defaultFilters,
    ...initialFilters
  })
  const [isExpanded, setIsExpanded] = useState(false)
  const [showDateCalendar, setShowDateCalendar] = useState(false)

  useEffect(() => {
    // Set default date range based on preset
    if (filters.dateRange.preset && !filters.dateRange.start && !filters.dateRange.end) {
      const endDate = new Date()
      let startDate = new Date()

      switch (filters.dateRange.preset) {
        case '7d':
          startDate.setDate(startDate.getDate() - 7)
          break
        case '30d':
          startDate.setDate(startDate.getDate() - 30)
          break
        case '90d':
          startDate.setDate(startDate.getDate() - 90)
          break
        case '1y':
          startDate.setFullYear(startDate.getFullYear() - 1)
          break
      }

      setFilters(prev => ({
        ...prev,
        dateRange: {
          ...prev.dateRange,
          start: startDate.toISOString().split('T')[0],
          end: endDate.toISOString().split('T')[0]
        }
      }))
    }
  }, [filters.dateRange.preset])

  const updateFilters = (newFilters: Partial<FilterOptions>) => {
    const updated = { ...filters, ...newFilters }
    setFilters(updated)
    onFiltersChange(updated)
  }

  const handleDatePresetChange = (preset: FilterOptions['dateRange']['preset']) => {
    const endDate = new Date()
    let startDate = new Date()

    if (preset !== 'custom') {
      switch (preset) {
        case '7d':
          startDate.setDate(startDate.getDate() - 7)
          break
        case '30d':
          startDate.setDate(startDate.getDate() - 30)
          break
        case '90d':
          startDate.setDate(startDate.getDate() - 90)
          break
        case '1y':
          startDate.setFullYear(startDate.getFullYear() - 1)
          break
      }

      updateFilters({
        dateRange: {
          preset,
          start: startDate.toISOString().split('T')[0],
          end: endDate.toISOString().split('T')[0]
        }
      })
    } else {
      updateFilters({
        dateRange: {
          preset: 'custom',
          start: '',
          end: ''
        }
      })
      setShowDateCalendar(true)
    }
  }

  const toggleCategory = (categoryId: string) => {
    const newCategories = filters.categories.includes(categoryId)
      ? filters.categories.filter(id => id !== categoryId)
      : [...filters.categories, categoryId]

    updateFilters({ categories: newCategories })
  }

  const toggleAllCategories = () => {
    if (filters.categories.length === availableCategories.length) {
      updateFilters({ categories: [] })
    } else {
      updateFilters({
        categories: availableCategories.map(cat => cat.id)
      })
    }
  }

  const getActiveFiltersCount = () => {
    let count = 0
    if (filters.categories.length > 0) count++
    if (filters.contentType !== 'all') count++
    if (filters.status !== 'all') count++
    if (filters.performance !== 'all') count++
    if (filters.sortBy !== 'date' || filters.sortOrder !== 'desc') count++
    if (filters.searchTerm) count++
    if (filters.dateRange.preset !== '30d') count++
    return count
  }

  return (
    <div className="bg-white border border-gray-300 rounded-lg p-4 mb-6">
      {/* Filter Header */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2">
            <Filter className="w-4 h-4 text-blue-600" />
            <h3 className="text-sm font-semibold text-gray-900">Advanced Filters</h3>
          </div>
          {getActiveFiltersCount() > 0 && (
            <span className="px-2 py-1 bg-blue-100 text-blue-700 text-xs rounded-full border border-blue-300">
              {getActiveFiltersCount()} active
            </span>
          )}
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => setIsExpanded(!isExpanded)}
            className="flex items-center gap-1 px-3 py-1.5 rounded-md bg-gray-100 hover:bg-gray-200 transition text-xs text-gray-700"
          >
            {isExpanded ? 'Hide' : 'Show'} Filters
            <ChevronDown className={`w-4 h-4 transition-transform ${isExpanded ? 'rotate-180' : ''}`} />
          </button>
          <button
            onClick={() => {
              onReset()
              setFilters(defaultFilters)
            }}
            className="flex items-center gap-1 px-3 py-1.5 rounded-md bg-gray-100 hover:bg-gray-200 transition text-xs text-gray-700"
          >
            <RotateCw className="w-4 h-4" />
            Reset
          </button>
        </div>
      </div>

      {/* Quick Filters - Always Visible */}
      <div className="flex flex-wrap gap-2 mb-4">
        {/* Date Range Presets */}
        <div className="flex items-center gap-1">
          <Calendar className="w-3 h-3 text-gray-600" />
          <div className="flex gap-1">
            {[
              { key: '7d', label: '7D' },
              { key: '30d', label: '30D' },
              { key: '90d', label: '90D' },
              { key: '1y', label: '1Y' },
              { key: 'custom', label: 'Custom' }
            ].map((preset) => (
              <button
                key={preset.key}
                onClick={() => handleDatePresetChange(preset.key as FilterOptions['dateRange']['preset'])}
                className={`px-2 py-1 text-xs rounded-md transition ${
                  filters.dateRange.preset === preset.key
                    ? 'bg-blue-500 text-white'
                    : 'bg-gray-100/50 text-gray-700 hover:bg-gray-100/70'
                }`}
              >
                {preset.label}
              </button>
            ))}
          </div>
        </div>

        {/* Content Type */}
        <div className="flex items-center gap-1">
          <BookOpen className="w-3 h-3 text-gray-600" />
          <select
            value={filters.contentType}
            onChange={(e) => updateFilters({ contentType: e.target.value as FilterOptions['contentType'] })}
            className="px-2 py-1 text-xs rounded-md bg-gray-100/50 border border-gray-300/50 text-gray-700 focus:border-blue-500/50 focus:outline-none"
          >
            <option value="all">All Content</option>
            <option value="books">Books Only</option>
            <option value="videos">Videos Only</option>
          </select>
        </div>

        {/* Status */}
        <div className="flex items-center gap-1">
          <TrendingUp className="w-4 h-4 text-gray-600" />
          <select
            value={filters.status}
            onChange={(e) => updateFilters({ status: e.target.value as FilterOptions['status'] })}
            className="px-2 py-1 text-xs rounded-md bg-gray-100/50 border border-gray-300/50 text-gray-700 focus:border-blue-500/50 focus:outline-none"
          >
            <option value="all">All Status</option>
            <option value="active">Active</option>
            <option value="inactive">Inactive</option>
            <option value="premium">Premium</option>
            <option value="free">Free</option>
          </select>
        </div>

        {/* Performance */}
        <div className="flex items-center gap-1">
          <TrendingDown className="w-4 h-4 text-gray-600" />
          <select
            value={filters.performance}
            onChange={(e) => updateFilters({ performance: e.target.value as FilterOptions['performance'] })}
            className="px-2 py-1 text-xs rounded-md bg-gray-100/50 border border-gray-300/50 text-gray-700 focus:border-blue-500/50 focus:outline-none"
          >
            <option value="all">All Performance</option>
            <option value="high">High</option>
            <option value="medium">Medium</option>
            <option value="low">Low</option>
          </select>
        </div>

        {/* Sort Options */}
        <div className="flex items-center gap-1">
          <Users className="w-3 h-3 text-gray-600" />
          <select
            value={`${filters.sortBy}-${filters.sortOrder}`}
            onChange={(e) => {
              const [sortBy, sortOrder] = e.target.value.split('-')
              updateFilters({
                sortBy: sortBy as FilterOptions['sortBy'],
                sortOrder: sortOrder as FilterOptions['sortOrder']
              })
            }}
            className="px-2 py-1 text-xs rounded-md bg-gray-100/50 border border-gray-300/50 text-gray-700 focus:border-blue-500/50 focus:outline-none"
          >
            <option value="date-desc">Newest First</option>
            <option value="date-asc">Oldest First</option>
            <option value="views-desc">Most Viewed</option>
            <option value="views-asc">Least Viewed</option>
            <option value="revenue-desc">Highest Revenue</option>
            <option value="revenue-asc">Lowest Revenue</option>
            <option value="rating-desc">Highest Rated</option>
            <option value="rating-asc">Lowest Rated</option>
            <option value="name-asc">Name (A-Z)</option>
            <option value="name-desc">Name (Z-A)</option>
          </select>
        </div>
      </div>

      {/* Expanded Filters */}
      {isExpanded && (
        <div className="space-y-4 border-t border-gray-300/50 pt-4">
          {/* Custom Date Range */}
          {filters.dateRange.preset === 'custom' && (
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-xs text-gray-600 mb-1 block">Start Date</label>
                <input
                  type="date"
                  value={filters.dateRange.start}
                  onChange={(e) => updateFilters({
                    dateRange: { ...filters.dateRange, start: e.target.value }
                  })}
                  className="w-full px-3 py-2 text-sm rounded-lg bg-gray-100/50 border border-gray-300/50 text-gray-700 focus:border-blue-500/50 focus:outline-none"
                />
              </div>
              <div>
                <label className="text-xs text-gray-600 mb-1 block">End Date</label>
                <input
                  type="date"
                  value={filters.dateRange.end}
                  onChange={(e) => updateFilters({
                    dateRange: { ...filters.dateRange, end: e.target.value }
                  })}
                  className="w-full px-3 py-2 text-sm rounded-lg bg-gray-100/50 border border-gray-300/50 text-gray-700 focus:border-blue-500/50 focus:outline-none"
                />
              </div>
            </div>
          )}

          {/* Search Term */}
          <div>
            <label className="text-xs text-gray-600 mb-1 block">Search</label>
            <input
              type="text"
              placeholder="Search by title, description, or tags..."
              value={filters.searchTerm}
              onChange={(e) => updateFilters({ searchTerm: e.target.value })}
              className="w-full px-3 py-2 text-sm rounded-lg bg-gray-100/50 border border-gray-300/50 text-gray-700 placeholder:text-gray-500 focus:border-blue-500/50 focus:outline-none"
            />
          </div>

          {/* Categories */}
          {availableCategories.length > 0 && (
            <div>
              <div className="flex items-center justify-between mb-2">
                <label className="text-xs text-gray-600">Categories</label>
                <button
                  onClick={toggleAllCategories}
                  className="text-xs text-blue-400 hover:text-blue-300"
                >
                  {filters.categories.length === availableCategories.length ? 'Deselect All' : 'Select All'}
                </button>
              </div>
              <div className="flex flex-wrap gap-2 max-h-32 overflow-y-auto">
                {availableCategories.map((category) => (
                  <button
                    key={category.id}
                    onClick={() => toggleCategory(category.id)}
                    className={`px-3 py-1.5 text-xs rounded-lg border transition ${
                      filters.categories.includes(category.id)
                        ? 'bg-blue-500/20 text-blue-300 border-blue-500/40'
                        : 'bg-gray-100/50 text-gray-700 border-gray-300/50 hover:bg-gray-100/70'
                    }`}
                  >
                    {category.name}
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* Filter Summary */}
          <div className="bg-gray-100/30 rounded-lg p-3">
            <div className="flex items-center justify-between mb-2">
              <span className="text-xs font-medium text-gray-700">Active Filters Summary</span>
              <button
                onClick={() => {
                  onFiltersChange(filters)
                }}
                className="px-2 py-1 bg-blue-500 text-white text-xs rounded hover:bg-blue-600 transition flex items-center gap-1"
              >
                <Check className="w-3 h-3" />
                Apply
              </button>
            </div>
            <div className="text-xs text-gray-600 space-y-1">
              <div>Date Range: {filters.dateRange.preset === 'custom' ?
                `${filters.dateRange.start || 'Not set'} to ${filters.dateRange.end || 'Not set'}` :
                filters.dateRange.preset?.toUpperCase()}
              </div>
              <div>Content Type: {filters.contentType}</div>
              <div>Status: {filters.status}</div>
              <div>Performance: {filters.performance}</div>
              <div>Sort: {filters.sortBy} ({filters.sortOrder})</div>
              {filters.searchTerm && <div>Search: "{filters.searchTerm}"</div>}
              {filters.categories.length > 0 && (
                <div>Categories: {filters.categories.length} selected</div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
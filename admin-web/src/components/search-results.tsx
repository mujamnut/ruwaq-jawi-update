'use client'

import { useState } from 'react'
import { BookOpen, Video, Tag, Users, Eye, Star, Calendar, Clock, ExternalLink, Search } from 'lucide-react'

interface SearchResult {
  id: string
  type: 'book' | 'video' | 'category' | 'user'
  title: string
  description?: string
  category?: string
  status?: string
  views?: number
  rating?: number
  createdAt: string
  updatedAt: string
  author?: string
  thumbnail?: string
  url?: string
}

interface SearchResultsProps {
  results: SearchResult[]
  loading?: boolean
  query?: string
  totalResults?: number
  currentPage?: number
  totalPages?: number
  onPageChange?: (page: number) => void
  onItemClick?: (item: SearchResult) => void
}

export default function SearchResults({
  results,
  loading = false,
  query = '',
  totalResults = 0,
  currentPage = 1,
  totalPages = 1,
  onPageChange,
  onItemClick
}: SearchResultsProps) {
  const [viewMode, setViewMode] = useState<'grid' | 'list'>('list')

  const getTypeIcon = (type: string) => {
    switch (type) {
      case 'book':
        return <BookOpen className="w-4 h-4 text-emerald-400" />
      case 'video':
        return <Video className="w-4 h-4 text-blue-400" />
      case 'category':
        return <Tag className="w-4 h-4 text-purple-400" />
      case 'user':
        return <Users className="w-4 h-4 text-amber-400" />
      default:
        return <Tag className="w-4 h-4 text-slate-400" />
    }
  }

  const getTypeColor = (type: string) => {
    switch (type) {
      case 'book':
        return 'bg-emerald-500/10 text-emerald-300 border-emerald-500/40'
      case 'video':
        return 'bg-blue-500/10 text-blue-300 border-blue-500/40'
      case 'category':
        return 'bg-purple-500/10 text-purple-300 border-purple-500/40'
      case 'user':
        return 'bg-amber-500/10 text-amber-300 border-amber-500/40'
      default:
        return 'bg-slate-500/10 text-slate-300 border-slate-500/40'
    }
  }

  const getStatusColor = (status?: string) => {
    switch (status) {
      case 'active':
      case 'published':
        return 'bg-emerald-500/10 text-emerald-300 border-emerald-500/40'
      case 'inactive':
      case 'draft':
        return 'bg-rose-500/10 text-rose-300 border-rose-500/40'
      default:
        return 'bg-slate-500/10 text-slate-300 border-slate-500/40'
    }
  }

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric'
    })
  }

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center py-12">
        <div className="w-8 h-8 border-2 border-blue-500 border-t-transparent rounded-full animate-spin mb-4"></div>
        <p className="text-sm text-slate-400">Searching...</p>
      </div>
    )
  }

  if (query && results.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-12">
        <div className="w-16 h-16 rounded-xl bg-slate-900/80 border border-slate-700/80 flex items-center justify-center mb-4">
          <Search className="w-8 h-8 text-slate-400" />
        </div>
        <h3 className="text-lg font-semibold text-slate-200 mb-2">No results found</h3>
        <p className="text-sm text-slate-400 text-center max-w-md">
          No results found for "{query}". Try adjusting your search terms or filters.
        </p>
      </div>
    )
  }

  return (
    <div className="space-y-4">
      {/* Results Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-lg font-semibold text-slate-200">
            {query ? `Search Results for "${query}"` : 'All Content'}
          </h2>
          <p className="text-sm text-slate-400">
            {totalResults.toLocaleString()} {totalResults === 1 ? 'result' : 'results'} found
          </p>
        </div>

        <div className="flex items-center gap-2">
          <span className="text-xs text-slate-400">View:</span>
          <button
            onClick={() => setViewMode('list')}
            className={`p-2 rounded-lg transition-colors ${
              viewMode === 'list'
                ? 'bg-blue-600/20 border border-blue-500/40 text-blue-300'
                : 'hover:bg-slate-800/90 text-slate-400 hover:text-slate-200'
            }`}
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
              <path d="M4 6h16M4 12h16M4 18h16" />
            </svg>
          </button>
          <button
            onClick={() => setViewMode('grid')}
            className={`p-2 rounded-lg transition-colors ${
              viewMode === 'grid'
                ? 'bg-blue-600/20 border border-blue-500/40 text-blue-300'
                : 'hover:bg-slate-800/90 text-slate-400 hover:text-slate-200'
            }`}
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
              <path d="M4 6h16M4 12h16M4 18h7" />
            </svg>
          </button>
        </div>
      </div>

      {/* Results */}
      {viewMode === 'list' ? (
        <div className="space-y-2">
          {results.map((result) => (
            <div
              key={result.id}
              onClick={() => onItemClick?.(result)}
              className="flex items-center gap-4 p-4 rounded-xl bg-slate-900/50 border border-slate-700/50 hover:bg-slate-900/80 hover:border-slate-600/50 transition-all cursor-pointer group"
            >
              {/* Thumbnail */}
              <div className="w-12 h-12 rounded-xl overflow-hidden flex-shrink-0 bg-slate-800/80 border border-slate-700/80">
                {result.thumbnail ? (
                  <img
                    src={result.thumbnail}
                    alt={result.title}
                    className="w-full h-full object-cover"
                  />
                ) : (
                  <div className="w-full h-full flex items-center justify-center">
                    {getTypeIcon(result.type)}
                  </div>
                )}
              </div>

              {/* Content */}
              <div className="flex-1 min-w-0">
                <div className="flex items-start justify-between gap-3">
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      <h3 className="text-sm font-semibold text-slate-200 truncate">
                        {result.title}
                      </h3>
                      <span className={`px-2 py-0.5 rounded-full text-[10px] border ${getTypeColor(result.type)}`}>
                        {result.type}
                      </span>
                      {result.status && (
                        <span className={`px-2 py-0.5 rounded-full text-[10px] border ${getStatusColor(result.status)}`}>
                          {result.status}
                        </span>
                      )}
                    </div>
                    {result.description && (
                      <p className="text-xs text-slate-400 line-clamp-2 mb-2">
                        {result.description}
                      </p>
                    )}
                    <div className="flex items-center gap-4 text-[10px] text-slate-500">
                      {result.category && (
                        <span className="flex items-center gap-1">
                          <Tag className="w-3 h-3" />
                          {result.category}
                        </span>
                      )}
                      {result.author && (
                        <span className="flex items-center gap-1">
                          <Users className="w-3 h-3" />
                          {result.author}
                        </span>
                      )}
                      <span className="flex items-center gap-1">
                        <Calendar className="w-3 h-3" />
                        {formatDate(result.createdAt)}
                      </span>
                    </div>
                  </div>

                  {/* Stats */}
                  <div className="flex items-center gap-3 text-xs">
                    {result.views && (
                      <div className="flex items-center gap-1 text-slate-400">
                        <Eye className="w-3 h-3" />
                        <span>{result.views.toLocaleString()}</span>
                      </div>
                    )}
                    {result.rating && (
                      <div className="flex items-center gap-1 text-amber-400">
                        <Star className="w-3 h-3" />
                        <span>{result.rating}</span>
                      </div>
                    )}
                    <button className="p-1.5 rounded-lg opacity-0 group-hover:opacity-100 transition-opacity hover:bg-slate-800/90 text-slate-400 hover:text-slate-200">
                      <ExternalLink className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          {results.map((result) => (
            <div
              key={result.id}
              onClick={() => onItemClick?.(result)}
              className="p-4 rounded-xl bg-slate-900/50 border border-slate-700/50 hover:bg-slate-900/80 hover:border-slate-600/50 transition-all cursor-pointer group"
            >
              {/* Thumbnail */}
              <div className="w-full h-24 rounded-lg overflow-hidden mb-3 bg-slate-800/80 border border-slate-700/80">
                {result.thumbnail ? (
                  <img
                    src={result.thumbnail}
                    alt={result.title}
                    className="w-full h-full object-cover"
                  />
                ) : (
                  <div className="w-full h-full flex items-center justify-center">
                    {getTypeIcon(result.type)}
                  </div>
                )}
              </div>

              {/* Content */}
              <div className="space-y-2">
                <div className="flex items-center gap-2">
                  <h3 className="text-sm font-semibold text-slate-200 truncate">
                    {result.title}
                  </h3>
                </div>
                {result.description && (
                  <p className="text-xs text-slate-400 line-clamp-2">
                    {result.description}
                  </p>
                )}
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <span className={`px-1.5 py-0.5 rounded-full text-[9px] border ${getTypeColor(result.type)}`}>
                      {result.type}
                    </span>
                    {result.category && (
                      <span className="text-[9px] text-slate-500">
                        {result.category}
                      </span>
                    )}
                  </div>
                  <div className="flex items-center gap-2 text-[10px] text-slate-400">
                    {result.views && (
                      <span className="flex items-center gap-0.5">
                        <Eye className="w-2.5 h-2.5" />
                        {result.views.toLocaleString()}
                      </span>
                    )}
                    {result.rating && (
                      <span className="flex items-center gap-0.5 text-amber-400">
                        <Star className="w-2.5 h-2.5" />
                        {result.rating}
                      </span>
                    )}
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-center gap-2 pt-4">
          <button
            onClick={() => onPageChange?.(currentPage - 1)}
            disabled={currentPage === 1}
            className="px-3 py-1.5 rounded-lg bg-slate-900/80 border border-slate-700/80 text-xs text-slate-300 hover:bg-slate-800/90 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Previous
          </button>

          <div className="flex items-center gap-1">
            {Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
              let pageNum = i + 1
              if (totalPages > 5) {
                if (currentPage <= 3) {
                  pageNum = i + 1
                } else if (currentPage >= totalPages - 2) {
                  pageNum = totalPages - 4 + i
                } else {
                  pageNum = currentPage - 2 + i
                }
              }

              return (
                <button
                  key={pageNum}
                  onClick={() => onPageChange?.(pageNum)}
                  className={`px-3 py-1.5 rounded-lg text-xs transition-colors ${
                    pageNum === currentPage
                      ? 'bg-blue-600 text-white'
                      : 'bg-slate-900/80 border border-slate-700/80 text-slate-300 hover:bg-slate-800/90'
                  }`}
                >
                  {pageNum}
                </button>
              )
            })}
          </div>

          <button
            onClick={() => onPageChange?.(currentPage + 1)}
            disabled={currentPage === totalPages}
            className="px-3 py-1.5 rounded-lg bg-slate-900/80 border border-slate-700/80 text-xs text-slate-300 hover:bg-slate-800/90 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Next
          </button>
        </div>
      )}
    </div>
  )
}
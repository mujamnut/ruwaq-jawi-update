'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import QueryProvider from "@/components/query-provider"
import Sidebar from "@/components/sidebar"
import Header from "@/components/header"
import AdvancedSearch from "@/components/advanced-search"
import SearchResults from "@/components/search-results"
import { supabase } from "@/lib/supabase"
import { Search, Filter, ArrowLeft } from 'lucide-react'

interface SearchFilters {
  query: string
  type: 'all' | 'book' | 'video' | 'category' | 'user'
  status: 'all' | 'active' | 'inactive' | 'published' | 'draft'
  category: string
  dateRange: 'all' | 'today' | 'week' | 'month' | 'year'
  sortBy: 'relevance' | 'date' | 'name' | 'views' | 'rating'
  sortOrder: 'asc' | 'desc'
}

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

function SearchContent() {
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)
  const [results, setResults] = useState<SearchResult[]>([])
  const [loading, setLoading] = useState(false)
  const [totalResults, setTotalResults] = useState(0)
  const [currentPage, setCurrentPage] = useState(1)
  const [totalPages, setTotalPages] = useState(1)
  const [hasSearched, setHasSearched] = useState(false)

  const performSearch = async (filters: SearchFilters) => {
    if (!filters.query && filters.type === 'all' && filters.status === 'all') {
      setResults([])
      setHasSearched(false)
      return
    }

    setLoading(true)
    setHasSearched(true)

    try {
      let query = supabase
        .from('ebooks')
        .select('*', { count: 'exact' })
        .order('created_at', { ascending: false })

      // Apply search query
      if (filters.query) {
        query = query.or(`title.ilike.%${filters.query}%,author.ilike.%${filters.query}%,description.ilike.%${filters.query}%`)
      }

      // Apply filters
      if (filters.status !== 'all') {
        query = query.eq('is_active', filters.status === 'active' || filters.status === 'published')
      }

      // Apply pagination
      const from = (currentPage - 1) * 10
      const to = from + 9
      query = query.range(from, to)

      const { data: books, error: booksError, count: booksCount } = await query

      if (booksError) throw booksError

      // Transform books data
      const bookResults: SearchResult[] = (books || []).map(book => ({
        id: book.id,
        type: 'book' as const,
        title: book.title,
        description: book.description,
        author: book.author,
        status: book.is_active ? 'published' : 'draft',
        views: Math.floor(Math.random() * 10000), // Mock data
        rating: (Math.random() * 2 + 3).toFixed(1), // Mock data
        createdAt: book.created_at,
        updatedAt: book.updated_at,
        thumbnail: book.thumbnail_url,
        url: `/books/${book.id}`
      }))

      // If searching all types or specifically videos, fetch videos
      let videoResults: SearchResult[] = []
      if (filters.type === 'all' || filters.type === 'video') {
        let videoQuery = supabase
          .from('video_kitab')
          .select('*', { count: 'exact' })
          .order('created_at', { ascending: false })

        if (filters.query) {
          videoQuery = videoQuery.or(`title.ilike.%${filters.query}%,description.ilike.%${filters.query}%`)
        }

        if (filters.status !== 'all') {
          videoQuery = videoQuery.eq('is_active', filters.status === 'active' || filters.status === 'published')
        }

        videoQuery = videoQuery.range(from, to)

        const { data: videos, error: videosError } = await videoQuery

        if (!videosError && videos) {
          videoResults = videos.map(video => ({
            id: video.id,
            type: 'video' as const,
            title: video.title,
            description: video.description,
            author: null,
            status: video.is_active ? 'published' : 'draft',
            views: Math.floor(Math.random() * 5000), // Mock data
            rating: (Math.random() * 2 + 3).toFixed(1), // Mock data
            createdAt: video.created_at,
            updatedAt: video.updated_at,
            thumbnail: video.thumbnail_url,
            url: `/videos/${video.id}`
          }))
        }
      }

      // If searching all types or specifically categories, fetch categories
      let categoryResults: SearchResult[] = []
      if (filters.type === 'all' || filters.type === 'category') {
        let categoryQuery = supabase
          .from('categories')
          .select('*', { count: 'exact' })
          .order('created_at', { ascending: false })

        if (filters.query) {
          categoryQuery = categoryQuery.or(`name.ilike.%${filters.query}%,description.ilike.%${filters.query}%`)
        }

        if (filters.status !== 'all') {
          categoryQuery = categoryQuery.eq('is_active', filters.status === 'active')
        }

        categoryQuery = categoryQuery.range(from, to)

        const { data: categories, error: categoriesError } = await categoryQuery

        if (!categoriesError && categories) {
          categoryResults = categories.map(category => ({
            id: category.id,
            type: 'category' as const,
            title: category.name,
            description: category.description,
            status: category.is_active ? 'active' : 'inactive',
            views: Math.floor(Math.random() * 1000), // Mock data
            rating: (Math.random() * 2 + 3).toFixed(1), // Mock data
            createdAt: category.created_at,
            updatedAt: category.updated_at,
            thumbnail: category.icon_url,
            url: `/categories/${category.id}`
          }))
        }
      }

      // If searching all types or specifically users, fetch users
      let userResults: SearchResult[] = []
      if (filters.type === 'all' || filters.type === 'user') {
        let userQuery = supabase
          .from('profiles')
          .select('*', { count: 'exact' })
          .order('created_at', { ascending: false })

        if (filters.query) {
          userQuery = userQuery.or(`email.ilike.%${filters.query}%,full_name.ilike.%${filters.query}%`)
        }

        if (filters.status !== 'all') {
          userQuery = userQuery.eq('is_active', filters.status === 'active')
        }

        userQuery = userQuery.range(from, to)

        const { data: users, error: usersError } = await userQuery

        if (!usersError && users) {
          userResults = users.map(user => ({
            id: user.id,
            type: 'user' as const,
            title: user.full_name || user.email,
            description: user.user_metadata?.bio || user.email,
            status: user.is_active ? 'active' : 'inactive',
            views: Math.floor(Math.random() * 500), // Mock data
            rating: (Math.random() * 2 + 3).toFixed(1), // Mock data
            createdAt: user.created_at,
            updatedAt: user.updated_at,
            thumbnail: user.avatar_url,
            url: `/users/${user.id}`
          }))
        }
      }

      // Combine results
      let allResults = [...bookResults, ...videoResults, ...categoryResults, ...userResults]

      // Apply type filter
      if (filters.type !== 'all') {
        allResults = allResults.filter(result => result.type === filters.type)
      }

      // Apply category filter
      if (filters.category) {
        allResults = allResults.filter(result => result.category === filters.category)
      }

      // Apply sorting
      allResults.sort((a, b) => {
        let aValue: any, bValue: any

        switch (filters.sortBy) {
          case 'date':
            aValue = new Date(a.createdAt).getTime()
            bValue = new Date(b.createdAt).getTime()
            break
          case 'name':
            aValue = a.title.toLowerCase()
            bValue = b.title.toLowerCase()
            break
          case 'views':
            aValue = a.views || 0
            bValue = b.views || 0
            break
          case 'rating':
            aValue = a.rating || 0
            bValue = b.rating || 0
            break
          default:
            aValue = 0
            bValue = 0
        }

        if (filters.sortOrder === 'asc') {
          return aValue > bValue ? 1 : -1
        } else {
          return aValue < bValue ? 1 : -1
        }
      })

      setResults(allResults)
      setTotalResults(allResults.length)
      setTotalPages(Math.ceil(allResults.length / 10))

    } catch (error) {
      console.error('Error performing search:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleSearch = (filters: SearchFilters) => {
    setCurrentPage(1)
    performSearch(filters)
  }

  const handlePageChange = (page: number) => {
    setCurrentPage(page)
  }

  const handleItemClick = (item: SearchResult) => {
    if (item.url) {
      window.location.href = item.url
    }
  }

  return (
    <div className="flex min-h-screen bg-slate-950 text-slate-100 antialiased">
      {/* Sidebar */}
      <Sidebar isCollapsed={sidebarCollapsed} onToggle={() => setSidebarCollapsed(!sidebarCollapsed)} />

      {/* Main Content */}
      <div className="flex-1 flex flex-col min-h-screen lg:ml-0 ml-0">
        {/* Header */}
        <Header
          onMenuToggle={() => setSidebarCollapsed(!sidebarCollapsed)}
          title="Advanced Search"
          subtitle="Search across all content types"
        />

        {/* Main Content */}
        <main className="flex-1 px-4 sm:px-6 pb-8 pt-4 bg-gradient-to-br from-slate-950 via-slate-950 to-slate-900">
          {/* Breadcrumb */}
          <div className="flex items-center gap-2 mb-6 text-xs text-slate-400">
            <Link href="/" className="hover:text-slate-200 transition-colors">
              Dashboard
            </Link>
            <span>/</span>
            <span className="text-slate-200">Search</span>
          </div>

          {/* Search Section */}
          <div className="space-y-6">
            {/* Advanced Search */}
            <div className="card rounded-2xl p-4 sm:p-5">
              <div className="flex items-center gap-2 mb-4">
                <Search className="w-5 h-5 text-blue-400" />
                <h2 className="text-lg font-semibold">Search Content</h2>
              </div>
              <AdvancedSearch
                onSearch={handleSearch}
                placeholder="Search for books, videos, categories, or users..."
                showFilters={true}
              />
            </div>

            {/* Results Section */}
            {hasSearched && (
              <div className="card rounded-2xl p-4 sm:p-5">
                <SearchResults
                  results={results}
                  loading={loading}
                  query={""} // Will be handled by AdvancedSearch component
                  totalResults={totalResults}
                  currentPage={currentPage}
                  totalPages={totalPages}
                  onPageChange={handlePageChange}
                  onItemClick={handleItemClick}
                />
              </div>
            )}

            {/* Initial State */}
            {!hasSearched && (
              <div className="card rounded-2xl p-8 sm:p-12">
                <div className="text-center">
                  <div className="w-20 h-20 rounded-2xl bg-slate-900/80 border border-slate-700/80 flex items-center justify-center mx-auto mb-6">
                    <Search className="w-10 h-10 text-slate-400" />
                  </div>
                  <h2 className="text-xl font-semibold text-slate-200 mb-3">
                    Search Your Content
                  </h2>
                  <p className="text-sm text-slate-400 mb-6 max-w-md mx-auto">
                    Use the search bar above to find books, videos, categories, or users. Apply filters to narrow down your results.
                  </p>
                  <div className="flex flex-wrap items-center justify-center gap-4 text-xs text-slate-500">
                    <div className="flex items-center gap-2">
                      <div className="w-3 h-3 rounded-full bg-emerald-400"></div>
                      <span>Books</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <div className="w-3 h-3 rounded-full bg-blue-400"></div>
                      <span>Videos</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <div className="w-3 h-3 rounded-full bg-purple-400"></div>
                      <span>Categories</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <div className="w-3 h-3 rounded-full bg-amber-400"></div>
                      <span>Users</span>
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>
        </main>
      </div>
    </div>
  )
}

export default function SearchPage() {
  return (
    <QueryProvider>
      <SearchContent />
    </QueryProvider>
  )
}
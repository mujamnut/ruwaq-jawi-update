'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import QueryProvider from "@/components/query-provider"
import Sidebar from "@/components/sidebar"
import Header from "@/components/header"
import {
  Plus,
  Edit,
  Trash2,
  Search,
  Eye,
  Download,
  BookOpen,
  Filter
} from "lucide-react"
import { supabase } from "@/lib/supabase"
import { BulkOperations, BulkCheckbox } from "@/components/bulk-operations"

interface Book {
  id: string
  title: string
  author: string
  description: string
  category_id: string
  pdf_url: string
  thumbnail_url: string
  total_pages: number
  is_premium: boolean
  is_active: boolean
  created_at: string
  updated_at: string
}

function BooksContent() {
  const [books, setBooks] = useState<Book[]>([])
  const [categories, setCategories] = useState<any[]>([])
  const [searchTerm, setSearchTerm] = useState('')
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)
  const [loading, setLoading] = useState(true)
  const [deleteLoading, setDeleteLoading] = useState<string | null>(null)
  const [selectedBooks, setSelectedBooks] = useState<string[]>([])
  const [bulkLoading, setBulkLoading] = useState(false)

  useEffect(() => {
    Promise.all([fetchBooks(), fetchCategories()])
  }, [])

  const fetchBooks = async () => {
    try {
      setLoading(true)
      const { data, error } = await supabase
        .from('ebooks')
        .select('*')
        .order('created_at', { ascending: false })

      // Handle empty error objects and RLS issues
      if (error) {
        const errorMsg = error?.message || JSON.stringify(error) || 'Unknown error'
        console.error('Error fetching books:', errorMsg)
        return
      }

      setBooks(data || [])
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : JSON.stringify(error) || 'Unknown error'
      console.error('Error fetching books:', errorMsg)
    } finally {
      setLoading(false)
    }
  }

  const fetchCategories = async () => {
    try {
      const { data, error } = await supabase
        .from('categories')
        .select('id, name')
        .order('name')

      // Handle empty error objects and RLS issues
      if (error) {
        const errorMsg = error?.message || JSON.stringify(error) || 'Unknown error'
        console.error('Error fetching categories:', errorMsg)
        return
      }

      setCategories(data || [])
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : JSON.stringify(error) || 'Unknown error'
      console.error('Error fetching categories:', errorMsg)
    }
  }

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this book?')) return

    try {
      setDeleteLoading(id)
      const { error } = await supabase
        .from('ebooks')
        .delete()
        .eq('id', id)

      // Handle empty error objects and RLS issues
      if (error) {
        const errorMsg = error?.message || JSON.stringify(error) || 'Unknown error'
        console.error('Error deleting book:', errorMsg)
        return
      }

      await fetchBooks()
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : JSON.stringify(error) || 'Unknown error'
      console.error('Error deleting book:', errorMsg)
    } finally {
      setDeleteLoading(null)
    }
  }

  const getCategoryName = (categoryId: string) => {
    const category = categories.find(cat => cat.id === categoryId)
    return category?.name || 'Unknown'
  }

  const filteredBooks = books.filter(book =>
    book.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
    book.author.toLowerCase().includes(searchTerm.toLowerCase())
  )

  return (
    <div className="flex min-h-screen bg-slate-950 text-slate-100 antialiased">
      {/* Sidebar */}
      <Sidebar isCollapsed={sidebarCollapsed} onToggle={() => setSidebarCollapsed(!sidebarCollapsed)} />

      {/* Main Content */}
      <div className="flex-1 flex flex-col min-h-screen lg:ml-0 ml-0">
        {/* Header */}
        <Header
          onMenuToggle={() => setSidebarCollapsed(!sidebarCollapsed)}
          title="Ebooks Management"
          subtitle="Content Management"
        />

        {/* Main Content */}
        <main className="flex-1 px-4 sm:px-6 pb-8 pt-4 bg-gradient-to-br from-slate-950 via-slate-950 to-slate-900">
          {/* Page Header */}
          <div className="card rounded-2xl p-4 sm:p-5 mb-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <h2 className="text-base sm:text-lg font-semibold mb-1">Ebooks Library</h2>
                <p className="text-xs text-slate-400">Manage digital books and publications</p>
              </div>
              <div className="flex items-center gap-2">
                <Link href="/books/new" className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-gradient-to-r from-green-600 to-emerald-600 text-white text-xs font-medium hover:from-green-700 hover:to-emerald-700 transition-all shadow-lg">
                  <Plus className="w-4 h-4" />
                  Add New Book
                </Link>
              </div>
            </div>

            {/* Stats Cards */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mt-4">
              <div className="rounded-xl border border-slate-700/80 bg-slate-950/80 p-3">
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-[11px] text-slate-400">Total Books</span>
                  <span className="px-1.5 py-0.5 rounded-full bg-blue-500/10 text-[10px] text-blue-300 border border-blue-500/40">
                    {books.length}
                  </span>
                </div>
                <p className="text-lg font-semibold">{books.length}</p>
                <p className="mt-0.5 text-[11px] text-slate-500">Digital books</p>
              </div>
              <div className="rounded-xl border border-slate-700/80 bg-slate-950/80 p-3">
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-[11px] text-slate-400">Premium</span>
                  <span className="px-1.5 py-0.5 rounded-full bg-amber-500/10 text-[10px] text-amber-300 border border-amber-500/40">
                    {books.filter(b => b.is_premium).length}
                  </span>
                </div>
                <p className="text-lg font-semibold">{books.filter(b => b.is_premium).length}</p>
                <p className="mt-0.5 text-[11px] text-slate-500">Paid content</p>
              </div>
              <div className="rounded-xl border border-slate-700/80 bg-slate-950/80 p-3">
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-[11px] text-slate-400">Free</span>
                  <span className="px-1.5 py-0.5 rounded-full bg-emerald-500/10 text-[10px] text-emerald-300 border border-emerald-500/40">
                    {books.filter(b => !b.is_premium).length}
                  </span>
                </div>
                <p className="text-lg font-semibold">{books.filter(b => !b.is_premium).length}</p>
                <p className="mt-0.5 text-[11px] text-slate-500">Free content</p>
              </div>
              <div className="rounded-xl border border-slate-700/80 bg-slate-950/80 p-3">
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-[11px] text-slate-400">Categories</span>
                  <span className="px-1.5 py-0.5 rounded-full bg-indigo-500/10 text-[10px] text-indigo-300 border border-indigo-500/40">
                    {categories.length}
                  </span>
                </div>
                <p className="text-lg font-semibold">{categories.length}</p>
                <p className="mt-0.5 text-[11px] text-slate-500">Book categories</p>
              </div>
            </div>
          </div>

          {/* Filters and Search */}
          <div className="card rounded-2xl p-4 sm:p-5 mb-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div className="flex items-center gap-2">
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-slate-400 w-4 h-4" />
                  <input
                    type="text"
                    placeholder="Search books by title or author..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="pl-10 pr-4 py-2 w-full sm:w-80 rounded-xl bg-slate-900/80 border border-slate-700/80 text-xs text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
                  />
                </div>
                <button className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-slate-900/80 border border-slate-700/80 text-[11px] font-medium hover:bg-slate-800/90">
                  <Filter className="w-3.5 h-3.5" />
                  Filters
                </button>
              </div>
              <div className="text-[11px] text-slate-400">
                Showing {filteredBooks.length} of {books.length} books
              </div>
            </div>
          </div>

          {/* Bulk Operations */}
          <BulkOperations
            selectedItems={selectedBooks}
            items={filteredBooks}
            itemType="books"
            onSelectionChange={setSelectedBooks}
            onItemsUpdate={fetchBooks}
            onLoadingChange={setBulkLoading}
          />

          {/* Books Table */}
          <div className="card rounded-2xl p-4 sm:p-5">
            <div className="overflow-x-auto no-scrollbar">
              <table className="w-full text-left border-separate border-spacing-y-1.5">
                <thead className="text-[10px] uppercase tracking-[.18em] text-slate-500">
                  <tr>
                    <th className="px-2 py-1.5 w-10"></th>
                    <th className="px-2 py-1.5">Book</th>
                    <th className="px-2 py-1.5 whitespace-nowrap">Author</th>
                    <th className="px-2 py-1.5 whitespace-nowrap">Category</th>
                    <th className="px-2 py-1.5 whitespace-nowrap">Type</th>
                    <th className="px-2 py-1.5 whitespace-nowrap">Status</th>
                    <th className="px-2 py-1.5 whitespace-nowrap">Added</th>
                    <th className="px-2 py-1.5 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="text-xs">
                  {loading || bulkLoading ? (
                    <tr>
                      <td colSpan={8} className="text-center py-8">
                        <div className="flex items-center justify-center">
                          <div className="w-6 h-6 border-2 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
                          <span className="ml-2 text-slate-400">
                            {bulkLoading ? 'Processing bulk operation...' : 'Loading books...'}
                          </span>
                        </div>
                      </td>
                    </tr>
                  ) : filteredBooks.length === 0 ? (
                    <tr>
                      <td colSpan={8} className="text-center py-8">
                        <div className="flex flex-col items-center">
                          <BookOpen className="w-12 h-12 text-slate-600 mb-3" />
                          <h3 className="text-sm font-medium text-slate-300 mb-1">No books found</h3>
                          <p className="text-[11px] text-slate-500">
                            {searchTerm ? 'No books match your search criteria' : 'Start by adding your first book'}
                          </p>
                        </div>
                      </td>
                    </tr>
                  ) : (
                    filteredBooks.map((book) => (
                      <tr key={book.id} className={`bg-slate-950/90 hover:bg-slate-900/90 transition border border-slate-800/80 ${selectedBooks.includes(book.id) ? 'bg-blue-500/5' : ''}`}>
                        <td className="px-2 py-3">
                          <div className="flex items-center justify-center">
                            <BulkCheckbox
                              itemId={book.id}
                              isSelected={selectedBooks.includes(book.id)}
                              onToggle={(id, checked) => {
                                if (checked) {
                                  setSelectedBooks(prev => [...prev, id])
                                } else {
                                  setSelectedBooks(prev => prev.filter(selectedId => selectedId !== id))
                                }
                              }}
                              disabled={bulkLoading}
                            />
                          </div>
                        </td>
                        <td className="px-2 py-3">
                          <div className="flex items-center gap-3">
                            <div className="w-10 h-10 rounded-xl bg-slate-900 flex items-center justify-center border border-slate-700/80">
                              {book.thumbnail_url ? (
                                <img
                                  src={book.thumbnail_url}
                                  alt={book.title}
                                  className="w-full h-full object-cover rounded-xl"
                                />
                              ) : (
                                <BookOpen className="w-4 h-4 text-blue-400" />
                              )}
                            </div>
                            <div className="flex-1 min-w-0">
                              <p className="text-xs font-medium text-slate-100 truncate">{book.title}</p>
                              <p className="text-[10px] text-slate-400 line-clamp-2">{book.description || 'No description'}</p>
                            </div>
                          </div>
                        </td>
                        <td className="px-2 py-3">
                          <div className="text-xs text-slate-200">{book.author}</div>
                        </td>
                        <td className="px-2 py-3">
                          <span className="px-2 py-0.5 rounded-full bg-slate-900 border border-slate-700/80 text-[10px] text-slate-200">
                            {getCategoryName(book.category_id)}
                          </span>
                        </td>
                        <td className="px-2 py-3">
                          <span className={`px-2 py-0.5 rounded-full text-[10px] border ${
                            book.is_premium
                              ? 'bg-amber-500/10 text-amber-300 border-amber-500/40'
                              : 'bg-emerald-500/10 text-emerald-300 border-emerald-500/40'
                          }`}>
                            {book.is_premium ? 'Premium' : 'Free'}
                          </span>
                        </td>
                        <td className="px-2 py-3">
                          <span className={`px-2 py-0.5 rounded-full text-[10px] border ${
                            book.is_active
                              ? 'bg-emerald-500/10 text-emerald-300 border-emerald-500/40'
                              : 'bg-rose-500/10 text-rose-300 border-rose-500/40'
                          }`}>
                            {book.is_active ? 'Active' : 'Inactive'}
                          </span>
                        </td>
                        <td className="px-2 py-3">
                          <div className="text-[11px] text-slate-400">
                            {new Date(book.created_at).toLocaleDateString('en-US', {
                              month: 'short',
                              day: 'numeric',
                              year: 'numeric'
                            })}
                          </div>
                        </td>
                        <td className="px-2 py-3">
                          <div className="flex items-center justify-end gap-1">
                            <button className="p-1.5 rounded-lg bg-slate-900 border border-slate-700/80 text-[10px] hover:bg-slate-800/90 text-slate-300">
                              <Eye className="w-3.5 h-3.5" />
                            </button>
                            <button className="p-1.5 rounded-lg bg-slate-900 border border-slate-700/80 text-[10px] hover:bg-slate-800/90 text-slate-300">
                              <Edit className="w-3.5 h-3.5" />
                            </button>
                            <button
                              onClick={() => handleDelete(book.id)}
                              disabled={deleteLoading === book.id}
                              className="p-1.5 rounded-lg bg-slate-900 border border-slate-700/80 text-[10px] hover:bg-rose-600/20 hover:border-rose-500/40 text-slate-300 hover:text-rose-300 disabled:opacity-50"
                            >
                              {deleteLoading === book.id ? (
                                <div className="w-3.5 h-3.5 border border-current border-t-transparent rounded-full animate-spin"></div>
                              ) : (
                                <Trash2 className="w-3.5 h-3.5" />
                              )}
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </main>
      </div>
    </div>
  )
}

export default function BooksPage() {
  return (
    <QueryProvider>
      <BooksContent />
    </QueryProvider>
  )
}
'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import DashboardLayout from "@/components/dashboard-layout"
import {
  Plus,
  Edit,
  Trash2,
  Search,
  Folder,
  Filter,
  Tag,
  RefreshCw
} from 'lucide-react'
import { supabase } from "@/lib/supabase"
import { BulkOperations, BulkCheckbox } from "@/components/bulk-operations"

interface Category {
  id: string
  name: string
  description: string
  icon_url: string
  sort_order: number
  is_active: boolean
  created_at: string
  updated_at: string
}

function CategoriesContent() {
  const [categories, setCategories] = useState<Category[]>([])
  const [searchTerm, setSearchTerm] = useState('')
  const [loading, setLoading] = useState(true)
  const [deleteLoading, setDeleteLoading] = useState<string | null>(null)
  const [selectedCategories, setSelectedCategories] = useState<string[]>([])
  const [bulkLoading, setBulkLoading] = useState(false)
  const [refreshKey, setRefreshKey] = useState(0)

  useEffect(() => {
    fetchCategories()
  }, [refreshKey])

  // Refresh data when page becomes visible again
  useEffect(() => {
    const handleVisibilityChange = () => {
      if (document.visibilityState === 'visible') {
        setRefreshKey(prev => prev + 1)
      }
    }

    const handleFocus = () => {
      setRefreshKey(prev => prev + 1)
    }

    document.addEventListener('visibilitychange', handleVisibilityChange)
    window.addEventListener('focus', handleFocus)

    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange)
      window.removeEventListener('focus', handleFocus)
    }
  }, [])

  const fetchCategories = async () => {
    try {
      setLoading(true)
      const { data, error } = await supabase
        .from('categories')
        .select('*')
        .order('sort_order', { ascending: true })

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
    } finally {
      setLoading(false)
    }
  }

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this category? This action cannot be undone.')) return

    try {
      setDeleteLoading(id)
      const { error } = await supabase
        .from('categories')
        .delete()
        .eq('id', id)

      // Handle empty error objects and RLS issues
      if (error) {
        const errorMsg = error?.message || JSON.stringify(error) || 'Unknown error'
        console.error('Error deleting category:', errorMsg)
        return
      }

      await fetchCategories()
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : JSON.stringify(error) || 'Unknown error'
      console.error('Error deleting category:', errorMsg)
    } finally {
      setDeleteLoading(null)
    }
  }

  const filteredCategories = categories.filter(category =>
    category.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    category.description.toLowerCase().includes(searchTerm.toLowerCase())
  )

  return (
    <DashboardLayout title="Categories" subtitle="Content categories & organization">
          <main className="flex-1 px-4 sm:px-6 pb-8 pt-4 bg-gray-50 dark:bg-gradient-to-br dark:from-slate-950 dark:via-slate-950 dark:to-slate-900 transition-colors duration-300">
          {/* Page Header */}
          <div className="card rounded-2xl p-4 sm:p-5 mb-4 bg-white dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <h2 className="text-base sm:text-lg font-semibold mb-1">Content Categories</h2>
                <p className="text-xs text-gray-600">Organize your content by categories</p>
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => setRefreshKey(prev => prev + 1)}
                  disabled={loading}
                  className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-white/90 dark:bg-slate-700/90 border border-gray-300/80 dark:border-slate-600/80 text-[11px] font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-100/90 dark:hover:bg-slate-600/90 disabled:opacity-50 transition-all"
                >
                  <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
                  Refresh
                </button>
                <Link href="/categories/new" className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-gradient-to-r from-blue-600 to-indigo-600 text-white text-xs font-medium hover:from-blue-700 hover:to-indigo-700 transition-all shadow-lg">
                  <Plus className="w-4 h-4" />
                  Add Category
                </Link>
              </div>
            </div>

            {/* Stats Cards */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mt-4">
              <div className="rounded-xl border border-gray-300/80 dark:border-slate-600/80 bg-white/80 dark:bg-slate-800/90 p-3">
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-[11px] text-gray-600 dark:text-gray-400">Total</span>
                  <span className="px-1.5 py-0.5 rounded-full bg-blue-500/10 text-[10px] text-blue-300 dark:text-blue-400 border border-blue-500/40 dark:border-blue-400/40">
                    {categories.length}
                  </span>
                </div>
                <p className="text-lg font-semibold text-gray-900 dark:text-white">{categories.length}</p>
                <p className="mt-0.5 text-[11px] text-gray-500 dark:text-gray-400">Categories</p>
              </div>
              <div className="rounded-xl border border-gray-300/80 dark:border-slate-600/80 bg-white/80 dark:bg-slate-800/90 p-3">
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-[11px] text-gray-600 dark:text-gray-400">Active</span>
                  <span className="px-1.5 py-0.5 rounded-full bg-emerald-500/10 text-[10px] text-emerald-300 dark:text-emerald-400 border border-emerald-500/40 dark:border-emerald-400/40">
                    {categories.filter(c => c.is_active).length}
                  </span>
                </div>
                <p className="text-lg font-semibold text-gray-900 dark:text-white">{categories.filter(c => c.is_active).length}</p>
                <p className="mt-0.5 text-[11px] text-gray-500 dark:text-gray-400">Live now</p>
              </div>
              <div className="rounded-xl border border-gray-300/80 dark:border-slate-600/80 bg-white/80 dark:bg-slate-800/90 p-3">
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-[11px] text-gray-600 dark:text-gray-400">Inactive</span>
                  <span className="px-1.5 py-0.5 rounded-full bg-rose-500/10 text-[10px] text-rose-300 dark:text-rose-400 border border-rose-500/40 dark:border-rose-400/40">
                    {categories.filter(c => !c.is_active).length}
                  </span>
                </div>
                <p className="text-lg font-semibold text-gray-900 dark:text-white">{categories.filter(c => !c.is_active).length}</p>
                <p className="mt-0.5 text-[11px] text-gray-500 dark:text-gray-400">Hidden</p>
              </div>
              <div className="rounded-xl border border-gray-300/80 dark:border-slate-600/80 bg-white/80 dark:bg-slate-800/90 p-3">
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-[11px] text-gray-600 dark:text-gray-400">Sort Order</span>
                  <span className="px-1.5 py-0.5 rounded-full bg-indigo-500/10 text-[10px] text-indigo-300 dark:text-indigo-400 border border-indigo-500/40 dark:border-indigo-400/40">
                    Ordered
                  </span>
                </div>
                <p className="text-lg font-semibold text-gray-900 dark:text-white">{categories.filter(c => c.sort_order > 0).length}</p>
                <p className="mt-0.5 text-[11px] text-gray-500 dark:text-gray-400">Custom sort</p>
              </div>
            </div>
          </div>

          {/* Filters and Search */}
          <div className="card rounded-2xl p-4 sm:p-5 mb-4 bg-white dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div className="flex items-center gap-2">
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-600 dark:text-gray-400 w-4 h-4" />
                  <input
                    type="text"
                    placeholder="Search categories by name or description..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="pl-10 pr-4 py-2 w-full sm:w-80 rounded-xl bg-white/80 dark:bg-slate-700/90 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500/50 dark:focus:ring-blue-400/50 focus:border-blue-500/50 dark:focus:border-blue-400/50"
                  />
                </div>
                <button className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-white/80 dark:bg-slate-700/90 border border-gray-300/80 dark:border-slate-600/80 text-[11px] font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-100/90 dark:hover:bg-slate-600/90">
                  <Filter className="w-3.5 h-3.5" />
                  Filters
                </button>
              </div>
              <div className="text-[11px] text-gray-600 dark:text-gray-400">
                Showing {filteredCategories.length} of {categories.length} categories
              </div>
            </div>
          </div>

          {/* Bulk Operations */}
          <BulkOperations
            selectedItems={selectedCategories}
            items={filteredCategories}
            itemType="categories"
            onSelectionChange={setSelectedCategories}
            onItemsUpdate={fetchCategories}
            onLoadingChange={setBulkLoading}
          />

          {/* Categories Table */}
          <div className="card rounded-2xl p-4 sm:p-5 bg-white dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80">
            <div className="overflow-x-auto no-scrollbar">
              <table className="w-full text-left border-separate border-spacing-y-1.5">
                <thead className="text-[10px] uppercase tracking-[.18em] text-gray-500 dark:text-gray-400">
                  <tr>
                    <th className="px-2 py-1.5 w-10"></th>
                    <th className="px-2 py-1.5">Category</th>
                    <th className="px-2 py-1.5">Description</th>
                    <th className="px-2 py-1.5 whitespace-nowrap">Sort Order</th>
                    <th className="px-2 py-1.5 whitespace-nowrap">Status</th>
                    <th className="px-2 py-1.5 whitespace-nowrap">Created</th>
                    <th className="px-2 py-1.5 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="text-xs">
                  {loading || bulkLoading ? (
                    <tr>
                      <td colSpan={7} className="text-center py-8">
                        <div className="flex items-center justify-center">
                          <div className="w-6 h-6 border-2 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
                          <span className="ml-2 text-gray-600 dark:text-gray-400">
                            {bulkLoading ? 'Processing bulk operation...' : 'Loading categories...'}
                          </span>
                        </div>
                      </td>
                    </tr>
                  ) : filteredCategories.length === 0 ? (
                    <tr>
                      <td colSpan={7} className="text-center py-8">
                        <div className="flex flex-col items-center">
                          <Folder className="w-12 h-12 text-gray-400 dark:text-gray-600 mb-3" />
                          <h3 className="text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">No categories found</h3>
                          <p className="text-[11px] text-gray-500 dark:text-gray-400">
                            {searchTerm ? 'No categories match your search criteria' : 'Start by adding your first category'}
                          </p>
                        </div>
                      </td>
                    </tr>
                  ) : (
                    filteredCategories.map((category) => (
                      <tr key={category.id} className={`bg-white/90 dark:bg-slate-700/90 hover:bg-white dark:hover:bg-slate-700 transition border border-gray-200/80 dark:border-slate-600/80 ${selectedCategories.includes(category.id) ? 'bg-blue-500/5 dark:bg-blue-500/10' : ''}`}>
                        <td className="px-2 py-3">
                          <div className="flex items-center justify-center">
                            <BulkCheckbox
                              itemId={category.id}
                              isSelected={selectedCategories.includes(category.id)}
                              onToggle={(id, checked) => {
                                if (checked) {
                                  setSelectedCategories(prev => [...prev, id])
                                } else {
                                  setSelectedCategories(prev => prev.filter(selectedId => selectedId !== id))
                                }
                              }}
                              disabled={bulkLoading}
                            />
                          </div>
                        </td>
                        <td className="px-2 py-3">
                          <div className="flex items-center gap-3">
                            <div className="w-10 h-10 rounded-xl bg-white dark:bg-slate-600 flex items-center justify-center border border-gray-300/80 dark:border-slate-500/80">
                              {category.icon_url ? (
                                <img
                                  src={category.icon_url}
                                  alt={category.name}
                                  className="w-full h-full object-cover rounded-xl"
                                />
                              ) : (
                                <Tag className="w-4 h-4 text-blue-400 dark:text-blue-300" />
                              )}
                            </div>
                            <div className="flex-1 min-w-0">
                              <p className="text-xs font-medium text-gray-900 dark:text-white truncate">{category.name}</p>
                              <p className="text-[10px] text-gray-600 dark:text-gray-400">Category ID: {category.id.substring(0, 8)}...</p>
                            </div>
                          </div>
                        </td>
                        <td className="px-2 py-3">
                          <div className="max-w-xs">
                            <p className="text-xs text-gray-800 dark:text-gray-200 line-clamp-2">
                              {category.description || 'No description provided'}
                            </p>
                          </div>
                        </td>
                        <td className="px-2 py-3">
                          <span className="px-2 py-0.5 rounded-full bg-white dark:bg-slate-600 border border-gray-300/80 dark:border-slate-500/80 text-[10px] text-gray-800 dark:text-gray-200">
                            {category.sort_order || 'Default'}
                          </span>
                        </td>
                        <td className="px-2 py-3">
                          <span className={`px-2 py-0.5 rounded-full text-[10px] border ${
                            category.is_active
                              ? 'bg-emerald-500/10 text-emerald-300 dark:text-emerald-400 border-emerald-500/40 dark:border-emerald-400/40'
                              : 'bg-rose-500/10 text-rose-300 dark:text-rose-400 border-rose-500/40 dark:border-rose-400/40'
                          }`}>
                            {category.is_active ? 'Active' : 'Inactive'}
                          </span>
                        </td>
                        <td className="px-2 py-3">
                          <div className="text-[11px] text-gray-600 dark:text-gray-400">
                            {new Date(category.created_at).toLocaleDateString('en-US', {
                              month: 'short',
                              day: 'numeric',
                              year: 'numeric'
                            })}
                          </div>
                        </td>
                        <td className="px-2 py-3">
                          <div className="flex items-center justify-end gap-1">
                            <Link href={`/categories/${category.id}/edit`} className="p-1.5 rounded-lg bg-white dark:bg-slate-600 border border-gray-300/80 dark:border-slate-500/80 text-[10px] hover:bg-gray-100/90 dark:hover:bg-slate-500/90 text-gray-700 dark:text-gray-300">
                              <Edit className="w-3.5 h-3.5" />
                            </Link>
                            <button
                              onClick={() => handleDelete(category.id)}
                              disabled={deleteLoading === category.id}
                              className="p-1.5 rounded-lg bg-white dark:bg-slate-600 border border-gray-300/80 dark:border-slate-500/80 text-[10px] hover:bg-rose-600/20 dark:hover:bg-rose-600/30 hover:border-rose-500/40 dark:hover:border-rose-400/40 text-gray-700 dark:text-gray-300 hover:text-rose-300 dark:hover:text-rose-400 disabled:opacity-50"
                            >
                              {deleteLoading === category.id ? (
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
    </DashboardLayout>
  )
}

export default function CategoriesPage() {
  return <CategoriesContent />
}
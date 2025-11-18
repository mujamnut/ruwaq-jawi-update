'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import DashboardLayout from "@/components/dashboard-layout"
import {
  ArrowLeft,
  Save,
  Tag,
  Upload,
  X,
  Image
} from 'lucide-react'
import { supabase } from "@/lib/supabase"

function NewCategoryContent() {
  
  const [loading, setLoading] = useState(false)
  const [uploading, setUploading] = useState(false)

  // Form state
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    sort_order: 0,
    is_active: true
  })

  // Icon state
  const [iconFile, setIconFile] = useState<File | null>(null)
  const [iconPreview, setIconPreview] = useState<string>('')

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    const { name, value, type } = e.target
    setFormData(prev => ({
      ...prev,
      [name]: type === 'checkbox' ? (e.target as HTMLInputElement).checked : value
    }))
  }

  const handleIconChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) {
      if (file.type.startsWith('image/')) {
        setIconFile(file)
        const reader = new FileReader()
        reader.onloadend = () => {
          setIconPreview(reader.result as string)
        }
        reader.readAsDataURL(file)
      } else {
        alert('Please upload an image file')
      }
    }
  }

  const removeIcon = () => {
    setIconFile(null)
    setIconPreview('')
  }

  const uploadIcon = async (file: File) => {
    const fileExt = file.name.split('.').pop()
    const fileName = `${Date.now()}.${fileExt}`
    const filePath = `category-icons/${fileName}`

    const { error: uploadError } = await supabase.storage
      .from('book-files')
      .upload(filePath, file)

    if (uploadError) throw uploadError

    const { data } = supabase.storage
      .from('book-files')
      .getPublicUrl(filePath)

    return data.publicUrl
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    if (!formData.name) {
      alert('Please enter a category name')
      return
    }

    setLoading(true)

    try {
      let iconUrl = ''

      // Upload icon if provided
      if (iconFile) {
        setUploading(true)
        iconUrl = await uploadIcon(iconFile)
      }

      // Get current max sort order if not specified
      let sortOrder = formData.sort_order
      if (sortOrder === 0) {
        const { data: categories } = await supabase
          .from('categories')
          .select('sort_order')
          .order('sort_order', { ascending: false })
          .limit(1)

        if (categories && categories.length > 0) {
          sortOrder = (categories[0].sort_order || 0) + 10
        } else {
          sortOrder = 10
        }
      }

      // Insert category data
      const { error } = await supabase
        .from('categories')
        .insert({
          name: formData.name,
          description: formData.description,
          icon_url: iconUrl,
          sort_order: sortOrder,
          is_active: formData.is_active
        })

      if (error) throw error

      alert('Category created successfully!')
      // Redirect to categories page
      window.location.href = '/categories'
    } catch (error) {
      console.error('Error creating category:', error)
      alert('Error creating category. Please try again.')
    } finally {
      setLoading(false)
      setUploading(false)
    }
  }

  return (
    <DashboardLayout
      title="Add New Category"
      subtitle="Content Organization"
    >
      {/* Main Content */}
      <div className="px-4 sm:px-6 pb-8 pt-4">
          <div className="w-full">
            {/* Page Header */}
            <div className="card rounded-2xl p-4 sm:p-5 mb-4">
              <div className="flex items-center gap-3 mb-4">
                <Link href="/categories" className="p-2 rounded-xl bg-white/90 border border-gray-300/80 hover:bg-gray-100/90 transition">
                  <ArrowLeft className="w-4 h-4 text-gray-700" />
                </Link>
                <div>
                  <h2 className="text-base sm:text-lg font-semibold">Add New Category</h2>
                  <p className="text-xs text-gray-600 dark:text-gray-400">Create a new content category</p>
                </div>
              </div>
            </div>

            {/* Form */}
            <form onSubmit={handleSubmit} className="card rounded-2xl p-4 sm:p-5">
              <div className="space-y-6">
                {/* Basic Information */}
                <div>
                  <h3 className="text-sm font-semibold mb-4 flex items-center gap-2">
                    <Tag className="w-4 h-4 text-blue-400" />
                    Category Information
                  </h3>
                  <div className="space-y-4">
                    <div>
                      <label className="block text-[11px] font-medium text-gray-700 dark:text-gray-300 mb-2">
                        Category Name *
                      </label>
                      <input
                        type="text"
                        name="name"
                        value={formData.name}
                        onChange={handleInputChange}
                        className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
                        placeholder="Enter category name"
                        required
                      />
                    </div>
                    <div>
                      <label className="block text-[11px] font-medium text-gray-700 dark:text-gray-300 mb-2">
                        Description
                      </label>
                      <textarea
                        name="description"
                        value={formData.description}
                        onChange={handleInputChange}
                        rows={3}
                        className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50 resize-none"
                        placeholder="Enter category description"
                      />
                    </div>
                    <div>
                      <label className="block text-[11px] font-medium text-gray-700 dark:text-gray-300 mb-2">
                        Sort Order
                      </label>
                      <input
                        type="number"
                        name="sort_order"
                        value={formData.sort_order}
                        onChange={handleInputChange}
                        min="0"
                        className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
                        placeholder="Leave as 0 for automatic ordering"
                      />
                      <p className="text-[10px] text-gray-500 mt-1">
                        Lower numbers appear first. Leave as 0 for automatic ordering.
                      </p>
                    </div>
                  </div>
                </div>

                {/* Category Icon */}
                <div>
                  <h3 className="text-sm font-semibold mb-4 flex items-center gap-2">
                    <Image className="w-4 h-4 text-purple-400" />
                    Category Icon
                  </h3>
                  <div className="border-2 border-dashed border-gray-300/80 rounded-xl p-4">
                    {iconPreview ? (
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-3">
                          <div className="w-12 h-12 rounded-xl overflow-hidden">
                            <img
                              src={iconPreview}
                              alt="Icon preview"
                              className="w-full h-full object-cover"
                            />
                          </div>
                          <div>
                            <p className="text-xs font-medium text-gray-800 dark:text-gray-200">Icon uploaded</p>
                            <p className="text-[10px] text-gray-600 dark:text-gray-400">Image file</p>
                          </div>
                        </div>
                        <button
                          type="button"
                          onClick={removeIcon}
                          className="p-1.5 rounded-lg bg-rose-600/20 border border-rose-500/40 text-rose-300 hover:bg-rose-600/30"
                        >
                          <X className="w-4 h-4" />
                        </button>
                      </div>
                    ) : (
                      <div className="text-center">
                        <input
                          type="file"
                          accept="image/*"
                          onChange={handleIconChange}
                          className="hidden"
                          id="icon-upload"
                        />
                        <label
                          htmlFor="icon-upload"
                          className="cursor-pointer inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-white/80 border border-gray-300/80 text-xs text-gray-700 hover:bg-gray-100/90 transition"
                        >
                          <Upload className="w-4 h-4" />
                          Choose Icon
                        </label>
                        <p className="text-[10px] text-gray-500 mt-2">
                          Upload JPG, PNG or GIF (Max 1MB)
                        </p>
                        <p className="text-[10px] text-gray-400 mt-1">
                          Optional - Used for category identification
                        </p>
                      </div>
                    )}
                  </div>
                </div>

                {/* Settings */}
                <div>
                  <h3 className="text-sm font-semibold mb-4 flex items-center gap-2">
                    <Tag className="w-4 h-4 text-green-400" />
                    Category Settings
                  </h3>
                  <div className="space-y-3">
                    <label className="flex items-center gap-3 cursor-pointer">
                      <input
                        type="checkbox"
                        name="is_active"
                        checked={formData.is_active}
                        onChange={handleInputChange}
                        className="w-4 h-4 rounded bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
                      />
                      <div>
                        <span className="text-xs font-medium text-gray-800 dark:text-gray-200">Active</span>
                        <p className="text-[10px] text-gray-600 dark:text-gray-400">Category is visible and can be used</p>
                      </div>
                    </label>
                  </div>
                </div>

                {/* Actions */}
                <div className="flex items-center justify-end gap-3 pt-4 border-t border-gray-200/80">
                  <Link
                    href="/categories"
                    className="px-4 py-2 rounded-xl bg-white/80 border border-gray-300/80 text-xs text-gray-700 hover:bg-gray-100/90 transition"
                  >
                    Cancel
                  </Link>
                  <button
                    type="submit"
                    disabled={loading || uploading}
                    className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-gradient-to-r from-blue-600 to-indigo-600 text-white text-xs font-medium hover:from-blue-700 hover:to-indigo-700 transition-all shadow-lg disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {loading || uploading ? (
                      <>
                        <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                        {uploading ? 'Uploading...' : 'Saving...'}
                      </>
                    ) : (
                      <>
                        <Save className="w-4 h-4" />
                        Create Category
                      </>
                    )}
                  </button>
                </div>
              </div>
            </form>
          </div>
      </div>
    </DashboardLayout>
  )
}

export default function NewCategoryPage() {
  return <NewCategoryContent />
}
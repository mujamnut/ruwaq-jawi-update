'use client'

import { useState, useEffect } from 'react'
import { useParams, useRouter } from 'next/navigation'
import Link from 'next/link'
import DashboardLayout from "@/components/dashboard-layout"
import {
  ArrowLeft,
  Save,
  Upload,
  X,
  Tag,
  Folder,
  Eye,
  EyeOff,
  Loader,
  AlertTriangle,
  CheckCircle,
  Info
} from 'lucide-react'
import { supabase } from "@/lib/supabase"

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

function CategoryEditContent() {
  const params = useParams()
  const router = useRouter()
  const categoryId = params.id as string

  const [category, setCategory] = useState<Category | null>(null)
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    icon_url: '',
    sort_order: 0,
    is_active: true
  })
  const [iconFile, setIconFile] = useState<File | null>(null)
  const [iconPreview, setIconPreview] = useState('')
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [uploading, setUploading] = useState(false)
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [success, setSuccess] = useState(false)

  useEffect(() => {
    if (categoryId) {
      fetchCategory()
    }
  }, [categoryId])

  const fetchCategory = async () => {
    try {
      setLoading(true)
      const { data, error } = await supabase
        .from('categories')
        .select('*')
        .eq('id', categoryId)
        .single()

      if (error) throw error

      setCategory(data)
      setFormData({
        name: data.name || '',
        description: data.description || '',
        icon_url: data.icon_url || '',
        sort_order: data.sort_order || 0,
        is_active: data.is_active !== false
      })
      setIconPreview(data.icon_url || '')
    } catch (error) {
      console.error('Error fetching category:', error)
      setErrors({ fetch: 'Failed to fetch category details' })
    } finally {
      setLoading(false)
    }
  }

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value, type } = e.target
    if (type === 'checkbox') {
      const checked = (e.target as HTMLInputElement).checked
      setFormData(prev => ({ ...prev, [name]: checked }))
    } else if (type === 'number') {
      setFormData(prev => ({ ...prev, [name]: parseInt(value) || 0 }))
    } else {
      setFormData(prev => ({ ...prev, [name]: value }))
    }

    // Clear error for this field
    if (errors[name]) {
      setErrors(prev => ({ ...prev, [name]: '' }))
    }
  }

  const handleIconSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) {
      // Validate file type
      if (!file.type.startsWith('image/')) {
        setErrors({ icon: 'Please select an image file' })
        return
      }

      // Validate file size (max 5MB)
      if (file.size > 5 * 1024 * 1024) {
        setErrors({ icon: 'File size must be less than 5MB' })
        return
      }

      setIconFile(file)
      setErrors(prev => ({ ...prev, icon: '' }))

      // Create preview
      const reader = new FileReader()
      reader.onload = (e) => {
        setIconPreview(e.target?.result as string)
      }
      reader.readAsDataURL(file)
    }
  }

  const clearIcon = () => {
    setIconFile(null)
    setIconPreview('')
    setFormData(prev => ({ ...prev, icon_url: '' }))
    if (errors.icon) {
      setErrors(prev => ({ ...prev, icon: '' }))
    }
  }

  const uploadIcon = async (): Promise<string | null> => {
    if (!iconFile) return formData.icon_url

    try {
      setUploading(true)

      // Upload to Supabase Storage
      const fileExt = iconFile.name.split('.').pop()
      const fileName = `category-${Date.now()}.${fileExt}`
      const filePath = `category-icons/${fileName}`

      // Delete old icon if exists
      if (formData.icon_url && formData.icon_url.includes('category-icons/')) {
        const oldFileName = formData.icon_url.split('/').pop()
        if (oldFileName) {
          await supabase.storage
            .from('assets')
            .remove([`category-icons/${oldFileName}`])
        }
      }

      const { error: uploadError } = await supabase.storage
        .from('assets')
        .upload(filePath, iconFile, {
          cacheControl: '3600',
          upsert: false
        })

      if (uploadError) throw uploadError

      // Get public URL
      const { data } = supabase.storage
        .from('assets')
        .getPublicUrl(filePath)

      return data.publicUrl
    } catch (error) {
      console.error('Error uploading icon:', error)
      throw error
    } finally {
      setUploading(false)
    }
  }

  const validateForm = () => {
    const newErrors: Record<string, string> = {}

    if (!formData.name.trim()) {
      newErrors.name = 'Category name is required'
    }

    if (!formData.description.trim()) {
      newErrors.description = 'Description is required'
    } else if (formData.description.length < 10) {
      newErrors.description = 'Description must be at least 10 characters'
    }

    if (formData.sort_order < 0) {
      newErrors.sort_order = 'Sort order must be 0 or greater'
    }

    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    if (!validateForm()) return

    try {
      setSaving(true)
      setSuccess(false)

      // Upload icon if selected
      const iconUrl = await uploadIcon()

      // Update category
      const { error } = await supabase
        .from('categories')
        .update({
          name: formData.name.trim(),
          description: formData.description.trim(),
          icon_url: iconUrl,
          sort_order: formData.sort_order,
          is_active: formData.is_active,
          updated_at: new Date().toISOString()
        })
        .eq('id', categoryId)

      if (error) throw error

      setSuccess(true)

      // Update local state
      if (category) {
        setCategory({
          ...category,
          name: formData.name.trim(),
          description: formData.description.trim(),
          icon_url: iconUrl || '',
          sort_order: formData.sort_order,
          is_active: formData.is_active,
          updated_at: new Date().toISOString()
        })
      }

      // Show success message briefly then redirect
      setTimeout(() => {
        router.push('/categories')
      }, 2000)

    } catch (error) {
      console.error('Error updating category:', error)
      setErrors({ submit: 'Failed to update category. Please try again.' })
    } finally {
      setSaving(false)
    }
  }

  if (loading) {
    return (
      <DashboardLayout title="Edit Category" subtitle="Loading...">
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="text-center">
            <Loader className="w-8 h-8 animate-spin mx-auto mb-2 text-blue-400" />
            <p className="text-gray-600 dark:text-gray-400">Loading category details...</p>
          </div>
        </div>
      </DashboardLayout>
    )
  }

  if (!category && !loading) {
    return (
      <DashboardLayout title="Category Not Found" subtitle="Error">
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="text-center">
            <AlertTriangle className="w-8 h-8 mx-auto mb-2 text-rose-400" />
            <p className="text-gray-600 dark:text-gray-400">Category not found</p>
          </div>
        </div>
      </DashboardLayout>
    )
  }

  return (
    <DashboardLayout title="Edit Category" subtitle="Update Category Information">
      <div className="px-4 sm:px-6 py-4">
        {/* Breadcrumb */}
        <div className="mb-4">
          <Link
            href="/categories"
            className="inline-flex items-center gap-2 text-gray-600 dark:text-gray-400 hover:text-gray-800 dark:text-gray-200 text-xs transition-colors"
          >
            <ArrowLeft className="w-3.5 h-3.5" />
            Back to Categories
          </Link>
        </div>

        {success && (
          <div className="card rounded-xl p-4 mb-4 border-emerald-500/20 bg-emerald-500/5">
            <div className="flex items-center gap-3">
              <CheckCircle className="w-5 h-5 text-emerald-400" />
              <div>
                <h4 className="text-sm font-medium text-emerald-300">Category Updated Successfully!</h4>
                <p className="text-xs text-emerald-400">Redirecting to categories list...</p>
              </div>
            </div>
          </div>
        )}

        {errors.fetch && (
          <div className="card rounded-xl p-4 mb-4 border-rose-500/20 bg-rose-500/5">
            <div className="flex items-center gap-3">
              <AlertTriangle className="w-5 h-5 text-rose-400" />
              <p className="text-sm text-rose-300">{errors.fetch}</p>
            </div>
          </div>
        )}

        {/* Edit Form */}
        <div className="card rounded-2xl p-5 sm:p-6">
          <form onSubmit={handleSubmit} className="space-y-6">
            {/* Basic Information */}
            <div>
              <h3 className="text-sm font-semibold text-gray-800 dark:text-gray-200 mb-4 flex items-center gap-2">
                <Folder className="w-4 h-4 text-blue-400" />
                Basic Information
              </h3>

              <div className="grid sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Category Name *
                  </label>
                  <input
                    type="text"
                    name="name"
                    value={formData.name}
                    onChange={handleInputChange}
                    className={`w-full px-3 py-2 rounded-lg bg-white/80 border ${
                      errors.name ? 'border-rose-500/50' : 'border-gray-300/80'
                    } text-xs text-gray-900 placeholder:text-gray-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50`}
                    placeholder="e.g., Islamic Studies"
                  />
                  {errors.name && (
                    <p className="text-xs text-rose-400 mt-1">{errors.name}</p>
                  )}
                </div>

                <div>
                  <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Sort Order
                  </label>
                  <input
                    type="number"
                    name="sort_order"
                    value={formData.sort_order}
                    onChange={handleInputChange}
                    min="0"
                    className={`w-full px-3 py-2 rounded-lg bg-white/80 border ${
                      errors.sort_order ? 'border-rose-500/50' : 'border-gray-300/80'
                    } text-xs text-gray-900 placeholder:text-gray-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50`}
                    placeholder="0"
                  />
                  {errors.sort_order && (
                    <p className="text-xs text-rose-400 mt-1">{errors.sort_order}</p>
                  )}
                </div>
              </div>

              <div className="mt-4">
                <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Description *
                </label>
                <textarea
                  name="description"
                  value={formData.description}
                  onChange={handleInputChange}
                  rows={4}
                  className={`w-full px-3 py-2 rounded-lg bg-white/80 border ${
                    errors.description ? 'border-rose-500/50' : 'border-gray-300/80'
                  } text-xs text-gray-900 placeholder:text-gray-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50 resize-none`}
                  placeholder="Describe what type of content belongs in this category..."
                />
                {errors.description && (
                  <p className="text-xs text-rose-400 mt-1">{errors.description}</p>
                )}
              </div>
            </div>

            {/* Category Icon */}
            <div>
              <h3 className="text-sm font-semibold text-gray-800 dark:text-gray-200 mb-4 flex items-center gap-2">
                <Tag className="w-4 h-4 text-purple-400" />
                Category Icon
              </h3>

              <div className="flex items-start gap-4">
                <div className="flex-1">
                  <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Upload New Icon
                  </label>
                  <div className="relative">
                    <input
                      type="file"
                      accept="image/*"
                      onChange={handleIconSelect}
                      className="hidden"
                      id="icon-upload"
                    />
                    <label
                      htmlFor="icon-upload"
                      className={`flex items-center gap-2 px-4 py-2 rounded-lg border ${
                        errors.icon ? 'border-rose-500/50' : 'border-gray-300/80'
                      } bg-white/80 text-xs text-gray-700 hover:bg-gray-100/90 cursor-pointer transition-colors`}
                    >
                      <Upload className="w-4 h-4" />
                      Choose Image
                    </label>
                  </div>
                  {errors.icon && (
                    <p className="text-xs text-rose-400 mt-1">{errors.icon}</p>
                  )}
                  <p className="text-xs text-gray-500 mt-1">
                    Recommended: SquareIcon image, at least 256x256px. Max size: 5MB.
                  </p>
                </div>

                <div className="flex items-center gap-4">
                  {iconPreview ? (
                    <div className="relative group">
                      <img
                        src={iconPreview}
                        alt="Category icon preview"
                        className="w-16 h-16 rounded-xl object-cover border border-gray-300/80"
                      />
                      <button
                        type="button"
                        onClick={clearIcon}
                        className="absolute -top-2 -right-2 w-6 h-6 rounded-full bg-rose-500 text-white flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity"
                      >
                        <X className="w-3 h-3" />
                      </button>
                    </div>
                  ) : (
                    <div className="w-16 h-16 rounded-xl bg-gray-100/80 border border-gray-300/80 flex items-center justify-center">
                      <Tag className="w-6 h-6 text-gray-400" />
                    </div>
                  )}
                </div>
              </div>
            </div>

            {/* Status */}
            <div>
              <h3 className="text-sm font-semibold text-gray-800 dark:text-gray-200 mb-4 flex items-center gap-2">
                <Eye className="w-4 h-4 text-emerald-400" />
                Visibility Status
              </h3>

              <div className="flex items-center justify-between p-4 rounded-lg bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80">
                <div className="flex items-center gap-3">
                  <div className={`w-8 h-8 rounded-lg flex items-center justify-center ${
                    formData.is_active ? 'bg-emerald-500/20' : 'bg-rose-500/20'
                  }`}>
                    {formData.is_active ? (
                      <Eye className="w-4 h-4 text-emerald-400" />
                    ) : (
                      <EyeOff className="w-4 h-4 text-rose-400" />
                    )}
                  </div>
                  <div>
                    <p className="text-sm font-medium text-gray-800 dark:text-gray-200">
                      {formData.is_active ? 'Active' : 'Inactive'}
                    </p>
                    <p className="text-xs text-gray-600 dark:text-gray-400">
                      {formData.is_active
                        ? 'Category is visible to users and can be selected for content'
                        : 'Category is hidden from users and cannot be used for new content'}
                    </p>
                  </div>
                </div>

                <label className="relative inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    name="is_active"
                    checked={formData.is_active}
                    onChange={handleInputChange}
                    className="sr-only peer"
                  />
                  <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                </label>
              </div>
            </div>

            {/* Submit Button */}
            <div className="flex items-center justify-between pt-6 border-t border-gray-200/80">
              <Link
                href="/categories"
                className="px-4 py-2 rounded-lg bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-700 dark:text-gray-300 hover:bg-gray-100/90 transition-colors"
              >
                Cancel
              </Link>

              <button
                type="submit"
                disabled={saving || uploading}
                className="inline-flex items-center gap-2 px-6 py-2 rounded-xl bg-gradient-to-r from-blue-600 to-indigo-600 text-white text-xs font-medium hover:from-blue-700 hover:to-indigo-700 transition-all shadow-lg disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {saving || uploading ? (
                  <>
                    <Loader className="w-4 h-4 animate-spin" />
                    {uploading ? 'Uploading...' : 'Saving...'}
                  </>
                ) : (
                  <>
                    <Save className="w-4 h-4" />
                    Update Category
                  </>
                )}
              </button>
            </div>
          </form>
        </div>
      </div>
    </DashboardLayout>
  )
}

export default function EditCategoryPage() {
  return <CategoryEditContent />
}
'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { useParams, useRouter } from 'next/navigation'
import DashboardLayout from "@/components/dashboard-layout"
import {
  ArrowLeft,
  Save,
  Upload,
  X,
  BookOpen,
  FileText,
  Image,
  AlertTriangle,
  CheckCircle
} from 'lucide-react'
import { supabase } from "@/lib/supabase"

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

interface Category {
  id: string
  name: string
}

function EditBookContent() {
  const params = useParams()
  const router = useRouter()
  const [loading, setLoading] = useState(true)
  const [uploading, setUploading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [success, setSuccess] = useState(false)
  const [error, setError] = useState('')
  const [notFound, setNotFound] = useState(false)

  // Form state
  const [formData, setFormData] = useState({
    title: '',
    author: '',
    description: '',
    category_id: '',
    is_premium: false,
    is_active: true
  })

  // File states
  const [pdfFile, setPdfFile] = useState<File | null>(null)
  const [thumbnailFile, setThumbnailFile] = useState<File | null>(null)
  const [pdfPreview, setPdfPreview] = useState<string>('')
  const [thumbnailPreview, setThumbnailPreview] = useState<string>('')
  const [originalPdfUrl, setOriginalPdfUrl] = useState<string>('')
  const [originalThumbnailUrl, setOriginalThumbnailUrl] = useState<string>('')

  useEffect(() => {
    if (params.id) {
      fetchBook(params.id as string)
      fetchCategories()
    }
  }, [params.id])

  const fetchBook = async (id: string) => {
    try {
      setLoading(true)
      const { data, error } = await supabase
        .from('ebooks')
        .select('*')
        .eq('id', id)
        .single()

      if (error) {
        if (error.code === 'PGRST116') {
          setNotFound(true)
        } else {
          throw error
        }
        return
      }

      const book = data as Book
      setFormData({
        title: book.title,
        author: book.author,
        description: book.description,
        category_id: book.category_id,
        is_premium: book.is_premium,
        is_active: book.is_active
      })
      setOriginalPdfUrl(book.pdf_url)
      setOriginalThumbnailUrl(book.thumbnail_url)

      if (book.pdf_url) {
        setPdfPreview(book.pdf_url)
      }
      if (book.thumbnail_url) {
        setThumbnailPreview(book.thumbnail_url)
      }

    } catch (error) {
      console.error('Error fetching book:', error)
      setError('Failed to load book details')
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

      if (error) throw error
      // Store categories for use in form
      window.categories = data || []
    } catch (error) {
      console.error('Error fetching categories:', error)
    }
  }

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    const { name, value, type } = e.target
    setFormData(prev => ({
      ...prev,
      [name]: type === 'checkbox' ? (e.target as HTMLInputElement).checked : value
    }))
    setError('')
    setSuccess(false)
  }

  const handlePdfChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) {
      if (file.type === 'application/pdf') {
        setPdfFile(file)
        setPdfPreview(file.name)
        setError('')
      } else {
        setError('Please upload a PDF file')
      }
    }
  }

  const handleThumbnailChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) {
      if (file.type.startsWith('image/')) {
        setThumbnailFile(file)
        const reader = new FileReader()
        reader.onloadend = () => {
          setThumbnailPreview(reader.result as string)
        }
        reader.readAsDataURL(file)
        setError('')
      } else {
        setError('Please upload an image file')
      }
    }
  }

  const removePdf = () => {
    setPdfFile(null)
    setPdfPreview('')
  }

  const removeThumbnail = () => {
    setThumbnailFile(null)
    setThumbnailPreview('')
  }

  const uploadFile = async (file: File, path: string) => {
    const fileExt = file.name.split('.').pop()
    const fileName = `${Date.now()}.${fileExt}`
    const filePath = `${path}/${fileName}`

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

    if (!formData.title || !formData.author || !formData.category_id) {
      setError('Please fill in all required fields')
      return
    }

    setSaving(true)
    setError('')
    setSuccess(false)

    try {
      let pdfUrl = originalPdfUrl
      let thumbnailUrl = originalThumbnailUrl

      // Upload new PDF if provided
      if (pdfFile) {
        setUploading(true)
        pdfUrl = await uploadFile(pdfFile, 'pdfs')

        // Delete old PDF if it exists
        if (originalPdfUrl) {
          const oldPath = originalPdfUrl.split('/').pop()
          if (oldPath) {
            await supabase.storage
              .from('book-files')
              .remove([`pdfs/${oldPath}`])
          }
        }
      }

      // Upload new thumbnail if provided
      if (thumbnailFile) {
        setUploading(true)
        thumbnailUrl = await uploadFile(thumbnailFile, 'thumbnails')

        // Delete old thumbnail if it exists
        if (originalThumbnailUrl) {
          const oldPath = originalThumbnailUrl.split('/').pop()
          if (oldPath) {
            await supabase.storage
              .from('book-files')
              .remove([`thumbnails/${oldPath}`])
          }
        }
      }

      // Update book data
      const { error } = await supabase
        .from('ebooks')
        .update({
          ...formData,
          pdf_url: pdfUrl,
          thumbnail_url: thumbnailUrl,
          updated_at: new Date().toISOString()
        })
        .eq('id', params.id)

      if (error) throw error

      setSuccess(true)

      // Redirect after 2 seconds
      setTimeout(() => {
        router.push('/books')
      }, 2000)

    } catch (error) {
      console.error('Error updating book:', error)
      setError('Error updating book. Please try again.')
    } finally {
      setSaving(false)
      setUploading(false)
    }
  }

  if (notFound) {
    return (
      <DashboardLayout title="Book Not Found" subtitle="Error">
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="card rounded-2xl p-8 text-center max-w-md">
            <AlertTriangle className="w-16 h-16 text-rose-400 mx-auto mb-4" />
            <h2 className="text-xl font-bold text-gray-900 mb-2">Book Not Found</h2>
            <p className="text-gray-600 dark:text-gray-400 mb-6">The book you're looking for doesn't exist or has been deleted.</p>
            <Link
              href="/books"
              className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-gradient-to-r from-blue-600 to-indigo-600 text-white text-xs font-medium hover:from-blue-700 hover:to-indigo-700 transition-all shadow-lg"
            >
              <ArrowLeft className="w-4 h-4" />
              Back to Books
            </Link>
          </div>
        </div>
      </DashboardLayout>
    )
  }

  if (loading) {
    return (
      <DashboardLayout title="Edit Book" subtitle="Loading...">
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="w-8 h-8 border-2 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
        </div>
      </DashboardLayout>
    )
  }

  return (
    <DashboardLayout title="Edit Book" subtitle="Update book information and files">
      <div className="px-4 sm:px-6 py-4">
        {/* Page Header */}
        <div className="card rounded-2xl p-4 sm:p-5 mb-4">
          <div className="flex items-center gap-3 mb-4">
            <Link href="/books" className="p-2 rounded-xl bg-white/90 border border-gray-300/80 hover:bg-gray-100/90 transition">
              <ArrowLeft className="w-4 h-4 text-gray-700" />
            </Link>
            <div>
              <h2 className="text-base sm:text-lg font-semibold">Edit Book</h2>
              <p className="text-xs text-gray-600 dark:text-gray-400">Update book information and files</p>
            </div>
          </div>

          {/* Success/Error Messages */}
          {success && (
            <div className="flex items-center gap-3 p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/40">
              <CheckCircle className="w-4 h-4 text-emerald-400" />
              <span className="text-sm text-emerald-300">Book updated successfully! Redirecting...</span>
            </div>
          )}

          {error && (
            <div className="flex items-center gap-3 p-3 rounded-xl bg-rose-500/10 border border-rose-500/40">
              <AlertTriangle className="w-4 h-4 text-rose-400" />
              <span className="text-sm text-rose-300">{error}</span>
            </div>
          )}
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="card rounded-2xl p-4 sm:p-5">
          <div className="space-y-6">
            {/* Basic Information */}
            <div>
              <h3 className="text-sm font-semibold mb-4 flex items-center gap-2">
                <BookOpen className="w-4 h-4 text-blue-400" />
                Basic Information
              </h3>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-[11px] font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Title *
                  </label>
                  <input
                    type="text"
                    name="title"
                    value={formData.title}
                    onChange={handleInputChange}
                    className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
                    placeholder="Enter book title"
                    required
                  />
                </div>
                <div>
                  <label className="block text-[11px] font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Author *
                  </label>
                  <input
                    type="text"
                    name="author"
                    value={formData.author}
                    onChange={handleInputChange}
                    className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
                    placeholder="Enter author name"
                    required
                  />
                </div>
                <div className="md:col-span-2">
                  <label className="block text-[11px] font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Description
                  </label>
                  <textarea
                    name="description"
                    value={formData.description}
                    onChange={handleInputChange}
                    rows={3}
                    className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50 resize-none"
                    placeholder="Enter book description"
                  />
                </div>
                <div>
                  <label className="block text-[11px] font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Category *
                  </label>
                  <select
                    name="category_id"
                    value={formData.category_id}
                    onChange={handleInputChange}
                    className="w-full px-3 py-2 rounded-xl bg-white/80 border border-gray-300/80 text-xs text-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
                    required
                  >
                    <option value="">Select a category</option>
                    {window.categories?.map((category: Category) => (
                      <option key={category.id} value={category.id}>
                        {category.name}
                      </option>
                    ))}
                  </select>
                </div>
              </div>
            </div>

            {/* Settings */}
            <div>
              <h3 className="text-sm font-semibold mb-4 flex items-center gap-2">
                <FileText className="w-4 h-4 text-green-400" />
                Book Settings
              </h3>
              <div className="space-y-3">
                <label className="flex items-center gap-3 cursor-pointer">
                  <input
                    type="checkbox"
                    name="is_premium"
                    checked={formData.is_premium}
                    onChange={handleInputChange}
                    className="w-4 h-4 rounded bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
                  />
                  <div>
                    <span className="text-xs font-medium text-gray-800 dark:text-gray-200">Premium Book</span>
                    <p className="text-[10px] text-gray-600 dark:text-gray-400">Requires paid subscription to access</p>
                  </div>
                </label>
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
                    <p className="text-[10px] text-gray-600 dark:text-gray-400">Book is visible to users</p>
                  </div>
                </label>
              </div>
            </div>

            {/* File Uploads */}
            <div>
              <h3 className="text-sm font-semibold mb-4 flex items-center gap-2">
                <Upload className="w-4 h-4 text-purple-400" />
                File Uploads
              </h3>

              {/* PDF Upload */}
              <div className="mb-4">
                <label className="block text-[11px] font-medium text-gray-700 dark:text-gray-300 mb-2">
                  PDF File
                </label>
                <div className="border-2 border-dashed border-gray-300/80 rounded-xl p-4">
                  {pdfPreview ? (
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-xl bg-white flex items-center justify-center">
                          <FileText className="w-5 h-5 text-blue-400" />
                        </div>
                        <div>
                          <p className="text-xs font-medium text-gray-800 dark:text-gray-200">{pdfPreview}</p>
                          <p className="text-[10px] text-gray-600 dark:text-gray-400">PDF file</p>
                        </div>
                      </div>
                      <button
                        type="button"
                        onClick={removePdf}
                        className="p-1.5 rounded-lg bg-rose-600/20 border border-rose-500/40 text-rose-300 hover:bg-rose-600/30"
                      >
                        <X className="w-4 h-4" />
                      </button>
                    </div>
                  ) : (
                    <div className="text-center">
                      <input
                        type="file"
                        accept=".pdf"
                        onChange={handlePdfChange}
                        className="hidden"
                        id="pdf-upload"
                      />
                      <label
                        htmlFor="pdf-upload"
                        className="cursor-pointer inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-white/80 border border-gray-300/80 text-xs text-gray-700 hover:bg-gray-100/90 transition"
                      >
                        <Upload className="w-4 h-4" />
                        {originalPdfUrl ? 'Replace PDF File' : 'Choose PDF File'}
                      </label>
                      <p className="text-[10px] text-gray-500 mt-2">
                        Upload PDF format only (Max 10MB)
                      </p>
                    </div>
                  )}
                </div>
              </div>

              {/* Thumbnail Upload */}
              <div>
                <label className="block text-[11px] font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Thumbnail Image
                </label>
                <div className="border-2 border-dashed border-gray-300/80 rounded-xl p-4">
                  {thumbnailPreview ? (
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        <div className="w-16 h-16 rounded-xl overflow-hidden">
                          <img
                            src={thumbnailPreview}
                            alt="Thumbnail preview"
                            className="w-full h-full object-cover"
                          />
                        </div>
                        <div>
                          <p className="text-xs font-medium text-gray-800 dark:text-gray-200">Thumbnail uploaded</p>
                          <p className="text-[10px] text-gray-600 dark:text-gray-400">Image file</p>
                        </div>
                      </div>
                      <button
                        type="button"
                        onClick={removeThumbnail}
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
                        onChange={handleThumbnailChange}
                        className="hidden"
                        id="thumbnail-upload"
                      />
                      <label
                        htmlFor="thumbnail-upload"
                        className="cursor-pointer inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-white/80 border border-gray-300/80 text-xs text-gray-700 hover:bg-gray-100/90 transition"
                      >
                        <Image className="w-4 h-4" />
                        {originalThumbnailUrl ? 'Replace Thumbnail' : 'Choose Thumbnail'}
                      </label>
                      <p className="text-[10px] text-gray-500 mt-2">
                        Upload JPG, PNG or GIF (Max 2MB)
                      </p>
                    </div>
                  )}
                </div>
              </div>
            </div>

            {/* Actions */}
            <div className="flex items-center justify-end gap-3 pt-4 border-t border-gray-200/80">
              <Link
                href="/books"
                className="px-4 py-2 rounded-xl bg-white/80 border border-gray-300/80 text-xs text-gray-700 hover:bg-gray-100/90 transition"
              >
                Cancel
              </Link>
              <button
                type="submit"
                disabled={saving || uploading}
                className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-gradient-to-r from-blue-600 to-indigo-600 text-white text-xs font-medium hover:from-blue-700 hover:to-indigo-700 transition-all shadow-lg disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {saving || uploading ? (
                  <>
                    <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                    {uploading ? 'Uploading...' : 'Saving...'}
                  </>
                ) : (
                  <>
                    <Save className="w-4 h-4" />
                    Update Book
                  </>
                )}
              </button>
            </div>
          </div>
        </form>
      </div>
    </DashboardLayout>
  )
}

export default function EditBookPage() {
  return <EditBookContent />
}
'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import QueryProvider from "@/components/query-provider"
import Sidebar from "@/components/sidebar"
import Header from "@/components/header"
import {
  ArrowLeft,
  Upload,
  Save,
  X,
  BookOpen,
  FileText,
  Image
} from "lucide-react"
import { supabase } from "@/lib/supabase"

interface Category {
  id: string
  name: string
}

function NewBookContent() {
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)
  const [categories, setCategories] = useState<Category[]>([])
  const [loading, setLoading] = useState(false)
  const [uploading, setUploading] = useState(false)
  const [uploadProgress, setUploadProgress] = useState(0)

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

  useEffect(() => {
    fetchCategories()
  }, [])

  const fetchCategories = async () => {
    try {
      const { data, error } = await supabase
        .from('categories')
        .select('id, name')
        .order('name')

      if (error) throw error
      setCategories(data || [])
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
  }

  const handlePdfChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) {
      if (file.type === 'application/pdf') {
        setPdfFile(file)
        setPdfPreview(file.name)
      } else {
        alert('Please upload a PDF file')
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
      } else {
        alert('Please upload an image file')
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

  const uploadFile = async (file: File, path: string, onProgress?: (progress: number) => void) => {
    const fileExt = file.name.split('.').pop()
    const fileName = `${Date.now()}.${fileExt}`
    const filePath = `${path}/${fileName}`

    // Add progress tracking for large files
    if (onProgress) {
      onProgress(0)
    }

    try {
      const { error: uploadError, data } = await supabase.storage
        .from('book-files')
        .upload(filePath, file, {
          cacheControl: '3600',
          upsert: false
        })

      if (onProgress) {
        onProgress(100)
      }

      if (uploadError) throw uploadError

      const { data: publicUrlData } = supabase.storage
        .from('book-files')
        .getPublicUrl(filePath)

      return publicUrlData.publicUrl
    } catch (error) {
      console.error(`Upload failed for ${file.name}:`, error)
      throw error
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    console.log('=== FORM SUBMISSION DEBUG ===');
    console.log('Form data:', formData);
    console.log('PDF file:', pdfFile ? pdfFile.name : 'No PDF file');
    console.log('Thumbnail file:', thumbnailFile ? thumbnailFile.name : 'No thumbnail file');

    if (!formData.title || !formData.author || !formData.category_id) {
      console.error('Validation failed - missing required fields');
      alert('Please fill in all required fields')
      return
    }

    setLoading(true)

    try {
      let pdfUrl = ''
      let thumbnailUrl = ''

      console.log('Starting file uploads...');
      setUploading(true)
      setUploadProgress(0)

      // Upload files in parallel for better performance
      const uploadPromises: Promise<any>[] = []

      if (pdfFile) {
        console.log('Preparing PDF upload:', pdfFile.name);
        const pdfUploadPromise = uploadFile(pdfFile, 'pdfs', (progress) => {
          setUploadProgress(progress)
        }).then(url => {
          pdfUrl = url
          console.log('PDF uploaded successfully:', url);
        })
        uploadPromises.push(pdfUploadPromise)
      }

      if (thumbnailFile) {
        console.log('Preparing thumbnail upload:', thumbnailFile.name);
        const thumbnailUploadPromise = uploadFile(thumbnailFile, 'thumbnails').then(url => {
          thumbnailUrl = url
          console.log('Thumbnail uploaded successfully:', url);
        })
        uploadPromises.push(thumbnailUploadPromise)
      }

      // Wait for all uploads to complete
      await Promise.all(uploadPromises)
      setUploading(false)
      setUploadProgress(100)

      console.log('All uploads completed. Preparing book data...');

      // Prepare book data
      const bookData = {
        title: formData.title.trim(),
        author: formData.author.trim(),
        description: formData.description?.trim() || '',
        category_id: formData.category_id,
        pdf_url: pdfUrl,
        thumbnail_url: thumbnailUrl,
        total_pages: null, // Will be updated later - must be NULL or > 0
        is_premium: formData.is_premium,
        is_active: formData.is_active
      };

      console.log('Book data to insert:', bookData);

      console.log('Inserting book into database...');

      // Optimized database insert
      const startTime = performance.now()
      const { data, error } = await supabase
        .from('ebooks')
        .insert(bookData)
        .select('id, title')
        .single()

      const dbTime = performance.now() - startTime
      console.log(`Database insert took ${dbTime.toFixed(2)}ms`);

      if (error) {
        console.error('=== SUPABASE INSERT ERROR ===');
        console.error('Full error object:', error);
        console.error('Error message:', error.message);
        console.error('Error details:', error.details);
        console.error('Error hint:', error.hint);
        console.error('Error code:', error.code);

        alert(`Database error: ${error.message || 'Unknown database error'}`);
        throw new Error(`Database error: ${error.message || 'Unknown database error'}`);
      }

      if (!data) {
        console.error('No data returned from insert operation');
        throw new Error('Book was created but no data was returned');
      }

      console.log('=== BOOK CREATED SUCCESSFULLY ===');
      console.log('Book data:', data);

      // Show success message and redirect
      alert('Book created successfully!')

      // Use immediate redirect instead of window.location.href
      window.location.replace('/books')
    } catch (error) {
      console.error('=== CATCH BLOCK ERROR ===');
      console.error('Full error object:', error);
      console.error('Error message:', error instanceof Error ? error.message : 'Unknown error');
      console.error('Error stack:', error instanceof Error ? error.stack : 'No stack trace');

      alert(`Error creating book: ${error instanceof Error ? error.message : 'Unknown error occurred'}. Please try again.`);
    } finally {
      setLoading(false)
      setUploading(false)
      setUploadProgress(0)
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
          title="Add New Book"
          subtitle="Content Management"
        />

        {/* Main Content */}
        <main className="flex-1 px-4 sm:px-6 pb-8 pt-4 bg-gradient-to-br from-slate-950 via-slate-950 to-slate-900">
          <div className="max-w-4xl mx-auto">
            {/* Page Header */}
            <div className="card rounded-2xl p-4 sm:p-5 mb-4">
              <div className="flex items-center gap-3 mb-4">
                <Link href="/books" className="p-2 rounded-xl bg-slate-900/90 border border-slate-700/80 hover:bg-slate-800/90 transition">
                  <ArrowLeft className="w-4 h-4 text-slate-300" />
                </Link>
                <div>
                  <h2 className="text-base sm:text-lg font-semibold">Add New Book</h2>
                  <p className="text-xs text-slate-400">Create a new ebook entry</p>
                </div>
              </div>
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
                      <label className="block text-[11px] font-medium text-slate-300 mb-2">
                        Title *
                      </label>
                      <input
                        type="text"
                        name="title"
                        value={formData.title}
                        onChange={handleInputChange}
                        className="w-full px-3 py-2 rounded-xl bg-slate-900/80 border border-slate-700/80 text-xs text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
                        placeholder="Enter book title"
                        required
                      />
                    </div>
                    <div>
                      <label className="block text-[11px] font-medium text-slate-300 mb-2">
                        Author *
                      </label>
                      <input
                        type="text"
                        name="author"
                        value={formData.author}
                        onChange={handleInputChange}
                        className="w-full px-3 py-2 rounded-xl bg-slate-900/80 border border-slate-700/80 text-xs text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
                        placeholder="Enter author name"
                        required
                      />
                    </div>
                    <div className="md:col-span-2">
                      <label className="block text-[11px] font-medium text-slate-300 mb-2">
                        Description
                      </label>
                      <textarea
                        name="description"
                        value={formData.description}
                        onChange={handleInputChange}
                        rows={3}
                        className="w-full px-3 py-2 rounded-xl bg-slate-900/80 border border-slate-700/80 text-xs text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50 resize-none"
                        placeholder="Enter book description"
                      />
                    </div>
                    <div>
                      <label className="block text-[11px] font-medium text-slate-300 mb-2">
                        Category *
                      </label>
                      <select
                        name="category_id"
                        value={formData.category_id}
                        onChange={handleInputChange}
                        className="w-full px-3 py-2 rounded-xl bg-slate-900/80 border border-slate-700/80 text-xs text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500/50"
                        required
                      >
                        <option value="">Select a category</option>
                        {categories.map((category) => (
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
                        className="w-4 h-4 rounded bg-slate-900 border border-slate-700 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
                      />
                      <div>
                        <span className="text-xs font-medium text-slate-200">Premium Book</span>
                        <p className="text-[10px] text-slate-400">Requires paid subscription to access</p>
                      </div>
                    </label>
                    <label className="flex items-center gap-3 cursor-pointer">
                      <input
                        type="checkbox"
                        name="is_active"
                        checked={formData.is_active}
                        onChange={handleInputChange}
                        className="w-4 h-4 rounded bg-slate-900 border border-slate-700 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
                      />
                      <div>
                        <span className="text-xs font-medium text-slate-200">Active</span>
                        <p className="text-[10px] text-slate-400">Book is visible to users</p>
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
                    <label className="block text-[11px] font-medium text-slate-300 mb-2">
                      PDF File
                    </label>
                    <div className="border-2 border-dashed border-slate-700/80 rounded-xl p-4">
                      {pdfPreview ? (
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-3">
                            <div className="w-10 h-10 rounded-xl bg-slate-900 flex items-center justify-center">
                              <FileText className="w-5 h-5 text-blue-400" />
                            </div>
                            <div>
                              <p className="text-xs font-medium text-slate-200">{pdfPreview}</p>
                              <p className="text-[10px] text-slate-400">PDF file</p>
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
                            className="cursor-pointer inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-slate-900/80 border border-slate-700/80 text-xs text-slate-300 hover:bg-slate-800/90 transition"
                          >
                            <Upload className="w-4 h-4" />
                            Choose PDF File
                          </label>
                          <p className="text-[10px] text-slate-500 mt-2">
                            Upload PDF format only (Max 10MB)
                          </p>
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Thumbnail Upload */}
                  <div>
                    <label className="block text-[11px] font-medium text-slate-300 mb-2">
                      Thumbnail Image
                    </label>
                    <div className="border-2 border-dashed border-slate-700/80 rounded-xl p-4">
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
                              <p className="text-xs font-medium text-slate-200">Thumbnail uploaded</p>
                              <p className="text-[10px] text-slate-400">Image file</p>
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
                            className="cursor-pointer inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-slate-900/80 border border-slate-700/80 text-xs text-slate-300 hover:bg-slate-800/90 transition"
                          >
                            <Image className="w-4 h-4" />
                            Choose Thumbnail
                          </label>
                          <p className="text-[10px] text-slate-500 mt-2">
                            Upload JPG, PNG or GIF (Max 2MB)
                          </p>
                        </div>
                      )}
                    </div>
                  </div>
                </div>

                {/* Upload Progress */}
                {(uploading || uploadProgress > 0) && (
                  <div className="mb-4">
                    <div className="flex items-center justify-between mb-2">
                      <span className="text-xs text-slate-300">
                        {uploading ? 'Uploading files...' : 'Upload complete'}
                      </span>
                      <span className="text-xs text-slate-400">
                        {uploadProgress}%
                      </span>
                    </div>
                    <div className="w-full bg-slate-700/50 rounded-full h-2">
                      <div
                        className="bg-gradient-to-r from-blue-500 to-emerald-500 h-2 rounded-full transition-all duration-300 ease-out"
                        style={{ width: `${uploadProgress}%` }}
                      ></div>
                    </div>
                  </div>
                )}

                {/* Actions */}
                <div className="flex items-center justify-end gap-3 pt-4 border-t border-slate-800/80">
                  <Link
                    href="/books"
                    className="px-4 py-2 rounded-xl bg-slate-900/80 border border-slate-700/80 text-xs text-slate-300 hover:bg-slate-800/90 transition"
                  >
                    Cancel
                  </Link>
                  <button
                    type="submit"
                    disabled={loading || uploading}
                    className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-gradient-to-r from-green-600 to-emerald-600 text-white text-xs font-medium hover:from-green-700 hover:to-emerald-700 transition-all shadow-lg disabled:opacity-50 disabled:cursor-not-allowed min-w-[120px]"
                  >
                    {loading || uploading ? (
                      <>
                        <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                        <span className="text-center">
                          {uploading
                            ? `Uploading${uploadProgress > 0 ? ` ${uploadProgress}%` : '...'}`
                            : 'Saving...'
                          }
                        </span>
                      </>
                    ) : (
                      <>
                        <Save className="w-4 h-4" />
                        Create Book
                      </>
                    )}
                  </button>
                </div>
              </div>
            </form>
          </div>
        </main>
      </div>
    </div>
  )
}

export default function NewBookPage() {
  return (
    <QueryProvider>
      <NewBookContent />
    </QueryProvider>
  )
}
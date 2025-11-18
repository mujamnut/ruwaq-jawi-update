'use client'

import { useState, useEffect } from 'react'

// Type declaration for window.categories
declare global {
  interface Window {
    categories?: any[]
  }
}
import Link from 'next/link'
import { useParams, useRouter } from 'next/navigation'
import DashboardLayout from "@/components/dashboard-layout"
import {
  ArrowLeft,
  Save,
  Upload,
  X,
  Video,
  Clock,
  AlertTriangle,
  CheckCircle
} from 'lucide-react'
import { supabase } from "@/lib/supabase"

interface VideoKitab {
  id: string
  title: string
  description: string
  category_id: string
  thumbnail_url: string
  youtube_playlist_url: string
  duration: number
  is_premium: boolean
  is_active: boolean
  created_at: string
  updated_at: string
}

interface Category {
  id: string
  name: string
}

function EditVideoContent() {
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
    description: '',
    category_id: '',
    video_url: '',
    duration: 0,
    is_premium: false,
    is_active: true
  })

  // File state
  const [thumbnailFile, setThumbnailFile] = useState<File | null>(null)
  const [thumbnailPreview, setThumbnailPreview] = useState<string>('')
  const [originalThumbnailUrl, setOriginalThumbnailUrl] = useState<string>('')

  useEffect(() => {
    if (params.id) {
      fetchVideo(params.id as string)
      fetchCategories()
    }
  }, [params.id])

  const fetchVideo = async (id: string) => {
    try {
      setLoading(true)
      const { data, error } = await supabase
        .from('video_kitab')
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

      const video = data as VideoKitab
      setFormData({
        title: video.title,
        description: video.description,
        category_id: video.category_id,
        video_url: video.youtube_playlist_url,
        duration: video.duration || 0,
        is_premium: video.is_premium,
        is_active: video.is_active
      })
      setOriginalThumbnailUrl(video.thumbnail_url)

      if (video.thumbnail_url) {
        setThumbnailPreview(video.thumbnail_url)
      }

    } catch (error) {
      console.error('Error fetching video:', error)
      setError('Failed to load video details')
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

  const removeThumbnail = () => {
    setThumbnailFile(null)
    setThumbnailPreview('')
  }

  const uploadThumbnail = async (file: File) => {
    const fileExt = file.name.split('.').pop()
    const fileName = `${Date.now()}.${fileExt}`
    const filePath = `video-thumbnails/${fileName}`

    const { error: uploadError } = await supabase.storage
      .from('book-files')
      .upload(filePath, file)

    if (uploadError) throw uploadError

    const { data } = supabase.storage
      .from('book-files')
      .getPublicUrl(filePath)

    return data.publicUrl
  }

  const getVideoIdFromUrl = (url: string) => {
    // Handle YouTube URLs
    const youtubeRegex = /(?:youtube\.com\/(?:embed\/|watch\?v=|shorts\/))([^&\n?#]+)/
    const match = url.match(youtubeRegex)
    return match ? match[1] : null
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    if (!formData.title || !formData.category_id) {
      setError('Please fill in all required fields')
      return
    }

    setSaving(true)
    setError('')
    setSuccess(false)

    try {
      let thumbnailUrl = originalThumbnailUrl
      let videoId = formData.video_url ? getVideoIdFromUrl(formData.video_url) : null

      // Upload new thumbnail if provided
      if (thumbnailFile) {
        setUploading(true)
        thumbnailUrl = await uploadThumbnail(thumbnailFile)

        // Delete old thumbnail if it exists
        if (originalThumbnailUrl) {
          const oldPath = originalThumbnailUrl.split('/').pop()
          if (oldPath) {
            await supabase.storage
              .from('book-files')
              .remove([`video-thumbnails/${oldPath}`])
          }
        }
      }

      // Update video data - only include fields that should be updated
      const updateData: any = {
        title: formData.title,
        description: formData.description,
        category_id: formData.category_id,
        youtube_playlist_url: formData.video_url,
        duration: formData.duration || 0,
        is_premium: formData.is_premium,
        is_active: formData.is_active,
        updated_at: new Date().toISOString()
      }

      // Only add video_id if it exists (extracted from YouTube URL)
      if (videoId) {
        updateData.video_id = videoId
      }

      // Only add thumbnail_url if it changed
      if (thumbnailUrl !== originalThumbnailUrl) {
        updateData.thumbnail_url = thumbnailUrl
      }

      const { error } = await supabase
        .from('video_kitab')
        .update(updateData)
        .eq('id', params.id)

      if (error) throw error

      setSuccess(true)

      // Redirect after 2 seconds
      setTimeout(() => {
        router.push('/videos')
      }, 2000)

    } catch (error) {
      console.error('Error updating video:', error)

      // Log detailed error information
      if (error instanceof Error) {
        console.error('Error message:', error.message)
        console.error('Error stack:', error.stack)
      }

      // Log Supabase-specific error if available
      if (typeof error === 'object' && error !== null) {
        console.error('Supabase error:', JSON.stringify(error, null, 2))
      }

      setError(`Error updating video: ${error instanceof Error ? error.message : 'Unknown error'}`)
    } finally {
      setSaving(false)
      setUploading(false)
    }
  }

  if (notFound) {
    return (
      <DashboardLayout title="Video Not Found" subtitle="Error">
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="card rounded-2xl p-8 text-center max-w-md">
            <AlertTriangle className="w-16 h-16 text-rose-400 mx-auto mb-4" />
            <h2 className="text-xl font-bold text-gray-900 mb-2">Video Not Found</h2>
            <p className="text-gray-600 dark:text-gray-400 mb-6">The video you're looking for doesn't exist or has been deleted.</p>
            <Link
              href="/videos"
              className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-gradient-to-r from-purple-600 to-pink-600 text-white text-xs font-medium hover:from-purple-700 hover:to-pink-700 transition-all shadow-lg"
            >
              <ArrowLeft className="w-4 h-4" />
              Back to Videos
            </Link>
          </div>
        </div>
      </DashboardLayout>
    )
  }

  if (loading) {
    return (
      <DashboardLayout title="Edit Video" subtitle="Loading...">
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="w-8 h-8 border-2 border-purple-500 border-t-transparent rounded-full animate-spin"></div>
        </div>
      </DashboardLayout>
    )
  }

  return (
    <DashboardLayout title="Edit Video Kitab" subtitle="Video Content">
      <div className="px-4 sm:px-6 py-4">
                {/* Page Header */}
                <div className="card rounded-2xl p-4 sm:p-5 mb-4">
                  <div className="flex items-center gap-3 mb-4">
                    <Link href="/videos" className="p-2 rounded-xl bg-white/90 border border-gray-300/80 hover:bg-gray-100/90 transition">
                      <ArrowLeft className="w-4 h-4 text-gray-700" />
                    </Link>
                    <div>
                      <h2 className="text-base sm:text-lg font-semibold">Edit Video Kitab</h2>
                      <p className="text-xs text-gray-600 dark:text-gray-400">Update video information and details</p>
                    </div>
                  </div>

                  {/* Success/Error Messages */}
                  {success && (
                    <div className="flex items-center gap-3 p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/40">
                      <CheckCircle className="w-4 h-4 text-emerald-400" />
                      <span className="text-sm text-emerald-300">Video updated successfully! Redirecting...</span>
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
                        <Video className="w-4 h-4 text-purple-400" />
                        Video Information
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
                            className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-purple-500/50 focus:border-purple-500/50"
                            placeholder="Enter video title"
                            required
                          />
                        </div>
                          <div className="md:col-span-2">
                          <label className="block text-[11px] font-medium text-gray-700 dark:text-gray-300 mb-2">
                            YouTube URL
                          </label>
                          <input
                            type="url"
                            name="video_url"
                            value={formData.video_url}
                            onChange={handleInputChange}
                            className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-purple-500/50 focus:border-purple-500/50"
                            placeholder="https://youtube.com/watch?v=..."
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
                            className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-purple-500/50 focus:border-purple-500/50 resize-none"
                            placeholder="Enter video description"
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
                            className="w-full px-3 py-2 rounded-xl bg-white/80 border border-gray-300/80 text-xs text-gray-900 focus:outline-none focus:ring-2 focus:ring-purple-500/50 focus:border-purple-500/50"
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

                    {/* Video Settings */}
                    <div>
                      <h3 className="text-sm font-semibold mb-4 flex items-center gap-2">
                        <Clock className="w-4 h-4 text-amber-400" />
                        Video Settings
                      </h3>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div>
                          <label className="block text-[11px] font-medium text-gray-700 dark:text-gray-300 mb-2">
                            Duration (seconds)
                          </label>
                          <input
                            type="number"
                            name="duration"
                            value={formData.duration}
                            onChange={handleInputChange}
                            min="0"
                            className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-amber-500/50 focus:border-amber-500/50"
                            placeholder="0"
                          />
                        </div>
                        <div className="space-y-3">
                          <label className="flex items-center gap-3 cursor-pointer">
                            <input
                              type="checkbox"
                              name="is_premium"
                              checked={formData.is_premium}
                              onChange={handleInputChange}
                              className="w-4 h-4 rounded bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-purple-500 focus:ring-2 focus:ring-purple-500/50"
                            />
                            <div>
                              <span className="text-xs font-medium text-gray-800 dark:text-gray-200">Premium Video</span>
                              <p className="text-[10px] text-gray-600 dark:text-gray-400">Requires paid subscription</p>
                            </div>
                          </label>
                          <label className="flex items-center gap-3 cursor-pointer">
                            <input
                              type="checkbox"
                              name="is_active"
                              checked={formData.is_active}
                              onChange={handleInputChange}
                              className="w-4 h-4 rounded bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-purple-500 focus:ring-2 focus:ring-purple-500/50"
                            />
                            <div>
                              <span className="text-xs font-medium text-gray-800 dark:text-gray-200">Active</span>
                              <p className="text-[10px] text-gray-600 dark:text-gray-400">Video is visible to users</p>
                            </div>
                          </label>
                        </div>
                      </div>
                    </div>

                    {/* Thumbnail Upload */}
                    <div>
                      <h3 className="text-sm font-semibold mb-4 flex items-center gap-2">
                        <Upload className="w-4 h-4 text-indigo-400" />
                        Video Thumbnail
                      </h3>
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
                              <Upload className="w-4 h-4" />
                              Choose Thumbnail
                            </label>
                            <p className="text-[10px] text-gray-500 mt-2">
                              Upload JPG, PNG or GIF (Max 2MB)
                            </p>
                            <p className="text-[10px] text-gray-400 mt-1">
                              Optional - Used for video preview
                            </p>
                          </div>
                        )}
                      </div>
                    </div>

                    {/* Actions */}
                    <div className="flex items-center justify-end gap-3 pt-4 border-t border-gray-200/80">
                      <Link
                        href="/videos"
                        className="px-4 py-2 rounded-xl bg-white/80 border border-gray-300/80 text-xs text-gray-700 hover:bg-gray-100/90 transition"
                      >
                        Cancel
                      </Link>
                      <button
                        type="submit"
                        disabled={saving || uploading}
                        className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-gradient-to-r from-purple-600 to-pink-600 text-white text-xs font-medium hover:from-purple-700 hover:to-pink-700 transition-all shadow-lg disabled:opacity-50 disabled:cursor-not-allowed"
                      >
                        {saving || uploading ? (
                          <>
                            <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                            {uploading ? 'Uploading...' : 'Saving...'}
                          </>
                        ) : (
                          <>
                            <Save className="w-4 h-4" />
                            Update Video
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

export default function EditVideoPage() {
  return <EditVideoContent />
}
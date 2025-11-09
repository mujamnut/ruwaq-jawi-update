'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import QueryProvider from "@/components/query-provider"
import Sidebar from "@/components/sidebar"
import Header from "@/components/header"
import {
  ArrowLeft,
  Save,
  Play,
  Upload,
  X,
  Video,
  Image,
  Clock,
  User
} from "lucide-react"
import { supabase } from "@/lib/supabase"

interface Category {
  id: string
  name: string
}

function NewVideoContent() {
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)
  const [categories, setCategories] = useState<Category[]>([])
  const [loading, setLoading] = useState(false)
  const [uploading, setUploading] = useState(false)
  const [uploadProgress, setUploadProgress] = useState(0)

  // Form state
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    category_id: '',
    video_url: '',
    duration_hours: '',
    duration_minutes: '',
    duration_seconds: '',
    is_premium: false,
    is_active: true
  })

  // File states
  const [thumbnailFile, setThumbnailFile] = useState<File | null>(null)
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

  const removeThumbnail = () => {
    setThumbnailFile(null)
    setThumbnailPreview('')
  }

  const parseVideoUrl = (url: string) => {
    // Extract video ID from YouTube URL
    const youtubeRegex = /(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([^&\n?#]+)/
    const match = url.match(youtubeRegex)
    return match ? match[1] : url
  }

  const getVideoDuration = async (videoId: string) => {
    try {
      // This would require YouTube API key in production
      // For now, we'll return a placeholder duration
      return 1800 // 30 minutes in seconds
    } catch (error) {
      console.error('Error getting video duration:', error)
      return 0
    }
  }

  const compressImage = async (file: File, maxWidth = 1920, maxHeight = 1080, quality = 0.8): Promise<File> => {
    return new Promise((resolve) => {
      const canvas = document.createElement('canvas')
      const ctx = canvas.getContext('2d')!
      const img = new Image()

      img.onload = () => {
        // Calculate new dimensions
        let { width, height } = img

        if (width > maxWidth || height > maxHeight) {
          const ratio = Math.min(maxWidth / width, maxHeight / height)
          width *= ratio
          height *= ratio
        }

        canvas.width = width
        canvas.height = height

        // Draw and compress
        ctx.drawImage(img, 0, 0, width, height)

        canvas.toBlob((blob) => {
          if (blob) {
            const compressedFile = new File([blob], file.name, {
              type: 'image/jpeg',
              lastModified: Date.now()
            })
            resolve(compressedFile)
          } else {
            resolve(file)
          }
        }, 'image/jpeg', quality)
      }

      img.onerror = () => resolve(file)
      img.src = URL.createObjectURL(file)
    })
  }

  const uploadThumbnail = async (file: File, onProgress?: (progress: number) => void) => {
    const fileExt = file.name.split('.').pop()
    const fileName = `${Date.now()}.${fileExt}`
    const filePath = `video-thumbnails/${fileName}`

    // Add progress tracking for large files
    if (onProgress) {
      onProgress(0)
    }

    try {
      console.log('Starting thumbnail upload:', file.name, 'Size:', file.size, 'bytes')

      // Compress image before upload if it's too large (>1MB)
      let fileToUpload = file
      if (file.size > 1024 * 1024) {
        console.log('Compressing image before upload...')
        fileToUpload = await compressImage(file, 1920, 1080, 0.8)
        console.log(`Image compressed from ${(file.size / 1024 / 1024).toFixed(2)}MB to ${(fileToUpload.size / 1024 / 1024).toFixed(2)}MB`)
      }

      const startTime = performance.now()
      const { error: uploadError, data } = await supabase.storage
        .from('book-files')
        .upload(filePath, fileToUpload, {
          cacheControl: '3600',
          upsert: false
        })
      const uploadTime = performance.now() - startTime
      console.log(`Upload completed in ${uploadTime.toFixed(2)}ms`)

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

    if (!formData.title || !formData.category_id || !formData.video_url) {
      alert('Please fill in all required fields')
      return
    }

    setLoading(true)

    try {
      let thumbnailUrl = ''
      let duration = 0

      console.log('Starting video kitab creation...');
      setUploading(true)
      setUploadProgress(0)

      // Prepare all async operations
      const asyncOperations: Promise<any>[] = []

      // Upload thumbnail if provided
      if (thumbnailFile) {
        console.log('Preparing thumbnail upload:', thumbnailFile.name);
        const thumbnailUploadPromise = uploadThumbnail(thumbnailFile, (progress) => {
          setUploadProgress(progress)
        }).then(url => {
          thumbnailUrl = url
          console.log('Thumbnail uploaded successfully:', url);
        })
        asyncOperations.push(thumbnailUploadPromise)
      }

      // Parse video URL and get duration
      const parsedVideoId = parseVideoUrl(formData.video_url)

      // Calculate total duration in seconds
      const hours = parseInt(formData.duration_hours) || 0
      const minutes = parseInt(formData.duration_minutes) || 0
      const seconds = parseInt(formData.duration_seconds) || 0
      duration = (hours * 3600) + (minutes * 60) + seconds

      // If duration is not provided, try to get it from video
      if (duration === 0 && parsedVideoId) {
        console.log('Fetching video duration from YouTube API...');
        const durationPromise = getVideoDuration(parsedVideoId).then(vidDuration => {
          duration = vidDuration
          console.log('Video duration fetched:', duration);
        })
        asyncOperations.push(durationPromise)
      }

      // Wait for all async operations to complete
      console.log('Waiting for async operations to complete...')
      await Promise.all(asyncOperations)
      setUploading(false)
      setUploadProgress(100)

      console.log('All async operations completed. Preparing video data...');

      // Prepare video data with trimmed values
      const videoData = {
        title: formData.title.trim(),
        description: formData.description?.trim() || '',
        category_id: formData.category_id,
        video_url: formData.video_url.trim(),
        youtube_playlist_id: parsedVideoId,
        total_duration_minutes: Math.floor(duration / 60),
        total_videos: 1, // Default value for single video
        duration: duration,
        thumbnail_url: thumbnailUrl,
        is_premium: formData.is_premium,
        is_active: formData.is_active
      };

      console.log('Video data to insert:', videoData);

      // Optimized database insert with timeout
      const startTime = performance.now()
      console.log('Starting database insert...')

      // Add timeout to prevent hanging
      const insertPromise = supabase
        .from('video_kitab')
        .insert(videoData)
        .select('id, title')
        .single()

      const timeoutPromise = new Promise((_, reject) =>
        setTimeout(() => reject(new Error('Database insert timeout after 30 seconds')), 30000)
      )

      const { data, error } = await Promise.race([insertPromise, timeoutPromise]) as any

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
        throw new Error('Video kitab was created but no data was returned');
      }

      console.log('=== VIDEO KITAB CREATED SUCCESSFULLY ===');
      console.log('Video data:', data);

      // Show success message and redirect
      alert('Video kitab created successfully!')

      // Use immediate redirect instead of window.location.href
      window.location.replace('/videos')
    } catch (error) {
      console.error('=== CATCH BLOCK ERROR ===');
      console.error('Full error object:', error);
      console.error('Error message:', error instanceof Error ? error.message : 'Unknown error');
      console.error('Error stack:', error instanceof Error ? error.stack : 'No stack trace');

      alert(`Error creating video kitab: ${error instanceof Error ? error.message : 'Unknown error occurred'}. Please try again.`);
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
          title="Add New Video"
          subtitle="Video Content"
        />

        {/* Main Content */}
        <main className="flex-1 px-4 sm:px-6 pb-8 pt-4 bg-gradient-to-br from-slate-950 via-slate-950 to-slate-900">
          <div className="max-w-4xl mx-auto">
            {/* Page Header */}
            <div className="card rounded-2xl p-4 sm:p-5 mb-4">
              <div className="flex items-center gap-3 mb-4">
                <Link href="/videos" className="p-2 rounded-xl bg-slate-900/90 border border-slate-700/80 hover:bg-slate-800/90 transition">
                  <ArrowLeft className="w-4 h-4 text-slate-300" />
                </Link>
                <div>
                  <h2 className="text-base sm:text-lg font-semibold">Add New Video</h2>
                  <p className="text-xs text-slate-400">Create a new video kitab entry</p>
                </div>
              </div>
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
                      <label className="block text-[11px] font-medium text-slate-300 mb-2">
                        Title *
                      </label>
                      <input
                        type="text"
                        name="title"
                        value={formData.title}
                        onChange={handleInputChange}
                        className="w-full px-3 py-2 rounded-xl bg-slate-900/80 border border-slate-700/80 text-xs text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-purple-500/50 focus:border-purple-500/50"
                        placeholder="Enter video title"
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
                        className="w-full px-3 py-2 rounded-xl bg-slate-900/80 border border-slate-700/80 text-xs text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-purple-500/50 focus:border-purple-500/50 resize-none"
                        placeholder="Enter video description"
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
                        className="w-full px-3 py-2 rounded-xl bg-slate-900/80 border border-slate-700/80 text-xs text-slate-100 focus:outline-none focus:ring-2 focus:ring-purple-500/50 focus:border-purple-500/50"
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

                {/* Video URL */}
                <div>
                  <h3 className="text-sm font-semibold mb-4 flex items-center gap-2">
                    <Play className="w-4 h-4 text-pink-400" />
                    Video URL
                  </h3>
                  <div>
                    <label className="block text-[11px] font-medium text-slate-300 mb-2">
                      Video URL *
                    </label>
                    <input
                      type="url"
                      name="video_url"
                      value={formData.video_url}
                      onChange={handleInputChange}
                      className="w-full px-3 py-2 rounded-xl bg-slate-900/80 border border-slate-700/80 text-xs text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-purple-500/50 focus:border-purple-500/50"
                      placeholder="https://youtube.com/watch?v=VIDEO_ID"
                      required
                    />
                    <p className="text-[10px] text-slate-500 mt-1">
                      Supports YouTube, Vimeo, and other video platforms
                    </p>
                  </div>
                </div>

                {/* Duration */}
                <div>
                  <h3 className="text-sm font-semibold mb-4 flex items-center gap-2">
                    <Clock className="w-4 h-4 text-green-400" />
                    Duration
                  </h3>
                  <div className="grid grid-cols-3 gap-3">
                    <div>
                      <label className="block text-[11px] font-medium text-slate-300 mb-2">
                        Hours
                      </label>
                      <input
                        type="number"
                        name="duration_hours"
                        value={formData.duration_hours}
                        onChange={handleInputChange}
                        min="0"
                        max="23"
                        className="w-full px-3 py-2 rounded-xl bg-slate-900/80 border border-slate-700/80 text-xs text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-green-500/50 focus:border-green-500/50"
                        placeholder="0"
                      />
                    </div>
                    <div>
                      <label className="block text-[11px] font-medium text-slate-300 mb-2">
                        Minutes
                      </label>
                      <input
                        type="number"
                        name="duration_minutes"
                        value={formData.duration_minutes}
                        onChange={handleInputChange}
                        min="0"
                        max="59"
                        className="w-full px-3 py-2 rounded-xl bg-slate-900/80 border border-slate-700/80 text-xs text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-green-500/50 focus:border-green-500/50"
                        placeholder="0"
                      />
                    </div>
                    <div>
                      <label className="block text-[11px] font-medium text-slate-300 mb-2">
                        Seconds
                      </label>
                      <input
                        type="number"
                        name="duration_seconds"
                        value={formData.duration_seconds}
                        onChange={handleInputChange}
                        min="0"
                        max="59"
                        className="w-full px-3 py-2 rounded-xl bg-slate-900/80 border border-slate-700/80 text-xs text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-green-500/50 focus:border-green-500/50"
                        placeholder="0"
                      />
                    </div>
                  </div>
                  <p className="text-[10px] text-slate-500 mt-1">
                    Leave blank if duration should be auto-detected
                  </p>
                </div>

                {/* Settings */}
                <div>
                  <h3 className="text-sm font-semibold mb-4 flex items-center gap-2">
                    <User className="w-4 h-4 text-blue-400" />
                    Video Settings
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
                        <span className="text-xs font-medium text-slate-200">Premium Video</span>
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
                        <p className="text-[10px] text-slate-400">Video is visible to users</p>
                      </div>
                    </label>
                  </div>
                </div>

                {/* Thumbnail Upload */}
                <div>
                  <h3 className="text-sm font-semibold mb-4 flex items-center gap-2">
                    <Image className="w-4 h-4 text-orange-400" />
                    Thumbnail Image
                  </h3>
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
                            <p className="text-[10px] text-slate-400">
                              {thumbnailFile
                                ? `${(thumbnailFile.size / 1024 / 1024).toFixed(2)} MB`
                                : 'Image file'
                              }
                              {thumbnailFile && thumbnailFile.size > 1024 * 1024 && (
                                <span className="text-amber-400 ml-1">• Will be compressed</span>
                              )}
                            </p>
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
                          <Upload className="w-4 h-4" />
                          Choose Thumbnail
                        </label>
                        <p className="text-[10px] text-slate-500 mt-2">
                          Upload JPG, PNG or GIF (Max 2MB)
                        </p>
                        <p className="text-[10px] text-slate-600 mt-1">
                          Optional - Used for video preview
                        </p>
                      </div>
                    )}
                  </div>
                </div>

                {/* Upload Progress */}
                {(uploading || uploadProgress > 0) && (
                  <div className="mb-4">
                    <div className="flex items-center justify-between mb-2">
                      <span className="text-xs text-slate-300">
                        {uploading ? 'Processing video...' : 'Processing complete'}
                      </span>
                      <span className="text-xs text-slate-400">
                        {uploadProgress}%
                      </span>
                    </div>
                    <div className="w-full bg-slate-700/50 rounded-full h-2">
                      <div
                        className="bg-gradient-to-r from-purple-500 to-pink-500 h-2 rounded-full transition-all duration-300 ease-out"
                        style={{ width: `${uploadProgress}%` }}
                      ></div>
                    </div>
                  </div>
                )}

                {/* Actions */}
                <div className="flex items-center justify-end gap-3 pt-4 border-t border-slate-800/80">
                  <Link
                    href="/videos"
                    className="px-4 py-2 rounded-xl bg-slate-900/80 border border-slate-700/80 text-xs text-slate-300 hover:bg-slate-800/90 transition"
                  >
                    Cancel
                  </Link>
                  <button
                    type="submit"
                    disabled={loading || uploading}
                    className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-gradient-to-r from-purple-600 to-pink-600 text-white text-xs font-medium hover:from-purple-700 hover:to-pink-700 transition-all shadow-lg disabled:opacity-50 disabled:cursor-not-allowed min-w-[120px]"
                  >
                    {loading || uploading ? (
                      <>
                        <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                        <span className="text-center">
                          {uploading
                            ? `Uploading${uploadProgress > 0 ? ` ${uploadProgress}%` : '...'}`
                            : 'Creating video...'
                          }
                        </span>
                      </>
                    ) : (
                      <>
                        <Save className="w-4 h-4" />
                        Create Video
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

export default function NewVideoPage() {
  return (
    <QueryProvider>
      <NewVideoContent />
    </QueryProvider>
  )
}
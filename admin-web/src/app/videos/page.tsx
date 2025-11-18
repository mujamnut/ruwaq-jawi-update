'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import DashboardLayout from "@/components/dashboard-layout"
import {
  Plus,
  Edit,
  Trash2,
  Search,
  Play,
  Filter,
  Video,
  Clock,
  Eye,
  RefreshCw
} from 'lucide-react'
import { supabase } from "@/lib/supabase"
import { BulkOperations, BulkCheckbox } from "@/components/bulk-operations"

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
  episode_count?: number
}

function VideosContent() {
  const [videos, setVideos] = useState<VideoKitab[]>([])
  const [categories, setCategories] = useState<any[]>([])
  const [searchTerm, setSearchTerm] = useState('')
  const [loading, setLoading] = useState(true)
  const [deleteLoading, setDeleteLoading] = useState<string | null>(null)
  const [selectedVideos, setSelectedVideos] = useState<string[]>([])
  const [bulkLoading, setBulkLoading] = useState(false)
  const [refreshKey, setRefreshKey] = useState(0)

  useEffect(() => {
    Promise.all([fetchVideos(), fetchCategories()])
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

  const fetchVideos = async () => {
    try {
      setLoading(true)
      const { data: videos, error } = await supabase
        .from('video_kitab')
        .select('*')
        .order('created_at', { ascending: false })

      // Handle empty error objects and RLS issues
      if (error) {
        const errorMsg = error?.message || JSON.stringify(error) || 'Unknown error'
        console.error('Error fetching videos:', errorMsg)
        return
      }

      // Fetch episode counts for each video
      const videoIds = videos?.map(video => video.id) || []
      const { data: episodes, error: episodesError } = await supabase
        .from('video_episodes')
        .select('video_kitab_id')
        .in('video_kitab_id', videoIds)

      if (episodesError) {
        console.error('Error fetching episodes:', episodesError)
      }

      // Count episodes per video
      const episodeCounts = episodes?.reduce((acc, episode) => {
        acc[episode.video_kitab_id] = (acc[episode.video_kitab_id] || 0) + 1
        return acc
      }, {} as Record<string, number>) || {}

      // Add episode counts to videos
      const videosWithEpisodeCounts = videos?.map(video => ({
        ...video,
        episode_count: episodeCounts[video.id] || 0
      })) || []

      setVideos(videosWithEpisodeCounts)
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : JSON.stringify(error) || 'Unknown error'
      console.error('Error fetching videos:', errorMsg)
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
    if (!confirm('Are you sure you want to delete this video? This action cannot be undone.')) return

    try {
      setDeleteLoading(id)
      const { error } = await supabase
        .from('video_kitab')
        .delete()
        .eq('id', id)

      // Handle empty error objects and RLS issues
      if (error) {
        const errorMsg = error?.message || JSON.stringify(error) || 'Unknown error'
        console.error('Error deleting video:', errorMsg)
        return
      }

      await fetchVideos()
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : JSON.stringify(error) || 'Unknown error'
      console.error('Error deleting video:', errorMsg)
    } finally {
      setDeleteLoading(null)
    }
  }

  const getCategoryName = (categoryId: string) => {
    const category = categories.find(cat => cat.id === categoryId)
    return category?.name || 'Unknown'
  }

  const formatDuration = (seconds: number) => {
    const hours = Math.floor(seconds / 3600)
    const minutes = Math.floor((seconds % 3600) / 60)
    const secs = seconds % 60

    if (hours > 0) {
      return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
    }
    return `${minutes}:${secs.toString().padStart(2, '0')}`
  }

  const filteredVideos = videos.filter(video =>
    video.title.toLowerCase().includes(searchTerm.toLowerCase())
  )

  return (
    <DashboardLayout title="Videos" subtitle="Manage video collections">
          {/* Main Content */}
          <main className="flex-1 px-4 sm:px-6 pb-8 pt-4 bg-gray-50 dark:bg-gradient-to-br dark:from-slate-950 dark:via-slate-950 dark:to-slate-900 transition-colors duration-300">
          {/* Page Header */}
          <div className="card rounded-2xl p-4 sm:p-5 mb-4 bg-white dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <h2 className="text-base sm:text-lg font-semibold mb-1 text-gray-900 dark:text-white">Video Collections</h2>
                <p className="text-xs text-gray-600 dark:text-gray-400">Manage video lessons and content</p>
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
                <Link href="/videos/new" className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-gradient-to-r from-purple-600 to-pink-600 text-white text-xs font-medium hover:from-purple-700 hover:to-pink-700 transition-all shadow-lg">
                  <Plus className="w-4 h-4" />
                  Add Video Kitab
                </Link>
              </div>
            </div>

            {/* Stats Cards */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mt-4">
              <div className="rounded-xl border border-gray-300/80 dark:border-slate-600/80 bg-white/80 dark:bg-slate-800/90 p-3">
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-[11px] text-gray-600 dark:text-gray-400">Total Videos</span>
                  <span className="px-1.5 py-0.5 rounded-full bg-purple-500/10 text-[10px] text-purple-300 dark:text-purple-400 border border-purple-500/40 dark:border-purple-400/40">
                    {videos.length}
                  </span>
                </div>
                <p className="text-lg font-semibold text-gray-900 dark:text-white">{videos.length}</p>
                <p className="mt-0.5 text-[11px] text-gray-500 dark:text-gray-400">Video collections</p>
              </div>
              <div className="rounded-xl border border-gray-300/80 dark:border-slate-600/80 bg-white/80 dark:bg-slate-800/90 p-3">
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-[11px] text-gray-600 dark:text-gray-400">Premium</span>
                  <span className="px-1.5 py-0.5 rounded-full bg-amber-500/10 text-[10px] text-amber-300 dark:text-amber-400 border border-amber-500/40 dark:border-amber-400/40">
                    {videos.filter(v => v.is_premium).length}
                  </span>
                </div>
                <p className="text-lg font-semibold text-gray-900 dark:text-white">{videos.filter(v => v.is_premium).length}</p>
                <p className="mt-0.5 text-[11px] text-gray-500 dark:text-gray-400">Paid content</p>
              </div>
              <div className="rounded-xl border border-gray-300/80 dark:border-slate-600/80 bg-white/80 dark:bg-slate-800/90 p-3">
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-[11px] text-gray-600 dark:text-gray-400">Free</span>
                  <span className="px-1.5 py-0.5 rounded-full bg-emerald-500/10 text-[10px] text-emerald-300 dark:text-emerald-400 border border-emerald-500/40 dark:border-emerald-400/40">
                    {videos.filter(v => !v.is_premium).length}
                  </span>
                </div>
                <p className="text-lg font-semibold text-gray-900 dark:text-white">{videos.filter(v => !v.is_premium).length}</p>
                <p className="mt-0.5 text-[11px] text-gray-500 dark:text-gray-400">Free content</p>
              </div>
              <div className="rounded-xl border border-gray-300/80 dark:border-slate-600/80 bg-white/80 dark:bg-slate-800/90 p-3">
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-[11px] text-gray-600 dark:text-gray-400">Total Duration</span>
                  <span className="px-1.5 py-0.5 rounded-full bg-indigo-500/10 text-[10px] text-indigo-300 dark:text-indigo-400 border border-indigo-500/40 dark:border-indigo-400/40">
                    <Clock className="w-3 h-3" />
                  </span>
                </div>
                <p className="text-lg font-semibold text-gray-900 dark:text-white">
                  {formatDuration(videos.reduce((total, video) => total + (video.duration || 0), 0))}
                </p>
                <p className="mt-0.5 text-[11px] text-gray-500 dark:text-gray-400">Content length</p>
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
                    placeholder="Search videos by title..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="pl-10 pr-4 py-2 w-full sm:w-80 rounded-xl bg-white/80 dark:bg-slate-700/90 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500/50 dark:focus:ring-blue-400/50 focus:border-blue-500/50 dark:focus:border-blue-400/50"
                  />
                </div>
                <button className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-white/80 dark:bg-slate-700/90 border border-gray-300/80 dark:border-slate-600/80 text-xs font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-100/90 dark:hover:bg-slate-600/90">
                  <Filter className="w-4 h-4" />
                  Filters
                </button>
              </div>
              <div className="text-xs text-gray-600 dark:text-gray-400">
                Showing {filteredVideos.length} of {videos.length} videos
              </div>
            </div>
          </div>

          {/* Bulk Operations */}
          <BulkOperations
            selectedItems={selectedVideos}
            items={filteredVideos}
            itemType="videos"
            onSelectionChange={setSelectedVideos}
            onItemsUpdate={fetchVideos}
            onLoadingChange={setBulkLoading}
          />

          {/* Videos Table */}
          <div className="card rounded-2xl p-4 sm:p-5 bg-white dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80">
            <div className="overflow-x-auto no-scrollbar">
              <table className="w-full text-left border-separate border-spacing-y-1.5">
                <thead className="text-[10px] uppercase tracking-[.18em] text-gray-500 dark:text-gray-400">
                  <tr>
                    <th className="px-2 py-1.5 w-10"></th>
                    <th className="px-2 py-1.5">Video</th>
                    <th className="px-2 py-1.5 whitespace-nowrap">Category</th>
                    <th className="px-2 py-1.5 whitespace-nowrap">Episodes</th>
                    <th className="px-2 py-1.5 whitespace-nowrap">Duration</th>
                    <th className="px-2 py-1.5 whitespace-nowrap">Type</th>
                    <th className="px-2 py-1.5 whitespace-nowrap">Added</th>
                    <th className="px-2 py-1.5 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="text-xs">
                  {loading || bulkLoading ? (
                    <tr>
                      <td colSpan={8} className="text-center py-8">
                        <div className="flex items-center justify-center">
                          <div className="w-6 h-6 border-2 border-purple-500 border-t-transparent rounded-full animate-spin"></div>
                          <span className="ml-2 text-gray-600 dark:text-gray-400">
                            {bulkLoading ? 'Processing bulk operation...' : 'Loading videos...'}
                          </span>
                        </div>
                      </td>
                    </tr>
                  ) : filteredVideos.length === 0 ? (
                    <tr>
                      <td colSpan={8} className="text-center py-8">
                        <div className="flex flex-col items-center">
                          <Video className="w-12 h-12 text-gray-400 dark:text-gray-600 mb-3" />
                          <h3 className="text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">No videos found</h3>
                          <p className="text-[11px] text-gray-500 dark:text-gray-400">
                            {searchTerm ? 'No videos match your search criteria' : 'Start by adding your first video kitab'}
                          </p>
                        </div>
                      </td>
                    </tr>
                  ) : (
                    filteredVideos.map((video) => (
                      <tr key={video.id} className={`bg-white/90 dark:bg-slate-700/90 hover:bg-white dark:hover:bg-slate-700 transition border border-gray-200/80 dark:border-slate-600/80 ${selectedVideos.includes(video.id) ? 'bg-blue-500/5 dark:bg-blue-500/10' : ''}`}>
                        <td className="px-2 py-3">
                          <div className="flex items-center justify-center">
                            <BulkCheckbox
                              itemId={video.id}
                              isSelected={selectedVideos.includes(video.id)}
                              onToggle={(id, checked) => {
                                if (checked) {
                                  setSelectedVideos(prev => [...prev, id])
                                } else {
                                  setSelectedVideos(prev => prev.filter(selectedId => selectedId !== id))
                                }
                              }}
                              disabled={bulkLoading}
                            />
                          </div>
                        </td>
                        <td className="px-2 py-3">
                          <div className="flex items-center gap-3">
                            <div className="w-10 h-10 rounded-xl bg-white dark:bg-slate-600 flex items-center justify-center border border-gray-300/80 dark:border-slate-500/80">
                              {video.thumbnail_url ? (
                                <img
                                  src={video.thumbnail_url}
                                  alt={video.title}
                                  className="w-full h-full object-cover rounded-xl"
                                />
                              ) : (
                                <Play className="w-4 h-4 text-purple-400 dark:text-purple-300" />
                              )}
                            </div>
                            <div className="flex-1 min-w-0">
                              <p className="text-xs font-medium text-gray-900 dark:text-white truncate">{video.title}</p>
                              <p className="text-[10px] text-gray-600 dark:text-gray-400 line-clamp-2">{video.description || 'No description'}</p>
                            </div>
                          </div>
                        </td>
                          <td className="px-2 py-3">
                          <span className="px-2 py-0.5 rounded-full bg-white dark:bg-slate-600 border border-gray-300/80 dark:border-slate-500/80 text-[10px] text-gray-800 dark:text-gray-200">
                            {getCategoryName(video.category_id)}
                          </span>
                        </td>
                        <td className="px-2 py-3">
                          <div className="flex items-center gap-1">
                            <span className="px-2 py-0.5 rounded-lg bg-indigo-50 dark:bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 border border-indigo-200 dark:border-indigo-400/30 text-[10px] font-medium">
                              {video.episode_count || 0} episodes
                            </span>
                          </div>
                        </td>
                        <td className="px-2 py-3">
                          <div className="flex items-center gap-1 text-[11px] text-gray-600 dark:text-gray-400">
                            <Clock className="w-3 h-3" />
                            {formatDuration(video.duration || 0)}
                          </div>
                        </td>
                        <td className="px-2 py-3">
                          <span className={`px-2 py-0.5 rounded-full text-[10px] border ${
                            video.is_premium
                              ? 'bg-amber-500/10 text-amber-300 dark:text-amber-400 border-amber-500/40 dark:border-amber-400/40'
                              : 'bg-emerald-500/10 text-emerald-300 dark:text-emerald-400 border-emerald-500/40 dark:border-emerald-400/40'
                          }`}>
                            {video.is_premium ? 'Premium' : 'Free'}
                          </span>
                        </td>
                        <td className="px-2 py-3">
                          <div className="text-[11px] text-gray-600 dark:text-gray-400">
                            {new Date(video.created_at).toLocaleDateString('en-US', {
                              month: 'short',
                              day: 'numeric',
                              year: 'numeric'
                            })}
                          </div>
                        </td>
                        <td className="px-2 py-3">
                          <div className="flex items-center justify-end gap-1">
                            {/* View Button */}
                            {video.youtube_playlist_url && (
                              <button
                                onClick={() => window.open(video.youtube_playlist_url, '_blank')}
                                className="p-1.5 rounded-lg bg-white dark:bg-slate-600 border border-gray-300/80 dark:border-slate-500/80 text-[10px] hover:bg-blue-600/20 dark:hover:bg-blue-600/30 hover:border-blue-500/40 dark:hover:border-blue-400/40 text-gray-700 dark:text-gray-300 hover:text-blue-600 dark:hover:text-blue-400 transition-colors"
                                title="View Video"
                              >
                                <Eye className="w-3.5 h-3.5" />
                              </button>
                            )}

                            {/* Edit Button */}
                            <Link
                              href={`/videos/${video.id}/edit`}
                              className="p-1.5 rounded-lg bg-white dark:bg-slate-600 border border-gray-300/80 dark:border-slate-500/80 text-[10px] hover:bg-amber-600/20 dark:hover:bg-amber-600/30 hover:border-amber-500/40 dark:hover:border-amber-400/40 text-gray-700 dark:text-gray-300 hover:text-amber-600 dark:hover:text-amber-400 transition-colors"
                              title="Edit Video"
                            >
                              <Edit className="w-3.5 h-3.5" />
                            </Link>

                            {/* Delete Button */}
                            <button
                              onClick={() => handleDelete(video.id)}
                              disabled={deleteLoading === video.id}
                              className="p-1.5 rounded-lg bg-white dark:bg-slate-600 border border-gray-300/80 dark:border-slate-500/80 text-[10px] hover:bg-rose-600/20 dark:hover:bg-rose-600/30 hover:border-rose-500/40 dark:hover:border-rose-400/40 text-gray-700 dark:text-gray-300 hover:text-rose-300 dark:hover:text-rose-400 disabled:opacity-50 transition-colors"
                              title="Delete Video"
                            >
                              {deleteLoading === video.id ? (
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

export default function VideosPage() {
  return <VideosContent />
}
import { useSupabaseQuery, useSupabaseCreate, useSupabaseUpdate, useSupabaseDelete, useSupabaseBulkDelete } from './use-supabase-query'
import { Database } from '../lib/supabase'

// Type definitions for video kitabs
type VideoKitab = Database['public']['Tables']['video_kitab']['Row']
type VideoKitabInsert = Database['public']['Tables']['video_kitab']['Insert']
type VideoKitabUpdate = Database['public']['Tables']['video_kitab']['Update']

// Type definitions for video episodes
type VideoEpisode = Database['public']['Tables']['video_episodes']['Row']
type VideoEpisodeInsert = Database['public']['Tables']['video_episodes']['Insert']
type VideoEpisodeUpdate = Database['public']['Tables']['video_episodes']['Update']

// Hook for fetching all video kitabs
export function useVideoKitabs(options?: {
  categoryId?: string
  isPremium?: boolean
  isActive?: boolean
  search?: string
}) {
  const filters: Record<string, any> = {}

  if (options?.categoryId !== undefined) {
    filters.category_id = options.categoryId
  }
  if (options?.isPremium !== undefined) {
    filters.is_premium = options.isPremium
  }
  if (options?.isActive !== undefined) {
    filters.is_active = options.isActive
  }

  return useSupabaseQuery('video_kitab', {
    filter: Object.keys(filters).length > 0 ? filters : undefined,
    orderBy: { column: 'created_at', ascending: false },
  })
}

// Hook for fetching a single video kitab by ID
export function useVideoKitab(id: string | undefined) {
  return useSupabaseQuery('video_kitab', {
    select: '*',
    filter: { id: id || '' }
  })
}

// Hook for creating a video kitab
export function useCreateVideoKitab(options?: {
  onSuccess?: (videoKitab: VideoKitab) => void
  onError?: (error: Error) => void
}) {
  return useSupabaseCreate('video_kitab', options)
}

// Hook for updating a video kitab
export function useUpdateVideoKitab(options?: {
  onSuccess?: (videoKitab: VideoKitab) => void
  onError?: (error: Error) => void
}) {
  return useSupabaseUpdate('video_kitab', options)
}

// Hook for deleting a video kitab
export function useDeleteVideoKitab(options?: {
  onSuccess?: () => void
  onError?: (error: Error) => void
}) {
  return useSupabaseDelete('video_kitab', options)
}

// Hook for fetching video episodes for a specific kitab
export function useVideoEpisodes(videoKitabId: string | undefined) {
  return useSupabaseQuery('video_episodes', {
    filter: videoKitabId ? { video_kitab_id: videoKitabId } : undefined,
    orderBy: { column: 'part_number', ascending: true },
    enabled: !!videoKitabId,
  })
}

// Hook for creating a video episode
export function useCreateVideoEpisode(options?: {
  onSuccess?: (episode: VideoEpisode) => void
  onError?: (error: Error) => void
}) {
  return useSupabaseCreate('video_episodes', options)
}

// Hook for updating a video episode
export function useUpdateVideoEpisode(options?: {
  onSuccess?: (episode: VideoEpisode) => void
  onError?: (error: Error) => void
}) {
  return useSupabaseUpdate('video_episodes', options)
}

// Hook for deleting a video episode
export function useDeleteVideoEpisode(options?: {
  onSuccess?: () => void
  onError?: (error: Error) => void
}) {
  return useSupabaseDelete('video_episodes', options)
}

// Hook for bulk deleting video kitabs
export function useBulkDeleteVideoKitabs(options?: {
  onSuccess?: () => void
  onError?: (error: Error) => void
}) {
  return useSupabaseBulkDelete('video_kitab', options)
}
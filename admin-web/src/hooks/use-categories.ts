import { useSupabaseQuery, useSupabaseCreate, useSupabaseUpdate, useSupabaseDelete } from './use-supabase-query'
import { Database } from '../lib/supabase'

// Type definitions for categories
type Category = Database['public']['Tables']['categories']['Row']
type CategoryInsert = Database['public']['Tables']['categories']['Insert']
type CategoryUpdate = Database['public']['Tables']['categories']['Update']

// Hook for fetching all categories
export function useCategories(options?: {
  isActive?: boolean
}) {
  const filters: Record<string, any> = {}

  if (options?.isActive !== undefined) {
    filters.is_active = options.isActive
  }

  return useSupabaseQuery('categories', {
    filter: Object.keys(filters).length > 0 ? filters : undefined,
    orderBy: { column: 'sort_order', ascending: true },
  })
}

// Hook for fetching a single category by ID
export function useCategory(id: string | undefined) {
  return useSupabaseQuery('categories', {
    select: '*',
    filter: { id: id || '' }
  })
}

// Hook for creating a category
export function useCreateCategory(options?: {
  onSuccess?: (category: Category) => void
  onError?: (error: Error) => void
}) {
  return useSupabaseCreate('categories', options)
}

// Hook for updating a category
export function useUpdateCategory(options?: {
  onSuccess?: (category: Category) => void
  onError?: (error: Error) => void
}) {
  return useSupabaseUpdate('categories', options)
}

// Hook for deleting a category
export function useDeleteCategory(options?: {
  onSuccess?: () => void
  onError?: (error: Error) => void
}) {
  return useSupabaseDelete('categories', options)
}

// Hook for updating category sort order
export function useUpdateCategoryOrder() {
  return useSupabaseUpdate('categories')
}
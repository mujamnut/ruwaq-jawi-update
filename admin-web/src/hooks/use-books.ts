import { useSupabaseQuery, useSupabaseCreate, useSupabaseUpdate, useSupabaseDelete, useSupabaseBulkDelete } from './use-supabase-query'
import { Database } from '../lib/supabase'

// Type definitions for books
type Book = Database['public']['Tables']['ebooks']['Row']
type BookInsert = Database['public']['Tables']['ebooks']['Insert']
type BookUpdate = Database['public']['Tables']['ebooks']['Update']

// Hook for fetching all books
export function useBooks(options?: {
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

  return useSupabaseQuery('ebooks', {
    filter: Object.keys(filters).length > 0 ? filters : undefined,
    orderBy: { column: 'created_at', ascending: false },
  })
}

// Hook for fetching a single book by ID
export function useBook(id: string | undefined) {
  return useSupabaseQuery('ebooks', {
    select: '*',
    filter: { id: id || '' }
  })
}

// Hook for creating a book
export function useCreateBook(options?: {
  onSuccess?: (book: Book) => void
  onError?: (error: Error) => void
}) {
  return useSupabaseCreate('ebooks', options)
}

// Hook for updating a book
export function useUpdateBook(options?: {
  onSuccess?: (book: Book) => void
  onError?: (error: Error) => void
}) {
  return useSupabaseUpdate('ebooks', options)
}

// Hook for deleting a book
export function useDeleteBook(options?: {
  onSuccess?: () => void
  onError?: (error: Error) => void
}) {
  return useSupabaseDelete('ebooks', options)
}

// Hook for bulk deleting books
export function useBulkDeleteBooks(options?: {
  onSuccess?: () => void
  onError?: (error: Error) => void
}) {
  return useSupabaseBulkDelete('ebooks', options)
}
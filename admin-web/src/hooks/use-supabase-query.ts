import { useQuery, useMutation, useQueryClient, UseQueryOptions } from '@tanstack/react-query'
import { supabase, Database } from '../lib/supabase'

// Generic type for Supabase queries
type SupabaseTable = keyof Database['public']['Tables']
type SupabaseRow<T extends SupabaseTable> = Database['public']['Tables'][T]['Row']
type SupabaseInsert<T extends SupabaseTable> = Database['public']['Tables'][T]['Insert']
type SupabaseUpdate<T extends SupabaseTable> = Database['public']['Tables'][T]['Update']

// Generic hook for fetching data from Supabase
export function useSupabaseQuery<T extends SupabaseTable>(
  table: T,
  options?: {
    select?: string
    filter?: Record<string, any>
    orderBy?: { column: string; ascending?: boolean }
    limit?: number
    enabled?: boolean
  }
) {
  return useQuery({
    queryKey: [table, options],
    queryFn: async () => {
      let query = supabase.from(table).select(options?.select || '*')

      // Apply filters
      if (options?.filter) {
        Object.entries(options.filter).forEach(([key, value]) => {
          if (value !== undefined && value !== null) {
            query = query.eq(key, value)
          }
        })
      }

      // Apply ordering
      if (options?.orderBy) {
        query = query.order(options.orderBy.column, {
          ascending: options.orderBy.ascending ?? true
        })
      }

      // Apply limit
      if (options?.limit) {
        query = query.limit(options.limit)
      }

      const { data, error } = await query

      if (error) throw error
      return data as unknown as SupabaseRow<T>[]
    },
    enabled: options?.enabled ?? true,
  })
}

// Hook for fetching single record by ID
export function useSupabaseQueryById<T extends SupabaseTable>(
  table: T,
  id: string | undefined,
  options?: {
    select?: string
    enabled?: boolean
  }
) {
  return useQuery({
    queryKey: [table, id],
    queryFn: async () => {
      if (!id) throw new Error('ID is required')

      const { data, error } = await supabase
        .from(table)
        .select(options?.select || '*')
        .eq('id', id)
        .single()

      if (error) throw error
      return data as unknown as SupabaseRow<T>
    },
    enabled: (options?.enabled ?? true) && !!id,
  })
}

// Hook for creating records
export function useSupabaseCreate<T extends SupabaseTable>(
  table: T,
  options?: {
    onSuccess?: (data: SupabaseRow<T>) => void
    onError?: (error: Error) => void
  }
) {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (data: SupabaseInsert<T>) => {
      const { data: result, error } = await supabase
        .from(table)
        .insert(data)
        .select()
        .single()

      if (error) throw error
      return result as SupabaseRow<T>
    },
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: [table] })
      options?.onSuccess?.(data)
    },
    onError: options?.onError,
  })
}

// Hook for updating records
export function useSupabaseUpdate<T extends SupabaseTable>(
  table: T,
  options?: {
    onSuccess?: (data: SupabaseRow<T>) => void
    onError?: (error: Error) => void
  }
) {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async ({ id, data }: { id: string; data: SupabaseUpdate<T> }) => {
      const { data: result, error } = await supabase
        .from(table)
        .update(data)
        .eq('id', id)
        .select()
        .single()

      if (error) throw error
      return result as SupabaseRow<T>
    },
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: [table] })
      queryClient.invalidateQueries({ queryKey: [table, data.id] })
      options?.onSuccess?.(data)
    },
    onError: options?.onError,
  })
}

// Hook for deleting records
export function useSupabaseDelete<T extends SupabaseTable>(
  table: T,
  options?: {
    onSuccess?: () => void
    onError?: (error: Error) => void
  }
) {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from(table).delete().eq('id', id)

      if (error) throw error
      return id
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [table] })
      options?.onSuccess?.()
    },
    onError: options?.onError,
  })
}

// Hook for bulk operations
export function useSupabaseBulkDelete<T extends SupabaseTable>(
  table: T,
  options?: {
    onSuccess?: () => void
    onError?: (error: Error) => void
  }
) {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (ids: string[]) => {
      const { error } = await supabase.from(table).delete().in('id', ids)

      if (error) throw error
      return ids
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [table] })
      options?.onSuccess?.()
    },
    onError: options?.onError,
  })
}

// Hook for searching
export function useSupabaseSearch<T extends SupabaseTable>(
  table: T,
  searchColumns: string[],
  searchQuery: string,
  options?: {
    enabled?: boolean
    debounceMs?: number
  }
) {
  return useQuery({
    queryKey: [table, 'search', searchQuery, searchColumns],
    queryFn: async () => {
      if (!searchQuery.trim()) return []

      const searchFilters = searchColumns.map(column =>
        `${column}.ilike.%${searchQuery}%`
      ).join(',')

      const { data, error } = await supabase
        .from(table)
        .select('*')
        .or(searchFilters)

      if (error) throw error
      return data as SupabaseRow<T>[]
    },
    enabled: (options?.enabled ?? true) && searchQuery.trim().length > 0,
  })
}
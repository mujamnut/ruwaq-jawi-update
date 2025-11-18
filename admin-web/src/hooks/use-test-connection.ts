import { useQuery } from '@tanstack/react-query'
import { supabaseAdmin } from '../lib/supabase'

export function useTestConnection() {
  return useQuery({
    queryKey: ['test-connection'],
    queryFn: async () => {
      console.log('Hook: Testing connection...')
      try {
        const { data, error } = await supabaseAdmin
          .from('user_subscriptions')
          .select('count')
          .limit(1)

        console.log('Hook: Connection test result:', { data, error })

        if (error) {
          console.error('Hook: Connection test error:', error)
          throw error
        }

        return { success: true, data }
      } catch (err) {
        console.error('Hook: Connection test exception:', err)
        throw err
      }
    },
    staleTime: 0,
  })
}
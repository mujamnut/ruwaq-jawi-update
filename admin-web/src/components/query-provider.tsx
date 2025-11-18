'use client'

import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ReactQueryDevtools } from '@tanstack/react-query-devtools'
import { useState } from 'react'

export default function QueryProvider({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 0, // No caching to ensure fresh data
        retry: 1, // Reduce retry to fail fast for debugging
        retryDelay: attemptIndex => 1000, // Fixed delay
        refetchOnWindowFocus: false,
      },
      mutations: {
        retry: 1,
      },
    },
    logger: (message, ...args) => {
      console.log('React Query:', message, ...args)
    }
  }))

  return (
    <QueryClientProvider client={queryClient}>
      {children}
      <ReactQueryDevtools initialIsOpen={false} />
    </QueryClientProvider>
  )
}
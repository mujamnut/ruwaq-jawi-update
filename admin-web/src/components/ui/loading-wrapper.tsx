import React from 'react'
import { Loader2 } from 'lucide-react'
import { Skeleton } from './skeleton'

interface LoadingWrapperProps {
  isLoading?: boolean
  error?: Error | null
  children: React.ReactNode
  fallback?: React.ReactNode
  skeleton?: React.ReactNode
  errorComponent?: React.ReactNode
  className?: string
}

export function LoadingWrapper({
  isLoading = false,
  error = null,
  children,
  fallback,
  skeleton,
  errorComponent,
  className
}: LoadingWrapperProps) {
  if (error) {
    return (
      errorComponent || (
        <div className={`flex flex-col items-center justify-center p-8 text-center ${className}`}>
          <div className="w-12 h-12 rounded-full bg-red-500/10 flex items-center justify-center mb-4">
            <span className="text-red-400 text-xl">⚠</span>
          </div>
          <h3 className="text-lg font-medium text-gray-800 mb-2">Something went wrong</h3>
          <p className="text-sm text-gray-600 max-w-md">
            {error.message || 'An error occurred while loading this content.'}
          </p>
        </div>
      )
    )
  }

  if (isLoading) {
    return (
      fallback ||
      skeleton || (
        <div className={`space-y-4 ${className}`}>
          <div className="flex items-center justify-center p-8">
            <Loader2 className="w-8 h-8 animate-spin text-blue-400" />
          </div>
        </div>
      )
    )
  }

  return <>{children}</>
}

// Table loading wrapper
export function TableLoadingWrapper({
  isLoading,
  error,
  children,
  columns,
  rows = 5
}: {
  isLoading?: boolean
  error?: Error | null
  children: React.ReactNode
  columns?: number
  rows?: number
}) {
  return (
    <LoadingWrapper
      isLoading={isLoading}
      error={error}
      skeleton={
        <div className="space-y-3">
          {Array.from({ length: rows }).map((_, i) => (
            <div key={i} className="flex items-center space-x-4 p-4 border border-gray-200 rounded-lg">
              {Array.from({ length: columns || 4 }).map((_, j) => (
                <Skeleton key={j} className="h-4 flex-1" />
              ))}
            </div>
          ))}
        </div>
      }
    >
      {children}
    </LoadingWrapper>
  )
}

// Stats loading wrapper
export function StatsLoadingWrapper({
  isLoading,
  error,
  children,
  cards = 4
}: {
  isLoading?: boolean
  error?: Error | null
  children: React.ReactNode
  cards?: number
}) {
  return (
    <LoadingWrapper
      isLoading={isLoading}
      error={error}
      skeleton={
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {Array.from({ length: cards }).map((_, i) => (
            <StatsCardSkeleton key={i} />
          ))}
        </div>
      }
    >
      {children}
    </LoadingWrapper>
  )
}

// Chart loading wrapper
export function ChartLoadingWrapper({
  isLoading,
  error,
  children,
  height = 250
}: {
  isLoading?: boolean
  error?: Error | null
  children: React.ReactNode
  height?: number
}) {
  return (
    <LoadingWrapper
      isLoading={isLoading}
      error={error}
      skeleton={
        <div className="flex items-center justify-center p-8" style={{ height }}>
          <div className="animate-pulse space-y-4 w-full">
            <div className="h-4 bg-gray-100 rounded w-3/4 mx-auto"></div>
            <div className="h-32 bg-gray-100 rounded"></div>
            <div className="flex justify-between">
              <div className="h-3 bg-gray-100 rounded w-16"></div>
              <div className="h-3 bg-gray-100 rounded w-16"></div>
              <div className="h-3 bg-gray-100 rounded w-16"></div>
              <div className="h-3 bg-gray-100 rounded w-16"></div>
            </div>
          </div>
        </div>
      }
    >
      {children}
    </LoadingWrapper>
  )
}

// Form loading wrapper
export function FormLoadingWrapper({
  isLoading,
  error,
  children,
  fields = 5
}: {
  isLoading?: boolean
  error?: Error | null
  children: React.ReactNode
  fields?: number
}) {
  return (
    <LoadingWrapper
      isLoading={isLoading}
      error={error}
      skeleton={
        <div className="space-y-4">
          {Array.from({ length: fields }).map((_, i) => (
            <div key={i} className="space-y-2">
              <div className="h-4 bg-gray-100 rounded w-1/4"></div>
              <div className="h-10 bg-gray-100 rounded"></div>
            </div>
          ))}
          <div className="flex justify-end gap-2">
            <div className="h-10 bg-gray-100 rounded w-20"></div>
            <div className="h-10 bg-gray-100 rounded w-32"></div>
          </div>
        </div>
      }
    >
      {children}
    </LoadingWrapper>
  )
}

// Page loading wrapper
export function PageLoadingWrapper({
  isLoading,
  error,
  children
}: {
  isLoading?: boolean
  error?: Error | null
  children: React.ReactNode
}) {
  return (
    <LoadingWrapper
      isLoading={isLoading}
      error={error}
      skeleton={
        <div className="space-y-6">
          <div className="animate-pulse">
            <div className="h-8 w-48 bg-gray-100 rounded mb-4" />
            <div className="h-4 w-64 bg-gray-100 rounded" />
          </div>
          <div className="grid grid-cols-1 lg:grid-cols-4 gap-4">
            {Array.from({ length: 4 }).map((_, i) => (
              <div key={i} className="h-32 bg-gray-100 rounded-lg" />
            ))}
          </div>
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {Array.from({ length: 2 }).map((_, i) => (
              <div key={i} className="h-64 bg-gray-100 rounded-lg" />
            ))}
          </div>
        </div>
      }
    >
      {children}
    </LoadingWrapper>
  )
}

// Inline loading spinner
export function LoadingSpinner({
  size = 'md',
  text
}: {
  size?: 'sm' | 'md' | 'lg'
  text?: string
}) {
  const sizeClasses = {
    sm: 'w-4 h-4',
    md: 'w-6 h-6',
    lg: 'w-8 h-8'
  }

  return (
    <div className="flex items-center gap-2">
      <Loader2 className={`animate-spin text-blue-400 ${sizeClasses[size]}`} />
      {text && <span className="text-sm text-gray-600">{text}</span>}
    </div>
  )
}

// Full page loading overlay
export function FullPageLoading({
  isLoading,
  text = 'Loading...'
}: {
  isLoading: boolean
  text?: string
}) {
  if (!isLoading) return null

  return (
    <div className="fixed inset-0 bg-white/80 backdrop-blur-sm flex items-center justify-center z-50">
      <div className="flex flex-col items-center space-y-4">
        <Loader2 className="w-12 h-12 animate-spin text-blue-400" />
        <span className="text-gray-700">{text}</span>
      </div>
    </div>
  )
}

// Re-export StatsCardSkeleton for convenience
import { StatsCardSkeleton } from './skeleton'
export { StatsCardSkeleton }

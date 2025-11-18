import { useState, useCallback } from 'react'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { FilterOptions } from '../components/advanced-filter'

// Enhanced analytics hook with advanced filtering
export function useAdvancedAnalytics(filters: FilterOptions) {
  return useQuery({
    queryKey: ['advanced-analytics', filters],
    queryFn: async () => {
      let query = supabase
        .from('combined_content_view') // This would be a database view or combined query
        .select('*')

      // Apply filters
      if (filters.dateRange.start && filters.dateRange.end) {
        query = query
          .gte('created_at', filters.dateRange.start)
          .lte('created_at', filters.dateRange.end)
      }

      if (filters.categories.length > 0) {
        query = query.in('category_id', filters.categories)
      }

      if (filters.contentType !== 'all') {
        if (filters.contentType === 'books') {
          query = query.eq('content_type', 'ebook')
        } else if (filters.contentType === 'videos') {
          query = query.eq('content_type', 'video')
        }
      }

      if (filters.status !== 'all') {
        switch (filters.status) {
          case 'active':
            query = query.eq('is_active', true)
            break
          case 'inactive':
            query = query.eq('is_active', false)
            break
          case 'premium':
            query = query.eq('is_premium', true)
            break
          case 'free':
            query = query.eq('is_premium', false)
            break
        }
      }

      if (filters.searchTerm) {
        query = query.or(`title.ilike.%${filters.searchTerm}%,description.ilike.%${filters.searchTerm}%`)
      }

      // Apply sorting
      query = query.order(filters.sortBy, { ascending: filters.sortOrder === 'asc' })

      const { data, error } = await query

      if (error) throw error

      // Apply performance filtering (client-side for now)
      let filteredData = data || []
      if (filters.performance !== 'all') {
        filteredData = filteredData.filter((item: any) => {
          const views = item.views || 0
          switch (filters.performance) {
            case 'high':
              return views > 10000
            case 'medium':
              return views >= 1000 && views <= 10000
            case 'low':
              return views < 1000
            default:
              return true
          }
        })
      }

      return filteredData
    },
    staleTime: 2 * 60 * 1000, // 2 minutes
    enabled: !!filters.dateRange.start && !!filters.dateRange.end
  })
}

// Hook for comparison analytics
export function useComparisonAnalytics(filters: FilterOptions, compareWith?: FilterOptions) {
  return useQuery({
    queryKey: ['comparison-analytics', filters, compareWith],
    queryFn: async () => {
      if (!compareWith) return null

      // Fetch current period data
      const currentQuery = buildContentQuery(filters)
      const { data: currentData, error: currentError } = await currentQuery

      if (currentError) throw currentError

      // Fetch comparison period data
      const compareQuery = buildContentQuery(compareWith)
      const { data: compareData, error: compareError } = await compareQuery

      if (compareError) throw compareError

      // Calculate comparison metrics
      const currentStats = calculateStats(currentData || [])
      const compareStats = calculateStats(compareData || [])

      return {
        current: currentStats,
        comparison: compareStats,
        changes: {
          totalViews: calculatePercentChange(compareStats.totalViews, currentStats.totalViews),
          totalRevenue: calculatePercentChange(compareStats.totalRevenue, currentStats.totalRevenue),
          avgRating: calculatePercentChange(compareStats.avgRating, currentStats.avgRating),
          engagement: calculatePercentChange(compareStats.engagement, currentStats.engagement)
        }
      }
    },
    staleTime: 5 * 60 * 1000, // 5 minutes
    enabled: !!compareWith && !!compareWith.dateRange.start && !!compareWith.dateRange.end
  })
}

// Performance metrics hook
export function usePerformanceMetrics(filters: FilterOptions) {
  return useQuery({
    queryKey: ['performance-metrics', filters],
    queryFn: async () => {
      const [
        contentResult,
        userResult,
        revenueResult
      ] = await Promise.allSettled([
        // Content performance
        buildContentQuery(filters),
        // User activity
        supabase
          .from('user_activity')
          .select('*')
          .gte('date', filters.dateRange.start)
          .lte('date', filters.dateRange.end),
        // Revenue data
        supabase
          .from('payments')
          .select('*')
          .eq('status', 'completed')
          .gte('created_at', filters.dateRange.start)
          .lte('created_at', filters.dateRange.end)
      ])

      const contentData = contentResult.status === 'fulfilled' ? contentResult.value.data || [] : []
      const userData = userResult.status === 'fulfilled' ? userResult.value.data || [] : []
      const revenueData = revenueResult.status === 'fulfilled' ? revenueResult.value.data || [] : []

      // Calculate performance metrics
      const metrics = {
        // Content metrics
        contentEngagement: calculateEngagementRate(contentData),
        contentPerformance: calculateContentPerformance(contentData),
        topPerformers: calculateTopPerformers(contentData),

        // User metrics
        userActivity: calculateUserActivity(userData),
        userRetention: calculateUserRetention(userData),

        // Revenue metrics
        revenueGrowth: calculateRevenueGrowth(revenueData),
        conversionRate: calculateConversionRate(contentData, revenueData),

        // Overall metrics
        healthScore: calculateHealthScore(contentData, userData, revenueData),
        growthRate: calculateGrowthRate(contentData)
      }

      return metrics
    },
    staleTime: 10 * 60 * 1000, // 10 minutes
    enabled: !!filters.dateRange.start && !!filters.dateRange.end
  })
}

// Helper functions
function buildContentQuery(filters: FilterOptions) {
  let query = supabase
    .from('combined_content_view')
    .select('*')

  if (filters.dateRange.start && filters.dateRange.end) {
    query = query
      .gte('created_at', filters.dateRange.start)
      .lte('created_at', filters.dateRange.end)
  }

  if (filters.categories.length > 0) {
    query = query.in('category_id', filters.categories)
  }

  if (filters.contentType !== 'all') {
    if (filters.contentType === 'books') {
      query = query.eq('content_type', 'ebook')
    } else if (filters.contentType === 'videos') {
      query = query.eq('content_type', 'video')
    }
  }

  if (filters.status !== 'all') {
    switch (filters.status) {
      case 'active':
        query = query.eq('is_active', true)
        break
      case 'inactive':
        query = query.eq('is_active', false)
        break
      case 'premium':
        query = query.eq('is_premium', true)
        break
      case 'free':
        query = query.eq('is_premium', false)
        break
    }
  }

  if (filters.searchTerm) {
    query = query.or(`title.ilike.%${filters.searchTerm}%,description.ilike.%${filters.searchTerm}%`)
  }

  return query
}

function calculateStats(data: any[]) {
  return {
    totalItems: data.length,
    totalViews: data.reduce((sum, item) => sum + (item.views || 0), 0),
    totalRevenue: data.reduce((sum, item) => sum + (item.revenue || 0), 0),
    avgRating: data.length > 0 ? data.reduce((sum, item) => sum + (item.rating || 0), 0) / data.length : 0,
    engagement: data.length > 0 ? data.reduce((sum, item) => sum + (item.engagement_rate || 0), 0) / data.length : 0
  }
}

function calculatePercentChange(oldValue: number, newValue: number): number {
  if (oldValue === 0) return newValue > 0 ? 100 : 0
  return ((newValue - oldValue) / oldValue) * 100
}

function calculateEngagementRate(data: any[]): number {
  if (data.length === 0) return 0
  const totalEngagement = data.reduce((sum, item) => sum + (item.likes || 0) + (item.comments || 0) + (item.shares || 0), 0)
  const totalViews = data.reduce((sum, item) => sum + (item.views || 0), 0)
  return totalViews > 0 ? (totalEngagement / totalViews) * 100 : 0
}

function calculateContentPerformance(data: any[]) {
  return {
    excellent: data.filter(item => (item.views || 0) > 10000).length,
    good: data.filter(item => (item.views || 0) >= 1000 && (item.views || 0) <= 10000).length,
    average: data.filter(item => (item.views || 0) >= 100 && (item.views || 0) < 1000).length,
    poor: data.filter(item => (item.views || 0) < 100).length
  }
}

function calculateTopPerformers(data: any[], limit: number = 10) {
  return data
    .sort((a, b) => (b.views || 0) - (a.views || 0))
    .slice(0, limit)
    .map(item => ({
      id: item.id,
      title: item.title,
      type: item.content_type,
      views: item.views || 0,
      rating: item.rating || 0,
      engagement: (item.likes || 0) + (item.comments || 0) + (item.shares || 0)
    }))
}

function calculateUserActivity(data: any[]) {
  return {
    totalUsers: data.length,
    activeUsers: data.filter(user => user.is_active).length,
    newUsers: data.filter(user => user.is_new).length,
    returningUsers: data.filter(user => !user.is_new).length
  }
}

function calculateUserRetention(data: any[]): number {
  const returningUsers = data.filter(user => !user.is_new).length
  const totalUsers = data.length
  return totalUsers > 0 ? (returningUsers / totalUsers) * 100 : 0
}

function calculateRevenueGrowth(data: any[]) {
  const sortedData = data.sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime())
  const totalRevenue = data.reduce((sum, item) => sum + (item.amount_cents || 0), 0)

  if (sortedData.length < 2) return 0

  const midPoint = Math.floor(sortedData.length / 2)
  const firstHalf = sortedData.slice(0, midPoint).reduce((sum, item) => sum + (item.amount_cents || 0), 0)
  const secondHalf = sortedData.slice(midPoint).reduce((sum, item) => sum + (item.amount_cents || 0), 0)

  return firstHalf > 0 ? ((secondHalf - firstHalf) / firstHalf) * 100 : 0
}

function calculateConversionRate(contentData: any[], revenueData: any[]): number {
  const totalViews = contentData.reduce((sum, item) => sum + (item.views || 0), 0)
  const totalConversions = revenueData.length
  return totalViews > 0 ? (totalConversions / totalViews) * 100 : 0
}

function calculateHealthScore(contentData: any[], userData: any[], revenueData: any[]): number {
  // Weighted score based on different factors
  const contentScore = calculateEngagementRate(contentData) / 100 * 0.3
  const userScore = calculateUserRetention(userData) / 100 * 0.3
  const revenueScore = Math.min(calculateRevenueGrowth(revenueData) / 100, 1) * 0.4

  return (contentScore + userScore + revenueScore) * 100
}

function calculateGrowthRate(data: any[]): number {
  if (data.length < 2) return 0

  const sortedData = data.sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime())
  const firstItem = sortedData[0]
  const lastItem = sortedData[sortedData.length - 1]

  const firstViews = firstItem.views || 0
  const lastViews = lastItem.views || 0

  return firstViews > 0 ? ((lastViews - firstViews) / firstViews) * 100 : 0
}
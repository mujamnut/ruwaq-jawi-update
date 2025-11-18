import { useQuery, useQueryClient, useMutation } from '@tanstack/react-query'
import { supabaseAdmin } from '../lib/supabase'
import { useEffect } from 'react'

// Types for subscription management
export interface Subscription {
  id: string
  user_id: string
  plan_id: string
  status: 'active' | 'trial' | 'expired' | 'cancelled' | 'pending'
  start_date: string
  end_date: string
  created_at: string
  updated_at: string
  cancel_at_period_end: boolean
  trial_end_date?: string
  subscription_provider?: 'stripe' | 'paypal' | 'manual'
  provider_subscription_id?: string
}

export interface SubscriptionPlan {
  id: string
  name: string
  description: string
  price_cents: number
  currency: string
  billing_interval: 'month' | 'year'
  features: string[]
  is_active: boolean
  sort_order: number
  created_at: string
  updated_at: string
  stripe_price_id?: string
  paypal_plan_id?: string
}

export interface Payment {
  id: string
  user_id: string
  subscription_id?: string
  amount_cents: number
  currency: string
  status: 'pending' | 'completed' | 'failed' | 'refunded' | 'partially_refunded'
  payment_method: 'card' | 'paypal' | 'bank_transfer' | 'manual'
  provider: 'stripe' | 'paypal' | 'manual'
  provider_payment_id?: string
  description: string
  created_at: string
  updated_at: string
  refunded_at?: string
  refund_reason?: string
}

export interface SubscriptionAnalytics {
  totalSubscriptions: number
  activeSubscriptions: number
  trialSubscriptions: number
  expiredSubscriptions: number
  cancelledSubscriptions: number
  monthlyRevenue: number
  annualRevenue: number
  totalRevenue: number
  churnRate: number
  mrr: number // Monthly Recurring Revenue
  arr: number // Annual Recurring Revenue
  newSubscriptionsThisMonth: number
  cancellationsThisMonth: number
}

// Hook for fetching all subscriptions
export function useSubscriptions(filters?: {
  status?: string
  plan_id?: string
  search?: string
}) {
  return useQuery({
    queryKey: ['subscriptions', filters],
    queryFn: async () => {
      console.log('Hook: Starting subscription fetch...')
      try {
        // First, get subscriptions
        let query = supabaseAdmin
          .from('user_subscriptions')
          .select('*')
          .order('created_at', { ascending: false })
          .limit(50) // Add pagination limit

        if (filters?.status) {
          query = query.eq('status', filters.status)
        }
        if (filters?.plan_id) {
          query = query.eq('subscription_plan_id', filters.plan_id)
        }

        console.log('Hook: Executing subscriptions query...')
        const { data: subscriptions, error: subscriptionError } = await query

        if (subscriptionError) {
          console.error('Hook: Subscription Error:', subscriptionError)
          throw subscriptionError
        }

        // Get all unique user IDs
        const userIds = [...new Set(subscriptions?.map(s => s.user_id) || [])]

        // Fetch user data
        let usersData: any[] = []
        if (userIds.length > 0) {
          console.log('Hook: Fetching user data...')
          const { data: users, error: usersError } = await supabaseAdmin.auth.admin.listUsers()

          if (!usersError && users.users) {
            usersData = users.users
          } else {
            console.log('Hook: Could not fetch users via admin API, trying direct auth query...')
            // Fallback: Try direct auth table query
            const { data: authUsers, error: authError } = await supabaseAdmin
              .from('auth.users')
              .select('id, email, raw_user_meta_data')
              .in('id', userIds)

            if (!authError) {
              usersData = authUsers || []
            }
          }
        }

        // Get subscription plans
        console.log('Hook: Fetching subscription plans...')
        const { data: plans, error: plansError } = await supabaseAdmin
          .from('subscription_plans')
          .select('*')
          .eq('is_active', true)

        if (plansError) {
          console.error('Hook: Plans Error:', plansError)
        }

        // Combine data
        const combinedData = (subscriptions || []).map(subscription => {
          const user = usersData.find(u => u.id === subscription.user_id)
          const plan = (plans || []).find(p => p.id === subscription.subscription_plan_id)

          return {
            ...subscription,
            auth: {
              users: {
                id: user?.id,
                email: user?.email,
                full_name: user?.user_metadata?.full_name || user?.raw_user_meta_data?.full_name || user?.user_metadata?.name || user?.raw_user_meta_data?.name,
                name: user?.user_metadata?.name || user?.raw_user_meta_data?.name
              }
            },
            subscription_plans: plan
          }
        })

        // Apply search filter on combined data
        let filteredData = combinedData
        if (filters?.search) {
          const searchLower = filters.search.toLowerCase()
          filteredData = combinedData.filter(subscription =>
            subscription.auth?.users?.email?.toLowerCase().includes(searchLower) ||
            subscription.auth?.users?.full_name?.toLowerCase().includes(searchLower) ||
            subscription.auth?.users?.name?.toLowerCase().includes(searchLower)
          )
        }

        console.log('Hook: Final result:', { data: filteredData?.length, error: null })
        return filteredData
      } catch (err) {
        console.error('Hook: Exception:', err)
        throw err
      }
    },
    staleTime: 0, // No caching - always fetch fresh data
  })
}

// Hook for fetching subscription plans
export function useSubscriptionPlans() {
  return useQuery({
    queryKey: ['subscription-plans'],
    queryFn: async () => {
      const { data, error } = await supabaseAdmin
        .from('subscription_plans')
        .select('*')
        .eq('is_active', true)

      if (error) throw error
      return data || []
    },
    staleTime: 0, // No caching - always fetch fresh data
  })
}

// Hook for fetching subscription analytics
export function useSubscriptionAnalytics() {
  return useQuery({
    queryKey: ['subscription-analytics'],
    queryFn: async (): Promise<SubscriptionAnalytics> => {
      try {
        const [
          subscriptionsResult,
          plansResult,
          paymentsResult
        ] = await Promise.allSettled([
        // Fetch all subscriptions for analytics
        supabaseAdmin
          .from('user_subscriptions')
          .select('status, subscription_plan_id, start_date, end_date, created_at'),

        // Fetch active plans for revenue calculation
        supabaseAdmin
          .from('subscription_plans')
          .select('id, price, duration_days, is_active')
          .eq('is_active', true),

        // Fetch all completed payments for revenue
        supabaseAdmin
          .from('payments')
          .select('amount_cents, created_at, status')
          .eq('status', 'completed')
      ])

      const subscriptions = subscriptionsResult.status === 'fulfilled' ? subscriptionsResult.value.data || [] : []
      const plans = plansResult.status === 'fulfilled' ? plansResult.value.data || [] : []
      const payments = paymentsResult.status === 'fulfilled' ? paymentsResult.value.data || [] : []

      // Calculate subscription counts
      const totalSubscriptions = subscriptions.length
      const activeSubscriptions = subscriptions.filter(s => s.status === 'active').length
      const trialSubscriptions = 0 // No trial status in current database
      const expiredSubscriptions = subscriptions.filter(s => s.status === 'expired').length
      const cancelledSubscriptions = subscriptions.filter(s => s.status === 'cancelled').length

      // Calculate revenue (amount_cents field is already in cents according to schema)
      const totalRevenue = payments.reduce((sum, payment) => sum + payment.amount_cents, 0) / 100

      // Calculate monthly and annual revenue
      const currentMonth = new Date().getMonth()
      const currentYear = new Date().getFullYear()
      const monthlyPayments = payments.filter(payment => {
        const paymentDate = new Date(payment.created_at)
        return paymentDate.getMonth() === currentMonth && paymentDate.getFullYear() === currentYear
      })
      const monthlyRevenue = monthlyPayments.reduce((sum, payment) => sum + payment.amount_cents, 0) / 100

      // Calculate MRR and ARR
      const activePlanIds = [...new Set(subscriptions.filter((s: any) => s.status === 'active').map((s: any) => s.subscription_plan_id))]
      const planMap = plans.reduce((acc, plan) => {
        acc[plan.id] = plan
        return acc
      }, {} as Record<string, any>)

      let mrr = 0
      subscriptions.filter((s: any) => s.status === 'active').forEach((subscription: any) => {
        const plan = planMap[subscription.subscription_plan_id]
        if (plan) {
          // Convert price from numeric to monthly rate
          const monthlyAmount = plan.duration_days >= 365
            ? Number(plan.price) / 12  // Yearly plan, convert to monthly
            : Number(plan.price)       // Monthly plan, use as is
          mrr += monthlyAmount
        }
      })
      // mrr is already in dollars (database stores price in dollars, not cents)
      const arr = mrr * 12

      // Calculate churn rate (simplified)
      const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
      const recentCancellations = subscriptions.filter((s: any) =>
        s.status === 'cancelled' && new Date(s.updated_at || s.created_at) > thirtyDaysAgo
      ).length
      const churnRate = activeSubscriptions > 0 ? (recentCancellations / activeSubscriptions) * 100 : 0

      // Calculate new subscriptions and cancellations this month
      const thisMonth = new Date().toISOString().slice(0, 7) // YYYY-MM format
      const newSubscriptionsThisMonth = subscriptions.filter((s: any) =>
        s.created_at.startsWith(thisMonth)
      ).length
      const cancellationsThisMonth = subscriptions.filter((s: any) =>
        s.status === 'cancelled' && (s.updated_at || s.created_at).startsWith(thisMonth)
      ).length

      return {
        totalSubscriptions,
        activeSubscriptions,
        trialSubscriptions,
        expiredSubscriptions,
        cancelledSubscriptions,
        monthlyRevenue,
        annualRevenue: monthlyRevenue * 12, // Simplified
        totalRevenue,
        churnRate,
        mrr,
        arr,
        newSubscriptionsThisMonth,
        cancellationsThisMonth
      }
    } catch (error) {
      // Fallback data if queries fail
      console.warn('Subscription analytics query failed, using fallback:', error)
      return {
        totalSubscriptions: 0,
        activeSubscriptions: 0,
        trialSubscriptions: 0,
        expiredSubscriptions: 0,
        cancelledSubscriptions: 0,
        monthlyRevenue: 0,
        annualRevenue: 0,
        totalRevenue: 0,
        churnRate: 0,
        mrr: 0,
        arr: 0,
        newSubscriptionsThisMonth: 0,
        cancellationsThisMonth: 0
      }
    }
    },
    staleTime: 0, // No caching - always fetch fresh data
  })
}

// Hook for fetching payments
export function usePayments(filters?: {
  status?: string
  user_id?: string
  search?: string
  date_from?: string
  date_to?: string
}) {
  return useQuery({
    queryKey: ['payments', filters],
    queryFn: async () => {
      console.log('Hook: Starting payments fetch...')
      try {
        // First, get payments
        let query = supabaseAdmin
          .from('payments')
          .select('*')
          .order('created_at', { ascending: false })
          .limit(50)

        if (filters?.status) {
          query = query.eq('status', filters.status)
        }
        if (filters?.user_id) {
          query = query.eq('user_id', filters.user_id)
        }
        if (filters?.date_from) {
          query = query.gte('created_at', filters.date_from)
        }
        if (filters?.date_to) {
          query = query.lte('created_at', filters.date_to)
        }

        console.log('Hook: Executing payments query...')
        const { data: payments, error: paymentError } = await query

        if (paymentError) {
          console.error('Hook: Payments Error:', paymentError)
          throw paymentError
        }

        // Get all unique user IDs from payments
        const userIds = [...new Set(payments?.map(p => p.user_id) || [])]

        // Fetch user data from profiles table (not auth.users)
        let profilesData: any[] = []
        if (userIds.length > 0) {
          console.log('Hook: Fetching user data from profiles...')
          const { data: profiles, error: profilesError } = await supabaseAdmin
            .from('profiles')
            .select('id, email, full_name')
            .in('id', userIds)

          if (profilesError) {
            console.error('Hook: Profiles Error:', profilesError)
          } else {
            profilesData = profiles || []
          }
        }

        // Combine payments with user data
        const combinedData = (payments || []).map(payment => {
          const profile = profilesData.find(p => p.id === payment.user_id)

          return {
            ...payment,
            profiles: profile || {
              id: payment.user_id,
              email: 'No email',
              full_name: payment.user_name || 'Unknown User'
            }
          }
        })

        // Apply search filter on combined data
        let filteredData = combinedData
        if (filters?.search) {
          const searchLower = filters.search.toLowerCase()
          filteredData = combinedData.filter(payment =>
            payment.profiles?.full_name?.toLowerCase().includes(searchLower) ||
            payment.profiles?.email?.toLowerCase().includes(searchLower) ||
            payment.description?.toLowerCase().includes(searchLower) ||
            payment.user_name?.toLowerCase().includes(searchLower)
          )
        }

        console.log('Hook: Final payments result:', { data: filteredData?.length, error: null })
        return filteredData
      } catch (err) {
        console.error('Hook: Payments Exception:', err)
        throw err
      }
    },
    staleTime: 0, // No caching - always fetch fresh data
  })
}

// Mutation for updating subscription status
export function useUpdateSubscriptionStatus() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async ({
      subscriptionId,
      status,
      cancelAtPeriodEnd = false
    }: {
      subscriptionId: string
      status: string
      cancelAtPeriodEnd?: boolean
    }) => {
      const { data, error } = await supabaseAdmin
        .from('user_subscriptions')
        .update({
          status,
          cancel_at_period_end: cancelAtPeriodEnd,
          updated_at: new Date().toISOString()
        })
        .eq('id', subscriptionId)
        .select()
        .single()

      if (error) throw error
      return data
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['subscriptions'] })
      queryClient.invalidateQueries({ queryKey: ['subscription-analytics'] })
      queryClient.invalidateQueries({ queryKey: ['dashboard'] })
    },
  })
}

// Hook for real-time subscription updates
export function useRealTimeSubscriptions() {
  const queryClient = useQueryClient()

  useEffect(() => {
    const channels = [
      // Listen for subscription changes
      supabaseAdmin
        .channel('subscription_changes')
        .on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table: 'user_subscriptions'
          },
          () => {
            queryClient.invalidateQueries({ queryKey: ['subscriptions'] })
            queryClient.invalidateQueries({ queryKey: ['subscription-analytics'] })
            queryClient.invalidateQueries({ queryKey: ['dashboard', 'stats'] })
          }
        )
        .subscribe(),

      // Listen for payment changes
      supabaseAdmin
        .channel('payment_changes')
        .on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table: 'payments'
          },
          () => {
            queryClient.invalidateQueries({ queryKey: ['payments'] })
            queryClient.invalidateQueries({ queryKey: ['subscription-analytics'] })
            queryClient.invalidateQueries({ queryKey: ['dashboard', 'revenue'] })
          }
        )
        .subscribe()
    ]

    return () => {
      channels.forEach(channel => {
        supabaseAdmin.removeChannel(channel)
      })
    }
  }, [queryClient])
}
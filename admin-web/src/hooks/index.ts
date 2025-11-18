// Supabase query hooks
export {
  useSupabaseQuery,
  useSupabaseQueryById,
  useSupabaseCreate,
  useSupabaseUpdate,
  useSupabaseDelete,
  useSupabaseBulkDelete,
  useSupabaseSearch,
} from './use-supabase-query'

// Entity-specific hooks
export {
  useBooks,
  useBook,
  useCreateBook,
  useUpdateBook,
  useDeleteBook,
  useBulkDeleteBooks,
} from './use-books'

export {
  useVideoKitabs,
  useVideoKitab,
  useCreateVideoKitab,
  useUpdateVideoKitab,
  useDeleteVideoKitab,
  useVideoEpisodes,
  useCreateVideoEpisode,
  useUpdateVideoEpisode,
  useDeleteVideoEpisode,
  useBulkDeleteVideoKitabs,
} from './use-videos'

export {
  useCategories,
  useCategory,
  useCreateCategory,
  useUpdateCategory,
  useDeleteCategory,
  useUpdateCategoryOrder,
} from './use-categories'

// Analytics hooks
export {
  useDashboardStats,
  useUserGrowth,
  useContentStats,
  useRevenueData,
  useRecentActivity,
  useCategoryDistribution,
  useTopContent,
  useRealTimeAnalytics,
} from './use-analytics'

// Subscription hooks
export {
  useSubscriptions,
  useSubscriptionPlans,
  useSubscriptionAnalytics,
  usePayments,
  useUpdateSubscriptionStatus,
  useRealTimeSubscriptions,
  type Subscription,
  type SubscriptionPlan,
  type Payment,
  type SubscriptionAnalytics,
} from './use-subscriptions'

// Form hooks
export {
  useForm,
  useFileUpload,
  type UseFormOptions,
  type UseFormReturn,
  type UseFileUploadOptions,
  type UseFileUploadReturn,
} from './use-form'
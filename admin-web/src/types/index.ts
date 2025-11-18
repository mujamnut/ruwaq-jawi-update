// Export all types from central location

// User and Authentication types
export interface User {
  id: string
  email: string
  full_name: string | null
  role: UserRole
  subscription_status: SubscriptionStatus
  phone_number: string | null
  avatar_url: string | null
  created_at: string
  updated_at: string
  last_seen_at: string | null
}

export type UserRole = 'student' | 'admin'
export type SubscriptionStatus = 'active' | 'inactive' | 'expired' | 'cancelled'

// Content types
export interface Category {
  id: string
  name: string
  description: string | null
  icon_url: string | null
  sort_order: number
  is_active: boolean
  created_at: string
  updated_at: string
}

export interface Book {
  id: string
  title: string
  author: string | null
  description: string | null
  category_id: string | null
  pdf_url: string
  pdf_storage_path: string | null
  pdf_file_size: number | null
  thumbnail_url: string | null
  total_pages: number | null
  is_premium: boolean
  is_active: boolean
  created_at: string
  updated_at: string
  average_rating: number
  total_ratings: number
}

export interface VideoKitab {
  id: string
  title: string
  author: string | null
  description: string | null
  category_id: string | null
  pdf_url: string | null
  pdf_storage_path: string | null
  pdf_file_size: number | null
  thumbnail_url: string | null
  total_pages: number | null
  total_videos: number
  total_duration_minutes: number
  is_premium: boolean
  is_active: boolean
  created_at: string
  updated_at: string
  youtube_playlist_id: string | null
  youtube_playlist_url: string | null
  auto_sync_enabled: boolean
  last_synced_at: string | null
  duration: number
  views_count: number
}

export interface VideoEpisode {
  id: string
  title: string
  description: string | null
  youtube_video_id: string
  youtube_video_url: string | null
  thumbnail_url: string | null
  duration_minutes: number
  duration_seconds: number
  part_number: number
  sort_order: number
  is_active: boolean
  is_premium: boolean
  created_at: string
  updated_at: string
  video_kitab_id: string
}

// Payment and Subscription types
export interface SubscriptionPlan {
  id: string
  name: string
  price: number
  currency: string
  duration_days: number
  is_active: boolean
  created_at: string
  updated_at: string
}

export interface Payment {
  id: string
  user_id: string
  amount_cents: number
  currency: string
  status: PaymentStatus
  provider: PaymentProvider
  provider_payment_id: string | null
  payment_intent_id: string | null
  reference_number: string | null
  receipt_url: string | null
  paid_at: string | null
  description: string | null
  raw_payload: Record<string, any>
  metadata: Record<string, any>
  created_at: string
  updated_at: string
  bill_id: string | null
  plan_id: string | null
  user_name: string | null
  activation_type: string
  transaction_data: Record<string, any>
}

export type PaymentStatus =
  | 'requires_action'
  | 'processing'
  | 'succeeded'
  | 'failed'
  | 'refunded'
  | 'canceled'
  | 'pending'
  | 'completed'

export type PaymentProvider =
  | 'stripe'
  | 'toyyibpay'
  | 'hitpay'
  | 'app_store'
  | 'play_store'
  | 'manual'

export interface UserSubscription {
  id: string
  user_id: string | null
  user_name: string | null
  subscription_plan_id: string | null
  status: SubscriptionStatus
  start_date: string | null
  end_date: string | null
  payment_id: string | null
  amount: number
  currency: string
  created_at: string
  updated_at: string
  previous_subscription_id: string | null
  prorated_days: number
  upgrade_reason: string | null
  change_type: 'new' | 'extension' | 'upgrade' | 'downgrade' | 'replacement'
}

// Notification types
export interface Notification {
  id: string
  type: 'broadcast' | 'personal' | 'group'
  title: string
  message: string
  target_type: 'all' | 'user' | 'role'
  target_criteria: Record<string, any>
  metadata: Record<string, any>
  created_at: string
  expires_at: string | null
  is_active: boolean
  delivered_at: string
  updated_at: string
}

export interface NotificationRead {
  id: string
  notification_id: string
  user_id: string
  is_read: boolean
  read_at: string | null
  created_at: string
  deleted_at: string | null
  updated_at: string
}

// Analytics types
export interface DashboardStats {
  totalUsers: number
  totalBooks: number
  totalVideos: number
  totalRevenue: number
  activeSubscriptions: number
  monthlyGrowth: number
}

export interface UserGrowthData {
  date: string
  users: number
  subscriptions: number
}

export interface ContentStats {
  totalBooks: number
  totalVideos: number
  totalVideoKitabs: number
  totalCategories: number
  premiumContent: number
  freeContent: number
}

export interface RevenueData {
  date: string
  revenue: number
  subscriptions: number
}

// Form types
export interface BookFormData {
  title: string
  author: string
  description: string
  category_id: string
  pdf_url: string
  thumbnail_url: string
  total_pages: number
  is_premium: boolean
  is_active: boolean
}

export interface VideoKitabFormData {
  title: string
  author: string
  description: string
  category_id: string
  thumbnail_url: string
  is_premium: boolean
  is_active: boolean
  youtube_playlist_id: string
  auto_sync_enabled: boolean
}

export interface CategoryFormData {
  name: string
  description: string
  icon_url: string
  sort_order: number
  is_active: boolean
}

// API Response types
export interface ApiResponse<T> {
  data: T
  message: string
  success: boolean
}

export interface PaginatedResponse<T> {
  data: T[]
  count: number
  page: number
  pageSize: number
  totalPages: number
}

// Filter and Search types
export interface FilterOptions {
  search?: string
  category?: string
  isPremium?: boolean
  isActive?: boolean
  dateFrom?: string
  dateTo?: string
}

export interface SortOptions {
  field: string
  direction: 'asc' | 'desc'
}

export interface PaginationOptions {
  page: number
  pageSize: number
}

// Table actions types
export interface BulkAction<T> {
  type: 'delete' | 'update' | 'export'
  items: T[]
  data?: Record<string, any>
}

export type TableAction<T> =
  | { type: 'edit'; item: T }
  | { type: 'delete'; item: T }
  | { type: 'view'; item: T }
  | { type: 'duplicate'; item: T }

// Utility types
export type Optional<T, K extends keyof T> = Omit<T, K> & Partial<Pick<T, K>>
export type RequiredFields<T, K extends keyof T> = T & Required<Pick<T, K>>
export type DeepPartial<T> = {
  [P in keyof T]?: T[P] extends object ? DeepPartial<T[P]> : T[P]
}
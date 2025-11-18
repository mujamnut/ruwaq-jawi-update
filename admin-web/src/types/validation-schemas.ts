import { z } from 'zod'

// Common validation schemas
export const paginationSchema = z.object({
  page: z.number().int().min(1).default(1),
  pageSize: z.number().int().min(1).max(100).default(10),
})

export const sortSchema = z.object({
  field: z.string(),
  direction: z.enum(['asc', 'desc']).default('desc'),
})

// Book validation schemas
export const bookFormSchema = z.object({
  title: z.string().min(1, 'Title is required').max(200, 'Title must be less than 200 characters'),
  author: z.string().min(1, 'Author is required').max(100, 'Author must be less than 100 characters'),
  description: z.string().max(1000, 'Description must be less than 1000 characters').optional(),
  category_id: z.string().uuid('Invalid category ID').optional(),
  pdf_url: z.string().url('Invalid PDF URL').min(1, 'PDF URL is required'),
  thumbnail_url: z.string().url('Invalid thumbnail URL').optional(),
  total_pages: z.number().int().min(1, 'Total pages must be at least 1').optional(),
  is_premium: z.boolean().default(false),
  is_active: z.boolean().default(true),
})

export const bookUpdateSchema = bookFormSchema.partial()

// Video Kitab validation schemas
export const videoKitabFormSchema = z.object({
  title: z.string().min(1, 'Title is required').max(200, 'Title must be less than 200 characters'),
  author: z.string().min(1, 'Author is required').max(100, 'Author must be less than 100 characters'),
  description: z.string().max(1000, 'Description must be less than 1000 characters').optional(),
  category_id: z.string().uuid('Invalid category ID').optional(),
  thumbnail_url: z.string().url('Invalid thumbnail URL').optional(),
  is_premium: z.boolean().default(false),
  is_active: z.boolean().default(true),
  youtube_playlist_id: z.string().optional(),
  auto_sync_enabled: z.boolean().default(true),
})

export const videoKitabUpdateSchema = videoKitabFormSchema.partial()

// Video Episode validation schemas
export const videoEpisodeFormSchema = z.object({
  title: z.string().min(1, 'Title is required').max(200, 'Title must be less than 200 characters'),
  description: z.string().max(1000, 'Description must be less than 1000 characters').optional(),
  youtube_video_id: z.string().min(1, 'YouTube video ID is required'),
  thumbnail_url: z.string().url('Invalid thumbnail URL').optional(),
  duration_minutes: z.number().int().min(0, 'Duration must be non-negative').default(0),
  part_number: z.number().int().min(1, 'Part number must be at least 1'),
  is_premium: z.boolean().default(false),
  is_active: z.boolean().default(true),
})

export const videoEpisodeUpdateSchema = videoEpisodeFormSchema.partial()

// Category validation schemas
export const categoryFormSchema = z.object({
  name: z.string().min(1, 'Category name is required').max(100, 'Category name must be less than 100 characters'),
  description: z.string().max(500, 'Description must be less than 500 characters').optional(),
  icon_url: z.string().url('Invalid icon URL').optional(),
  sort_order: z.number().int().min(0, 'Sort order must be non-negative').default(0),
  is_active: z.boolean().default(true),
})

export const categoryUpdateSchema = categoryFormSchema.partial()

// User profile validation schemas
export const userUpdateSchema = z.object({
  full_name: z.string().min(1, 'Full name is required').max(100, 'Full name must be less than 100 characters'),
  phone_number: z.string().regex(/^[+]?[\d\s\-\(\)]+$/, 'Invalid phone number format').optional(),
  avatar_url: z.string().url('Invalid avatar URL').optional(),
  role: z.enum(['student', 'admin']).optional(),
  subscription_status: z.enum(['active', 'inactive', 'expired', 'cancelled']).optional(),
})

// Search and filter schemas
export const searchSchema = z.object({
  query: z.string().min(1, 'Search query is required').max(100, 'Search query must be less than 100 characters'),
  filters: z.object({
    category_id: z.string().uuid().optional(),
    is_premium: z.boolean().optional(),
    is_active: z.boolean().optional(),
    date_from: z.string().datetime().optional(),
    date_to: z.string().datetime().optional(),
  }).optional(),
  sort: sortSchema.optional(),
  pagination: paginationSchema.optional(),
})

// Notification validation schemas
export const notificationFormSchema = z.object({
  type: z.enum(['broadcast', 'personal', 'group']),
  title: z.string().min(1, 'Title is required').max(200, 'Title must be less than 200 characters'),
  message: z.string().min(1, 'Message is required').max(1000, 'Message must be less than 1000 characters'),
  target_type: z.enum(['all', 'user', 'role']),
  target_criteria: z.object({
    user_ids: z.array(z.string().uuid()).optional(),
    target_roles: z.array(z.enum(['student', 'admin'])).optional(),
  }).optional(),
  metadata: z.object({
    icon: z.string().optional(),
    action_url: z.string().url().optional(),
    priority: z.enum(['low', 'medium', 'high']).default('medium'),
  }).optional(),
  expires_at: z.string().datetime().optional(),
  is_active: z.boolean().default(true),
})

// Payment validation schemas
export const paymentCreateSchema = z.object({
  user_id: z.string().uuid('Invalid user ID'),
  amount_cents: z.number().int().min(1, 'Amount must be at least 1 cent'),
  currency: z.string().length(3, 'Currency must be a 3-letter code').default('MYR'),
  plan_id: z.string().min(1, 'Plan ID is required'),
  user_name: z.string().min(1, 'User name is required'),
  activation_type: z.string().default('api'),
  description: z.string().max(500, 'Description must be less than 500 characters').optional(),
})

// Subscription plan validation schemas
export const subscriptionPlanSchema = z.object({
  id: z.string().min(1, 'Plan ID is required'),
  name: z.string().min(1, 'Plan name is required').max(100, 'Plan name must be less than 100 characters'),
  price: z.number().min(0, 'Price must be non-negative'),
  currency: z.string().length(3, 'Currency must be a 3-letter code').default('MYR'),
  duration_days: z.number().int().min(1, 'Duration must be at least 1 day'),
  is_active: z.boolean().default(true),
})

// File upload validation schemas
export const fileUploadSchema = z.object({
  file: z.instanceof(File),
  maxSize: z.number().int().min(1).optional(),
  allowedTypes: z.array(z.string()).optional(),
})

export const imageUploadSchema = fileUploadSchema.extend({
  allowedTypes: z.array(z.string()).default(['image/jpeg', 'image/png', 'image/gif', 'image/webp']),
  maxSize: z.number().int().default(5 * 1024 * 1024), // 5MB
})

export const pdfUploadSchema = fileUploadSchema.extend({
  allowedTypes: z.array(z.string()).default(['application/pdf']),
  maxSize: z.number().int().default(50 * 1024 * 1024), // 50MB
})

// Bulk operation validation schemas
export const bulkDeleteSchema = z.object({
  ids: z.array(z.string().uuid()).min(1, 'At least one ID is required'),
  confirm: z.boolean().refine(val => val === true, 'You must confirm the deletion'),
})

export const bulkUpdateSchema = z.object({
  ids: z.array(z.string().uuid()).min(1, 'At least one ID is required'),
  data: z.record(z.string(), z.any()),
})

// Export validation schemas
export const exportSchema = z.object({
  format: z.enum(['csv', 'excel', 'json']).default('csv'),
  filters: z.object({
    category_id: z.string().uuid().optional(),
    is_premium: z.boolean().optional(),
    is_active: z.boolean().optional(),
    date_from: z.string().datetime().optional(),
    date_to: z.string().datetime().optional(),
  }).optional(),
  fields: z.array(z.string()).optional(),
})

// Type exports
export type BookFormData = z.infer<typeof bookFormSchema>
export type BookUpdateData = z.infer<typeof bookUpdateSchema>
export type VideoKitabFormData = z.infer<typeof videoKitabFormSchema>
export type VideoKitabUpdateData = z.infer<typeof videoKitabUpdateSchema>
export type VideoEpisodeFormData = z.infer<typeof videoEpisodeFormSchema>
export type VideoEpisodeUpdateData = z.infer<typeof videoEpisodeUpdateSchema>
export type CategoryFormData = z.infer<typeof categoryFormSchema>
export type CategoryUpdateData = z.infer<typeof categoryUpdateSchema>
export type UserUpdateData = z.infer<typeof userUpdateSchema>
export type SearchFormData = z.infer<typeof searchSchema>
export type NotificationFormData = z.infer<typeof notificationFormSchema>
export type PaymentCreateData = z.infer<typeof paymentCreateSchema>
export type SubscriptionPlanData = z.infer<typeof subscriptionPlanSchema>
export type BulkDeleteData = z.infer<typeof bulkDeleteSchema>
export type BulkUpdateData = z.infer<typeof bulkUpdateSchema>
export type ExportData = z.infer<typeof exportSchema>
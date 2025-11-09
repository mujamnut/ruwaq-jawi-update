import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

// Database types
export interface Database {
  public: {
    Tables: {
      ebooks: {
        Row: {
          id: string
          title: string
          author: string
          description: string
          category_id: string
          pdf_url: string
          thumbnail_url: string
          total_pages: number
          is_premium: boolean
          is_active: boolean
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          title: string
          author?: string
          description?: string
          category_id?: string
          pdf_url: string
          thumbnail_url?: string
          total_pages?: number
          is_premium?: boolean
          is_active?: boolean
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          title?: string
          author?: string
          description?: string
          category_id?: string
          pdf_url?: string
          thumbnail_url?: string
          total_pages?: number
          is_premium?: boolean
          is_active?: boolean
          updated_at?: string
        }
      }
      categories: {
        Row: {
          id: string
          name: string
          description: string
          icon_url: string
          sort_order: number
          is_active: boolean
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          name: string
          description?: string
          icon_url?: string
          sort_order?: number
          is_active?: boolean
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          name?: string
          description?: string
          icon_url?: string
          sort_order?: number
          is_active?: boolean
          updated_at?: string
        }
      }
      video_kitab: {
        Row: {
          id: string
          title: string
          author: string
          description: string
          category_id: string
          thumbnail_url: string
          total_videos: number
          total_duration_minutes: number
          is_premium: boolean
          is_active: boolean
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          title: string
          author?: string
          description?: string
          category_id?: string
          thumbnail_url?: string
          total_videos?: number
          total_duration_minutes?: number
          is_premium?: boolean
          is_active?: boolean
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          title?: string
          author?: string
          description?: string
          category_id?: string
          thumbnail_url?: string
          total_videos?: number
          total_duration_minutes?: number
          is_premium?: boolean
          is_active?: boolean
          updated_at?: string
        }
      }
      video_episodes: {
        Row: {
          id: string
          title: string
          description: string
          youtube_video_id: string
          thumbnail_url: string
          duration_minutes: number
          part_number: number
          sort_order: number
          is_active: boolean
          created_at: string
          updated_at: string
          video_kitab_id: string
          is_premium: boolean
        }
        Insert: {
          id?: string
          title: string
          description?: string
          youtube_video_id: string
          thumbnail_url?: string
          duration_minutes?: number
          part_number: number
          sort_order?: number
          is_active?: boolean
          created_at?: string
          updated_at?: string
          video_kitab_id: string
          is_premium?: boolean
        }
        Update: {
          id?: string
          title?: string
          description?: string
          youtube_video_id?: string
          thumbnail_url?: string
          duration_minutes?: number
          part_number?: number
          sort_order?: number
          is_active?: boolean
          updated_at?: string
          video_kitab_id?: string
          is_premium?: boolean
        }
      }
    }
  }
}
'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import DashboardLayout from "@/components/dashboard-layout"
import { supabaseAdmin } from '@/lib/supabase'
import {
  ArrowLeft,
  Bell,
  Send,
  X,
  Save,
  Info,
  CheckCircle,
  AlertTriangle,
  XCircle,
  Users,
  User,
  Calendar,
  Link,
  Eye
} from 'lucide-react'

interface FormData {
  title: string
  message: string
  type: 'broadcast' | 'personal' | 'group'
  target_type: 'all' | 'user' | 'role'
  custom_emails: string
  action_url: string
  action_text: string
  expires_at: string
  send_immediately: boolean
}

export default function NewNotificationPage() {
  const router = useRouter()
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState(false)
  const [previewMode, setPreviewMode] = useState(false)

  const [formData, setFormData] = useState<FormData>({
    title: '',
    message: '',
    type: 'broadcast',
    target_type: 'all',
    custom_emails: '',
    action_url: '',
    action_text: '',
    expires_at: '',
    send_immediately: true
  })

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target
    setFormData(prev => ({
      ...prev,
      [name]: value
    }))

    // Clear error when user starts typing
    if (error) {
      setError(null)
    }
  }

  const validateForm = () => {
    if (!formData.title.trim()) {
      setError('Notification title is required')
      return false
    }

    if (!formData.message.trim()) {
      setError('Notification message is required')
      return false
    }

    if (formData.target_type === 'user' && !formData.custom_emails.trim()) {
      setError('Custom recipient emails are required')
      return false
    }

    return true
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    if (!validateForm()) {
      return
    }

    setLoading(true)
    setError(null)

    try {
      // Convert form data to database format
      const notificationData = {
        type: formData.type,
        title: formData.title.trim(),
        message: formData.message.trim(),
        target_type: formData.target_type,
        target_criteria: formData.target_type === 'user' ? {
          emails: formData.custom_emails.split(',').map(email => email.trim()).filter(email => email)
        } : formData.target_type === 'role' ? {
          roles: ['student'] // Default to student role for now
        } : {},
        expires_at: formData.expires_at ? new Date(formData.expires_at).toISOString() : null,
        metadata: {
          action_url: formData.action_url || null,
          action_text: formData.action_text || null
        },
        is_active: true,
        delivered_at: formData.send_immediately ? new Date().toISOString() : null
      }

      // Save to Supabase database
      const { data, error } = await supabaseAdmin
        .from('notifications')
        .insert([notificationData])
        .select()

      if (error) {
        console.error('Supabase error:', error)
        throw new Error(`Database error: ${error.message}`)
      }

      if (data && data.length > 0) {
        console.log('Notification created successfully:', data[0])
        setSuccess(true)

        // Reset form after successful submission
        setFormData({
          title: '',
          message: '',
          type: 'broadcast',
          target_type: 'all',
          custom_emails: '',
          action_url: '',
          action_text: '',
          expires_at: '',
          send_immediately: true
        })

        // Redirect after a delay to show success message
        setTimeout(() => {
          router.push('/notifications')
        }, 2000)
      } else {
        throw new Error('No data returned from database insert')
      }
    } catch (err: any) {
      console.error('Error creating notification:', err)
      setError(err.message || 'An unexpected error occurred while creating the notification. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  const getNotificationIcon = (type: FormData['type']) => {
    switch (type) {
      case 'broadcast':
        return <Bell className="w-6 h-6 text-blue-500" />
      case 'personal':
        return <User className="w-6 h-6 text-green-500" />
      case 'group':
        return <Users className="w-6 h-6 text-amber-500" />
      default:
        return <Bell className="w-6 h-6 text-gray-500" />
    }
  }

  const getTypeColor = (type: FormData['type']) => {
    switch (type) {
      case 'broadcast':
        return 'border-blue-500 bg-blue-50 dark:bg-blue-500/10'
      case 'personal':
        return 'border-green-500 bg-green-50 dark:bg-green-500/10'
      case 'group':
        return 'border-amber-500 bg-amber-50 dark:bg-amber-500/10'
      default:
        return 'border-gray-500 bg-gray-50 dark:bg-gray-500/10'
    }
  }

  const getPreviewNotification = () => {
    return {
      title: formData.title || 'Notification Title',
      message: formData.message || 'This is a preview of your notification message.',
      type: formData.type,
      status: 'unread' as const,
      created_at: new Date().toISOString(),
      action_url: formData.action_url,
      action_text: formData.action_text
    }
  }

  return (
    <DashboardLayout title="New Notification" subtitle="Create a new system notification">
      <main className="flex-1 px-4 sm:px-6 pb-8 pt-4 mx-auto max-w-full bg-gray-50 dark:bg-gradient-to-br dark:from-slate-950 dark:via-slate-950 dark:to-slate-900 transition-colors duration-300">
        {/* Header */}
        <div className="mb-6">
          <button
            onClick={() => router.back()}
            className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-white dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80 text-[11px] font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-100/90 dark:hover:bg-slate-700/90 transition-all"
          >
            <ArrowLeft className="w-4 h-4" />
            Back to Notifications
          </button>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Form */}
          <div className="lg:col-span-2">
            {/* Success Message */}
            {success && (
              <div className="mb-6 p-4 rounded-xl bg-emerald-50 dark:bg-emerald-500/10 border border-emerald-200 dark:border-emerald-500/40">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-emerald-500/20 dark:bg-emerald-500/30 flex items-center justify-center">
                    <CheckCircle className="w-5 h-5 text-emerald-600 dark:text-emerald-400" />
                  </div>
                  <div>
                    <h3 className="font-medium text-emerald-900 dark:text-emerald-300">Notification Created Successfully!</h3>
                    <p className="text-sm text-emerald-700 dark:text-emerald-400 mt-0.5">
                      The notification has been created and will be sent to the recipients.
                    </p>
                  </div>
                </div>
              </div>
            )}

            {/* Error Message */}
            {error && (
              <div className="mb-6 p-4 rounded-xl bg-rose-50 dark:bg-rose-500/10 border border-rose-200 dark:border-rose-500/40">
                <div className="flex items-start gap-3">
                  <div className="w-10 h-10 rounded-xl bg-rose-500/20 dark:bg-rose-500/30 flex items-center justify-center flex-shrink-0 mt-0.5">
                    <X className="w-5 h-5 text-rose-600 dark:text-rose-400" />
                  </div>
                  <div>
                    <h3 className="font-medium text-rose-900 dark:text-rose-300">Error</h3>
                    <p className="text-sm text-rose-700 dark:text-rose-400 mt-0.5">{error}</p>
                  </div>
                </div>
              </div>
            )}

            {/* Form Card */}
            <div className="card rounded-2xl p-6 sm:p-8 bg-white dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80">
              <form onSubmit={handleSubmit} className="space-y-6">
                {/* Title and Type */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div>
                    <label className="block text-xs font-semibold text-gray-900 dark:text-white mb-1.5">
                      <Bell className="w-3.5 h-3.5 inline mr-1.5 text-orange-500 dark:text-orange-400" />
                      Notification Title
                    </label>
                    <input
                      type="text"
                      name="title"
                      value={formData.title}
                      onChange={handleInputChange}
                      placeholder="Enter notification title"
                      disabled={loading}
                      className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-orange-500/50 dark:focus:ring-orange-400/50 focus:border-orange-500/50 dark:focus:border-orange-400/50 disabled:opacity-50"
                      required
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-gray-900 dark:text-white mb-1.5">
                      Type
                    </label>
                    <select
                      name="type"
                      value={formData.type}
                      onChange={handleInputChange}
                      disabled={loading}
                      className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-orange-500/50 dark:focus:ring-orange-400/50 focus:border-orange-500/50 dark:focus:border-orange-400/50 disabled:opacity-50"
                    >
                      <option value="broadcast">Broadcast (All Users)</option>
                      <option value="personal">Personal (Specific Users)</option>
                      <option value="group">Group (By Role)</option>
                    </select>
                  </div>
                </div>

                {/* Message */}
                <div>
                  <label className="block text-xs font-semibold text-gray-900 dark:text-white mb-1.5">
                    Message
                  </label>
                  <textarea
                    name="message"
                    value={formData.message}
                    onChange={handleInputChange}
                    placeholder="Enter notification message"
                    rows={4}
                    disabled={loading}
                    className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-orange-500/50 dark:focus:ring-orange-400/50 focus:border-orange-500/50 dark:focus:border-orange-400/50 disabled:opacity-50 resize-none"
                    required
                  />
                  <p className="mt-1 text-[10px] text-gray-500 dark:text-gray-400">
                    {formData.message.length}/500 characters
                  </p>
                </div>

                {/* Recipient and Priority */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div>
                    <label className="block text-xs font-semibold text-gray-900 dark:text-white mb-1.5">
                      <Users className="w-3.5 h-3.5 inline mr-1.5 text-orange-500 dark:text-orange-400" />
                      Recipient
                    </label>
                    <select
                      name="target_type"
                      value={formData.target_type}
                      onChange={handleInputChange}
                      disabled={loading}
                      className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-orange-500/50 dark:focus:ring-orange-400/50 focus:border-orange-500/50 dark:focus:border-orange-400/50 disabled:opacity-50"
                    >
                      <option value="all">All Users</option>
                      <option value="role">Specific Role</option>
                      <option value="user">Custom Emails</option>
                    </select>
                    <p className="mt-1 text-[10px] text-gray-500 dark:text-gray-400">
                      Who should receive this notification
                    </p>
                  </div>
                </div>

                {/* Custom Emails (shown only when target_type is 'user') */}
                {formData.target_type === 'user' && (
                  <div>
                    <label className="block text-xs font-semibold text-gray-900 dark:text-white mb-1.5">
                      <Users className="w-3.5 h-3.5 inline mr-1.5 text-orange-500 dark:text-orange-400" />
                      Custom Recipient Emails
                    </label>
                    <textarea
                      name="custom_emails"
                      value={formData.custom_emails}
                      onChange={handleInputChange}
                      placeholder="Enter email addresses separated by commas"
                      rows={3}
                      disabled={loading}
                      className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-orange-500/50 dark:focus:ring-orange-400/50 focus:border-orange-500/50 dark:focus:border-orange-400/50 disabled:opacity-50 resize-none"
                    />
                    <p className="mt-1 text-[10px] text-gray-500 dark:text-gray-400">
                      Separate multiple email addresses with commas
                    </p>
                  </div>
                )}

                {/* Action URL and Text */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div>
                    <label className="block text-xs font-semibold text-gray-900 dark:text-white mb-1.5">
                      <Link className="w-3.5 h-3.5 inline mr-1.5 text-orange-500 dark:text-orange-400" />
                      Action URL (Optional)
                    </label>
                    <input
                      type="url"
                      name="action_url"
                      value={formData.action_url}
                      onChange={handleInputChange}
                      placeholder="https://example.com/action"
                      disabled={loading}
                      className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-orange-500/50 dark:focus:ring-orange-400/50 focus:border-orange-500/50 dark:focus:border-orange-400/50 disabled:opacity-50"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-gray-900 dark:text-white mb-1.5">
                      Action Button Text (Optional)
                    </label>
                    <input
                      type="text"
                      name="action_text"
                      value={formData.action_text}
                      onChange={handleInputChange}
                      placeholder="View Details"
                      disabled={loading}
                      className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-xs text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-orange-500/50 dark:focus:ring-orange-400/50 focus:border-orange-500/50 dark:focus:border-orange-400/50 disabled:opacity-50"
                    />
                  </div>
                </div>

                
                {/* Form Actions */}
                <div className="flex items-center justify-between pt-6 border-t border-gray-200 dark:border-slate-600">
                  <div className="flex items-center gap-3">
                    <button
                      type="button"
                      onClick={() => setPreviewMode(!previewMode)}
                      className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-[11px] font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-100/90 dark:hover:bg-slate-600/80 transition-all"
                    >
                      <Eye className="w-4 h-4" />
                      {previewMode ? 'Hide' : 'Show'} Preview
                    </button>
                  </div>
                  <div className="flex items-center gap-3">
                    <button
                      type="button"
                      onClick={() => router.back()}
                      disabled={loading}
                      className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-white dark:bg-slate-700/80 border border-gray-300/80 dark:border-slate-600/80 text-[11px] font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-100/90 dark:hover:bg-slate-600/80 disabled:opacity-50 transition-all"
                    >
                      <X className="w-4 h-4" />
                      Cancel
                    </button>
                    <button
                      type="submit"
                      disabled={loading}
                      className="inline-flex items-center gap-2 px-6 py-2 rounded-xl bg-gradient-to-r from-orange-600 to-red-600 text-white text-xs font-medium hover:from-orange-700 hover:to-red-700 transition-all shadow-lg disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      {loading ? (
                        <>
                          <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                          Creating...
                        </>
                      ) : (
                        <>
                          <Send className="w-4 h-4" />
                          Send Notification
                        </>
                      )}
                    </button>
                  </div>
                </div>
              </form>
            </div>
          </div>

          {/* Preview Panel */}
          <div className="lg:col-span-1">
            <div className="card rounded-2xl p-6 bg-white dark:bg-slate-800/90 border border-gray-300/80 dark:border-slate-600/80 sticky top-6">
              <div className="flex items-center gap-2 mb-4">
                <Eye className="w-4 h-4 text-orange-500 dark:text-orange-400" />
                <h3 className="text-sm font-semibold text-gray-900 dark:text-white">Preview</h3>
              </div>

              <div className={`relative p-4 rounded-xl border-2 ${getTypeColor(formData.type)}`}>
                <div className="flex items-start gap-3">
                  {/* Icon */}
                  <div className="mt-0.5">
                    {getNotificationIcon(formData.type)}
                  </div>

                  {/* Content */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      <h4 className="text-sm font-medium text-gray-900 dark:text-white truncate">
                        {formData.title || 'Notification Title'}
                      </h4>
                      <span className={`px-2 py-0.5 rounded-full text-[10px] border ${
                        formData.type === 'info' ? 'bg-blue-500/10 text-blue-600 dark:text-blue-400 border-blue-500/40 dark:border-blue-400/40' :
                        formData.type === 'success' ? 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border-emerald-500/40 dark:border-emerald-400/40' :
                        formData.type === 'warning' ? 'bg-amber-500/10 text-amber-600 dark:text-amber-400 border-amber-500/40 dark:border-amber-400/40' :
                        'bg-rose-500/10 text-rose-600 dark:text-rose-400 border-rose-500/40 dark:border-rose-400/40'
                      }`}>
                        {formData.type}
                      </span>
                      <span className="px-2 py-0.5 rounded-full bg-blue-500/10 text-[10px] text-blue-600 dark:text-blue-400 border border-blue-500/40 dark:border-blue-400/40">
                        New
                      </span>
                    </div>
                    <p className="text-xs text-gray-600 dark:text-gray-400 mb-2">
                      {formData.message || 'This is a preview of your notification message.'}
                    </p>
                    <div className="flex items-center gap-4 text-[10px] text-gray-500 dark:text-gray-400 mb-2">
                      <div className="flex items-center gap-1">
                        <Calendar className="w-3 h-3" />
                        Just now
                      </div>
                      <div className="flex items-center gap-1">
                        <User className="w-3 h-3" />
                        {formData.target_type === 'all' ? 'All Users' :
                         formData.target_type === 'role' ? 'Specific Role' : 'Custom Users'}
                      </div>
                    </div>
                    {formData.action_url && formData.action_text && (
                      <div className="mt-2">
                        <a
                          href="#"
                          className="inline-flex items-center gap-1 text-xs text-orange-600 dark:text-orange-400 hover:text-orange-700 dark:hover:text-orange-300"
                          onClick={(e) => e.preventDefault()}
                        >
                          {formData.action_text}
                          <Eye className="w-3 h-3" />
                        </a>
                      </div>
                    )}
                  </div>
                </div>
              </div>

              <div className="mt-4 space-y-3">
                <div className="text-[10px] text-gray-600 dark:text-gray-400">
                  <div className="flex justify-between">
                    <span>Type:</span>
                    <span className="font-medium capitalize">{formData.type}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Target:</span>
                    <span className="font-medium capitalize">
                      {formData.target_type === 'all' ? 'All Users' :
                       formData.target_type === 'role' ? 'Specific Role' : 'Custom Users'}
                    </span>
                  </div>
                  {formData.action_url && (
                    <div className="flex justify-between">
                      <span>Has Action:</span>
                      <span className="font-medium">Yes</span>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </DashboardLayout>
  )
}
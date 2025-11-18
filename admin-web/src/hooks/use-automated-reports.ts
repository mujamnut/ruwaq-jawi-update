import { useState, useEffect, useCallback } from 'react'
import { supabase } from '../lib/supabase'

export interface ReportTemplate {
  id: string
  name: string
  description: string
  type: 'content' | 'users' | 'revenue' | 'engagement' | 'performance' | 'custom'
  format: 'pdf' | 'excel' | 'csv' | 'json'
  frequency: 'once' | 'daily' | 'weekly' | 'monthly' | 'quarterly'
  scheduled_at?: string
  status: 'active' | 'inactive' | 'paused'
  recipients: string[]
  parameters: Record<string, any>
  filters: Record<string, any>
  created_at: string
  updated_at?: string
  last_run?: string
  next_run?: string
  run_count: number
  success_count: number
  error_count: number
}

export interface GeneratedReport {
  id: string
  template_id: string
  template_name: string
  type: ReportTemplate['type']
  format: ReportTemplate['format']
  status: 'generating' | 'completed' | 'failed' | 'expired'
  file_url?: string
  file_size?: number
  generated_at: string
  expires_at?: string
  download_count: number
  parameters: Record<string, any>
  metrics: {
    records_count: number
    generation_time: number
    file_size: number
  }
  error_message?: string
}

export interface ReportAnalytics {
  totalTemplates: number
  activeTemplates: number
  totalReports: number
  completedReports: number
  failedReports: number
  totalDownloads: number
  averageGenerationTime: number
  successRate: number
  popularReportTypes: Record<string, number>
  monthlyTrends: Array<{
    month: string
    reports: number
    successRate: number
    avgGenerationTime: number
  }>
}

export function useAutomatedReports() {
  const [templates, setTemplates] = useState<ReportTemplate[]>([])
  const [reports, setReports] = useState<GeneratedReport[]>([])
  const [analytics, setAnalytics] = useState<ReportAnalytics | null>(null)
  const [loading, setLoading] = useState(false)
  const [generating, setGenerating] = useState<string | null>(null)

  // Fetch templates and reports
  const fetchData = useCallback(async () => {
    try {
      setLoading(true)
      const [templatesResult, reportsResult] = await Promise.all([
        supabase.from('report_templates').select('*').order('created_at', { ascending: false }),
        supabase.from('generated_reports').select('*').order('generated_at', { ascending: false }).limit(100)
      ])

      if (templatesResult.error) throw templatesResult.error
      if (reportsResult.error) throw reportsResult.error

      setTemplates(templatesResult.data || [])
      setReports(reportsResult.data || [])
      calculateAnalytics(templatesResult.data || [], reportsResult.data || [])
    } catch (error) {
      console.error('Failed to fetch reports data:', error)
    } finally {
      setLoading(false)
    }
  }, [])

  // Calculate analytics
  const calculateAnalytics = useCallback((templatesData: ReportTemplate[], reportsData: GeneratedReport[]) => {
    const totalTemplates = templatesData.length
    const activeTemplates = templatesData.filter(t => t.status === 'active').length
    const totalReports = reportsData.length
    const completedReports = reportsData.filter(r => r.status === 'completed').length
    const failedReports = reportsData.filter(r => r.status === 'failed').length
    const totalDownloads = reportsData.reduce((sum, r) => sum + r.download_count, 0)
    const averageGenerationTime = reportsData.length > 0
      ? reportsData.reduce((sum, r) => sum + r.metrics.generation_time, 0) / reportsData.length
      : 0
    const successRate = totalReports > 0 ? (completedReports / totalReports) * 100 : 0

    // Popular report types
    const popularReportTypes = reportsData.reduce((acc, report) => {
      acc[report.type] = (acc[report.type] || 0) + 1
      return acc
    }, {} as Record<string, number>)

    // Monthly trends (last 6 months)
    const monthlyTrends = []
    const now = new Date()
    for (let i = 5; i >= 0; i--) {
      const monthDate = new Date(now.getFullYear(), now.getMonth() - i, 1)
      const monthName = monthDate.toLocaleDateString('en-US', { month: 'short', year: 'numeric' })

      const monthReports = reportsData.filter(report => {
        const reportDate = new Date(report.generated_at)
        return reportDate.getMonth() === monthDate.getMonth() &&
               reportDate.getFullYear() === monthDate.getFullYear()
      })

      const monthCompleted = monthReports.filter(r => r.status === 'completed').length
      const monthSuccessRate = monthReports.length > 0 ? (monthCompleted / monthReports.length) * 100 : 0
      const monthAvgTime = monthReports.length > 0
        ? monthReports.reduce((sum, r) => sum + r.metrics.generation_time, 0) / monthReports.length
        : 0

      monthlyTrends.push({
        month: monthName,
        reports: monthReports.length,
        successRate: monthSuccessRate,
        avgGenerationTime: monthAvgTime
      })
    }

    setAnalytics({
      totalTemplates,
      activeTemplates,
      totalReports,
      completedReports,
      failedReports,
      totalDownloads,
      averageGenerationTime,
      successRate,
      popularReportTypes,
      monthlyTrends
    })
  }, [])

  // Create new template
  const createTemplate = useCallback(async (templateData: Partial<ReportTemplate>) => {
    try {
      const { data, error } = await supabase
        .from('report_templates')
        .insert({
          ...templateData,
          status: 'active',
          run_count: 0,
          success_count: 0,
          error_count: 0,
          created_at: new Date().toISOString()
        })
        .select()
        .single()

      if (error) throw error

      await fetchData()
      return data
    } catch (error) {
      console.error('Failed to create template:', error)
      throw error
    }
  }, [fetchData])

  // Update template
  const updateTemplate = useCallback(async (id: string, updates: Partial<ReportTemplate>) => {
    try {
      const { data, error } = await supabase
        .from('report_templates')
        .update({
          ...updates,
          updated_at: new Date().toISOString()
        })
        .eq('id', id)
        .select()
        .single()

      if (error) throw error

      await fetchData()
      return data
    } catch (error) {
      console.error('Failed to update template:', error)
      throw error
    }
  }, [fetchData])

  // Delete template
  const deleteTemplate = useCallback(async (id: string) => {
    try {
      const { error } = await supabase
        .from('report_templates')
        .delete()
        .eq('id', id)

      if (error) throw error

      await fetchData()
    } catch (error) {
      console.error('Failed to delete template:', error)
      throw error
    }
  }, [fetchData])

  // Generate report from template
  const generateReport = useCallback(async (templateId: string, customParameters?: Record<string, any>) => {
    try {
      setGenerating(templateId)

      const { data, error } = await supabase.rpc('generate_report', {
        template_id: templateId,
        custom_parameters: customParameters || {}
      })

      if (error) throw error

      // Refresh reports
      await fetchData()
      return data
    } catch (error) {
      console.error('Failed to generate report:', error)
      throw error
    } finally {
      setGenerating(null)
    }
  }, [fetchData])

  // Generate report with progress tracking
  const generateReportWithProgress = useCallback(async (
    templateId: string,
    onProgress?: (progress: number) => void
  ) => {
    try {
      setGenerating(templateId)

      // Simulate progress for demonstration
      if (onProgress) {
        onProgress(10)
        await new Promise(resolve => setTimeout(resolve, 500))
        onProgress(30)
        await new Promise(resolve => setTimeout(resolve, 500))
        onProgress(60)
        await new Promise(resolve => setTimeout(resolve, 500))
        onProgress(90)
        await new Promise(resolve => setTimeout(resolve, 300))
        onProgress(100)
      }

      const { data, error } = await supabase.rpc('generate_report', {
        template_id: templateId
      })

      if (error) throw error

      await fetchData()
      return data
    } catch (error) {
      console.error('Failed to generate report:', error)
      throw error
    } finally {
      setGenerating(null)
    }
  }, [fetchData])

  // Download report
  const downloadReport = useCallback(async (reportId: string) => {
    try {
      // Get report data
      const { data: report, error } = await supabase
        .from('generated_reports')
        .select('*')
        .eq('id', reportId)
        .single()

      if (error) throw error
      if (!report?.file_url) throw new Error('Report file not available')

      // Increment download count
      await supabase
        .from('generated_reports')
        .update({ download_count: report.download_count + 1 })
        .eq('id', reportId)

      // Update local state
      setReports(prev => prev.map(r =>
        r.id === reportId
          ? { ...r, download_count: r.download_count + 1 }
          : r
      ))

      // Trigger download
      const link = document.createElement('a')
      link.href = report.file_url
      link.download = `${report.template_name}_${new Date().toISOString().split('T')[0]}.${report.format}`
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)

      return report
    } catch (error) {
      console.error('Failed to download report:', error)
      throw error
    }
  }, [])

  // Share report via email
  const shareReport = useCallback(async (reportId: string, recipients: string[], message?: string) => {
    try {
      const { data, error } = await supabase.rpc('share_report_via_email', {
        report_id: reportId,
        recipients,
        message: message || 'Please find the attached report.'
      })

      if (error) throw error

      return data
    } catch (error) {
      console.error('Failed to share report:', error)
      throw error
    }
  }, [])

  // Delete report
  const deleteReport = useCallback(async (reportId: string) => {
    try {
      const { error } = await supabase
        .from('generated_reports')
        .delete()
        .eq('id', reportId)

      if (error) throw error

      await fetchData()
    } catch (error) {
      console.error('Failed to delete report:', error)
      throw error
    }
  }, [fetchData])

  // Clean up expired reports
  const cleanupExpiredReports = useCallback(async () => {
    try {
      const { error } = await supabase.rpc('cleanup_expired_reports')

      if (error) throw error

      await fetchData()
    } catch (error) {
      console.error('Failed to cleanup expired reports:', error)
      throw error
    }
  }, [fetchData])

  // Get template statistics
  const getTemplateStats = useCallback(async (templateId: string) => {
    try {
      const { data, error } = await supabase.rpc('get_template_stats', {
        template_id: templateId
      })

      if (error) throw error

      return data
    } catch (error) {
      console.error('Failed to get template stats:', error)
      throw error
    }
  }, [])

  // Get reports by date range
  const getReportsByDateRange = useCallback(async (startDate: Date, endDate: Date) => {
    try {
      const { data, error } = await supabase
        .from('generated_reports')
        .select('*')
        .gte('generated_at', startDate.toISOString())
        .lte('generated_at', endDate.toISOString())
        .order('generated_at', { ascending: false })

      if (error) throw error

      return data || []
    } catch (error) {
      console.error('Failed to get reports by date range:', error)
      throw error
    }
  }, [])

  // Get templates by type
  const getTemplatesByType = useCallback(async (type: ReportTemplate['type']) => {
    try {
      const { data, error } = await supabase
        .from('report_templates')
        .select('*')
        .eq('type', type)
        .order('created_at', { ascending: false })

      if (error) throw error

      return data || []
    } catch (error) {
      console.error('Failed to get templates by type:', error)
      throw error
    }
  }, [])

  // Toggle template status
  const toggleTemplateStatus = useCallback(async (templateId: string) => {
    try {
      const template = templates.find(t => t.id === templateId)
      if (!template) throw new Error('Template not found')

      const newStatus = template.status === 'active' ? 'inactive' : 'active'
      await updateTemplate(templateId, { status: newStatus })
    } catch (error) {
      console.error('Failed to toggle template status:', error)
      throw error
    }
  }, [templates, updateTemplate])

  // Duplicate template
  const duplicateTemplate = useCallback(async (templateId: string, newName?: string) => {
    try {
      const template = templates.find(t => t.id === templateId)
      if (!template) throw new Error('Template not found')

      const duplicateData = {
        name: newName || `${template.name} (Copy)`,
        description: template.description,
        type: template.type,
        format: template.format,
        frequency: template.frequency,
        recipients: template.recipients,
        parameters: template.parameters,
        filters: template.filters
      }

      const newTemplate = await createTemplate(duplicateData)
      return newTemplate
    } catch (error) {
      console.error('Failed to duplicate template:', error)
      throw error
    }
  }, [templates, createTemplate])

  // Validate template configuration
  const validateTemplate = useCallback((template: Partial<ReportTemplate>) => {
    const errors: string[] = []

    if (!template.name || template.name.trim().length === 0) {
      errors.push('Template name is required')
    }

    if (!template.type) {
      errors.push('Report type is required')
    }

    if (!template.format) {
      errors.push('Output format is required')
    }

    if (!template.frequency) {
      errors.push('Frequency is required')
    }

    if (template.frequency !== 'once' && !template.scheduled_at) {
      errors.push('Schedule date is required for recurring reports')
    }

    if (template.recipients && template.recipients.length > 0) {
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
      const invalidEmails = template.recipients.filter(email => !emailRegex.test(email))
      if (invalidEmails.length > 0) {
        errors.push(`Invalid email addresses: ${invalidEmails.join(', ')}`)
      }
    }

    return {
      isValid: errors.length === 0,
      errors
    }
  }, [])

  // Real-time subscription
  useEffect(() => {
    const channels = [
      supabase
        .channel('report-templates-changes')
        .on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table: 'report_templates'
          },
          fetchData
        )
        .subscribe(),

      supabase
        .channel('generated-reports-changes')
        .on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table: 'generated_reports'
          },
          fetchData
        )
        .subscribe()
    ]

    return () => {
      channels.forEach(channel => supabase.removeChannel(channel))
    }
  }, [fetchData])

  // Initial fetch
  useEffect(() => {
    fetchData()
  }, [fetchData])

  return {
    templates,
    reports,
    analytics,
    loading,
    generating,
    fetchData,
    createTemplate,
    updateTemplate,
    deleteTemplate,
    generateReport,
    generateReportWithProgress,
    downloadReport,
    shareReport,
    deleteReport,
    cleanupExpiredReports,
    getTemplateStats,
    getReportsByDateRange,
    getTemplatesByType,
    toggleTemplateStatus,
    duplicateTemplate,
    validateTemplate
  }
}
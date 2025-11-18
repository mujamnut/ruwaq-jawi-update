'use client'

import { useState } from 'react'
import DashboardLayout from "@/components/dashboard-layout"
import {
  Settings,
  Database,
  Shield,
  Bell,
  Palette,
  Globe,
  Mail,
  Lock,
  Save,
  RotateCw,
  Download,
  Upload,
  Trash2,
  Eye,
  EyeOff,
  Info,
  CheckCircle,
  XCircle,
  Monitor,
  Key,
  Smartphone,
  FileText,
  Activity,
  Clock,
  Users,
  Zap,
  AlertTriangle,
  Terminal
} from 'lucide-react'
import { supabase } from '@/lib/supabase'

export default function SettingsPage() {
  const [activeTab, setActiveTab] = useState('general')
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null)

  // General settings state
  const [generalSettings, setGeneralSettings] = useState({
    siteName: 'Maktabah Ruwaq Jawi',
    siteDescription: 'Islamic Library Management System',
    adminEmail: 'admin@ruwaq.app',
    maxFileSize: 10,
    allowedFileTypes: ['pdf', 'epub', 'mobi'],
    maintenanceMode: false,
    enableRegistration: true
  })

  // Email settings state
  const [emailSettings, setEmailSettings] = useState({
    smtpHost: '',
    smtpPort: 587,
    smtpUser: '',
    smtpPassword: '',
    fromEmail: 'noreply@ruwaq.app',
    fromName: 'Maktabah Ruwaq Jawi',
    enableEmailNotifications: true
  })

  // Security settings state
  const [securitySettings, setSecuritySettings] = useState({
    sessionTimeout: 24,
    maxLoginAttempts: 5,
    lockoutDuration: 15,
    requireEmailVerification: true,
    enableTwoFactor: false,
    passwordMinLength: 8
  })

  // Database settings state
  const [databaseSettings, setDatabaseSettings] = useState({
    autoBackup: true,
    backupFrequency: 'daily',
    retentionDays: 30,
    enableAnalytics: true,
    maxConnections: 100
  })

  // Theme settings state
  const [themeSettings, setThemeSettings] = useState({
    defaultTheme: 'light',
    primaryColor: '#f97316',
    accentColor: '#3b82f6',
    compactMode: false,
    enableAnimations: true,
    sidebarCollapsed: false
  })

  // API settings state
  const [apiSettings, setApiSettings] = useState({
    googleAnalyticsKey: '',
    youtubeApiKey: '',
    fileUploadUrl: '',
    cdnUrl: '',
    enableApiRateLimit: true,
    apiRateLimit: 100
  })

  // Notification settings state
  const [notificationSettings, setNotificationSettings] = useState({
    enablePushNotifications: true,
    emailAlerts: ['new_user', 'system_error', 'backup_completed'],
    slackWebhook: '',
    discordWebhook: '',
    adminAlerts: true
  })

  // Content settings state
  const [contentSettings, setContentSettings] = useState({
    autoApproveContent: false,
    enableComments: false,
    maxContentSize: 100,
    contentRetentionDays: 365,
    enableContentVersioning: true
  })

  // Monitoring settings state
  const [monitoringSettings, setMonitoringSettings] = useState({
    enableAuditLogs: true,
    logLevel: 'info',
    enableErrorTracking: true,
    performanceMonitoring: true,
    uptimeMonitoring: true
  })

  // Legal settings state
  const [legalSettings, setLegalSettings] = useState({
    privacyPolicyUrl: '',
    termsOfServiceUrl: '',
    gdprCompliance: true,
    cookiePolicy: '',
    dataRetentionPolicy: 365
  })

  // Localization settings state
  const [regionalSettings, setRegionalSettings] = useState({
    defaultLanguage: 'en',
    timezone: 'UTC',
    dateFormat: 'MM/DD/YYYY',
    currency: 'USD',
    numberFormat: 'en-US'
  })

  const tabs = [
    {
      id: 'general',
      label: 'General',
      icon: Settings,
      description: 'Basic application settings'
    },
    {
      id: 'security',
      label: 'Security',
      icon: Shield,
      description: 'Security and authentication'
    },
    {
      id: 'email',
      label: 'Email',
      icon: Mail,
      description: 'Email configuration'
    },
    {
      id: 'database',
      label: 'Database',
      icon: Database,
      description: 'Database and backup settings'
    },
    {
      id: 'theme',
      label: 'Appearance',
      icon: Palette,
      description: 'Theme and customization'
    },
    {
      id: 'api',
      label: 'API & Integrations',
      icon: Key,
      description: 'External services configuration'
    },
    {
      id: 'notifications',
      label: 'Notifications',
      icon: Bell,
      description: 'Alert and notification settings'
    },
    {
      id: 'content',
      label: 'Content Management',
      icon: FileText,
      description: 'Content policies and settings'
    },
    {
      id: 'monitoring',
      label: 'Monitoring',
      icon: Activity,
      description: 'System monitoring and logging'
    },
    {
      id: 'legal',
      label: 'Legal & Compliance',
      icon: Shield,
      description: 'Privacy and legal settings'
    },
    {
      id: 'regional',
      label: 'Regional',
      icon: Globe,
      description: 'Localization and regional settings'
    }
  ]

  const handleSave = async (tab: string) => {
    setLoading(true)
    setMessage(null)

    try {
      // Here you would save to your backend/database
      await new Promise(resolve => setTimeout(resolve, 1000)) // Simulate API call

      setMessage({ type: 'success', text: 'Settings saved successfully!' })
    } catch (error) {
      setMessage({ type: 'error', text: 'Failed to save settings. Please try again.' })
    } finally {
      setLoading(false)
    }
  }

  const handleBackup = async () => {
    setLoading(true)
    try {
      // Here you would trigger a backup
      await new Promise(resolve => setTimeout(resolve, 2000))
      setMessage({ type: 'success', text: 'Backup initiated successfully!' })
    } catch (error) {
      setMessage({ type: 'error', text: 'Failed to initiate backup.' })
    } finally {
      setLoading(false)
    }
  }

  const renderGeneralSettings = () => (
    <div className="space-y-6">
      <div className="card rounded-2xl p-6 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">Site Information</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Site Name
            </label>
            <input
              type="text"
              value={generalSettings.siteName}
              onChange={(e) => setGeneralSettings({ ...generalSettings, siteName: e.target.value })}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Admin Email
            </label>
            <input
              type="email"
              value={generalSettings.adminEmail}
              onChange={(e) => setGeneralSettings({ ...generalSettings, adminEmail: e.target.value })}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
          <div className="md:col-span-2">
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Site Description
            </label>
            <textarea
              value={generalSettings.siteDescription}
              onChange={(e) => setGeneralSettings({ ...generalSettings, siteDescription: e.target.value })}
              rows={3}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
        </div>
      </div>

      <div className="card rounded-2xl p-6 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">File Upload Settings</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Maximum File Size (MB)
            </label>
            <input
              type="number"
              value={generalSettings.maxFileSize}
              onChange={(e) => setGeneralSettings({ ...generalSettings, maxFileSize: parseInt(e.target.value) })}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Allowed File Types
            </label>
            <select
              multiple
              value={generalSettings.allowedFileTypes}
              onChange={(e) => setGeneralSettings({
                ...generalSettings,
                allowedFileTypes: Array.from(e.target.selectedOptions, option => option.value)
              })}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white"
            >
              <option value="pdf">PDF</option>
              <option value="epub">EPUB</option>
              <option value="mobi">MOBI</option>
              <option value="txt">TXT</option>
              <option value="doc">DOC</option>
            </select>
          </div>
        </div>
      </div>

      <div className="card rounded-2xl p-6 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">System Settings</h3>
        <div className="space-y-4">
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={generalSettings.maintenanceMode}
              onChange={(e) => setGeneralSettings({ ...generalSettings, maintenanceMode: e.target.checked })}
              className="w-4 h-4 rounded bg-gray-200 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-gray-900 dark:text-white">Maintenance Mode</span>
              <p className="text-xs text-gray-600 dark:text-gray-400">Temporarily disable public access to the site</p>
            </div>
          </label>
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={generalSettings.enableRegistration}
              onChange={(e) => setGeneralSettings({ ...generalSettings, enableRegistration: e.target.checked })}
              className="w-4 h-4 rounded bg-gray-200 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-gray-900 dark:text-white">Enable User Registration</span>
              <p className="text-xs text-gray-600 dark:text-gray-400">Allow new users to register accounts</p>
            </div>
          </label>
        </div>
      </div>
    </div>
  )

  const renderSecuritySettings = () => (
    <div className="space-y-6">
      <div className="card rounded-2xl p-6 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">Authentication Settings</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Session Timeout (hours)
            </label>
            <input
              type="number"
              value={securitySettings.sessionTimeout}
              onChange={(e) => setSecuritySettings({ ...securitySettings, sessionTimeout: parseInt(e.target.value) })}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Maximum Login Attempts
            </label>
            <input
              type="number"
              value={securitySettings.maxLoginAttempts}
              onChange={(e) => setSecuritySettings({ ...securitySettings, maxLoginAttempts: parseInt(e.target.value) })}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Lockout Duration (minutes)
            </label>
            <input
              type="number"
              value={securitySettings.lockoutDuration}
              onChange={(e) => setSecuritySettings({ ...securitySettings, lockoutDuration: parseInt(e.target.value) })}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Minimum Password Length
            </label>
            <input
              type="number"
              value={securitySettings.passwordMinLength}
              onChange={(e) => setSecuritySettings({ ...securitySettings, passwordMinLength: parseInt(e.target.value) })}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
        </div>
      </div>

      <div className="card rounded-2xl p-6 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">Security Options</h3>
        <div className="space-y-4">
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={securitySettings.requireEmailVerification}
              onChange={(e) => setSecuritySettings({ ...securitySettings, requireEmailVerification: e.target.checked })}
              className="w-4 h-4 rounded bg-gray-100 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-gray-900 dark:text-white">Require Email Verification</span>
              <p className="text-xs text-gray-600 dark:text-gray-400">Users must verify their email address before accessing the system</p>
            </div>
          </label>
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={securitySettings.enableTwoFactor}
              onChange={(e) => setSecuritySettings({ ...securitySettings, enableTwoFactor: e.target.checked })}
              className="w-4 h-4 rounded bg-gray-100 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-gray-900 dark:text-white">Enable Two-Factor Authentication</span>
              <p className="text-xs text-gray-600 dark:text-gray-400">Require 2FA for admin accounts (coming soon)</p>
            </div>
          </label>
        </div>
      </div>
    </div>
  )

  const renderEmailSettings = () => (
    <div className="space-y-6">
      <div className="card rounded-2xl p-6 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">SMTP Configuration</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              SMTP Host
            </label>
            <input
              type="text"
              value={emailSettings.smtpHost}
              onChange={(e) => setEmailSettings({ ...emailSettings, smtpHost: e.target.value })}
              placeholder="smtp.gmail.com"
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              SMTP Port
            </label>
            <input
              type="number"
              value={emailSettings.smtpPort}
              onChange={(e) => setEmailSettings({ ...emailSettings, smtpPort: parseInt(e.target.value) })}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              SMTP Username
            </label>
            <input
              type="text"
              value={emailSettings.smtpUser}
              onChange={(e) => setEmailSettings({ ...emailSettings, smtpUser: e.target.value })}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              SMTP Password
            </label>
            <input
              type="password"
              value={emailSettings.smtpPassword}
              onChange={(e) => setEmailSettings({ ...emailSettings, smtpPassword: e.target.value })}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              From Email
            </label>
            <input
              type="email"
              value={emailSettings.fromEmail}
              onChange={(e) => setEmailSettings({ ...emailSettings, fromEmail: e.target.value })}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              From Name
            </label>
            <input
              type="text"
              value={emailSettings.fromName}
              onChange={(e) => setEmailSettings({ ...emailSettings, fromName: e.target.value })}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
        </div>
      </div>

      <div className="card rounded-2xl p-6 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">Email Options</h3>
        <div className="space-y-4">
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={emailSettings.enableEmailNotifications}
              onChange={(e) => setEmailSettings({ ...emailSettings, enableEmailNotifications: e.target.checked })}
              className="w-4 h-4 rounded bg-gray-100 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-gray-900 dark:text-white">Enable Email Notifications</span>
              <p className="text-xs text-gray-600 dark:text-gray-400">Send email notifications for important events</p>
            </div>
          </label>
        </div>
      </div>

      <div className="card rounded-2xl p-6 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">Test Email</h3>
        <div className="flex gap-3">
          <input
            type="email"
            placeholder="Enter test email address"
            className="flex-1 px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
          />
          <button className="px-4 py-2 rounded-xl bg-gradient-to-r from-blue-600 to-indigo-600 text-white font-medium hover:from-blue-700 hover:to-indigo-700 transition-all shadow-lg">
            Send Test Email
          </button>
        </div>
      </div>
    </div>
  )

  const renderDatabaseSettings = () => (
    <div className="space-y-6">
      <div className="card rounded-2xl p-6 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">Backup Settings</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Backup Frequency
            </label>
            <select
              value={databaseSettings.backupFrequency}
              onChange={(e) => setDatabaseSettings({ ...databaseSettings, backupFrequency: e.target.value })}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white"
            >
              <option value="hourly">Hourly</option>
              <option value="daily">Daily</option>
              <option value="weekly">Weekly</option>
              <option value="monthly">Monthly</option>
            </select>
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Retention Period (days)
            </label>
            <input
              type="number"
              value={databaseSettings.retentionDays}
              onChange={(e) => setDatabaseSettings({ ...databaseSettings, retentionDays: parseInt(e.target.value) })}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
        </div>
        <div className="mt-4 space-y-4">
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={databaseSettings.autoBackup}
              onChange={(e) => setDatabaseSettings({ ...databaseSettings, autoBackup: e.target.checked })}
              className="w-4 h-4 rounded bg-gray-100 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-gray-900 dark:text-white">Automatic Backups</span>
              <p className="text-xs text-gray-600 dark:text-gray-400">Automatically backup database on schedule</p>
            </div>
          </label>
        </div>
      </div>

      <div className="card rounded-2xl p-6 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">Database Operations</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <button
            onClick={handleBackup}
            disabled={loading}
            className="flex items-center justify-center gap-2 px-4 py-3 rounded-xl bg-gradient-to-r from-blue-600 to-indigo-600 text-white font-medium hover:from-blue-700 hover:to-indigo-700 transition-all shadow-lg disabled:opacity-50"
          >
            {loading ? <RotateCw className="w-4 h-4 animate-spin" /> : <Download className="w-4 h-4" />}
            Create Backup
          </button>
          <button className="flex items-center justify-center gap-2 px-4 py-3 rounded-xl bg-gray-100 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-slate-600 transition-colors">
            <Upload className="w-4 h-4" />
            Restore Backup
          </button>
        </div>
      </div>

      <div className="card rounded-2xl p-6 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">Performance Settings</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Max Database Connections
            </label>
            <input
              type="number"
              value={databaseSettings.maxConnections}
              onChange={(e) => setDatabaseSettings({ ...databaseSettings, maxConnections: parseInt(e.target.value) })}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
        </div>
        <div className="mt-4">
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={databaseSettings.enableAnalytics}
              onChange={(e) => setDatabaseSettings({ ...databaseSettings, enableAnalytics: e.target.checked })}
              className="w-4 h-4 rounded bg-gray-100 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-gray-900 dark:text-white">Enable Analytics</span>
              <p className="text-xs text-gray-600 dark:text-gray-400">Collect usage analytics for reporting</p>
            </div>
          </label>
        </div>
      </div>
    </div>
  )

  const renderThemeSettings = () => (
    <div className="space-y-6">
      <div className="card rounded-2xl p-6 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">Theme Preferences</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Default Theme
            </label>
            <select
              value={themeSettings.defaultTheme}
              onChange={(e) => setThemeSettings({ ...themeSettings, defaultTheme: e.target.value })}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white"
            >
              <option value="light">Light</option>
              <option value="dark">Dark</option>
              <option value="system">System Default</option>
            </select>
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Primary Color
            </label>
            <input
              type="color"
              value={themeSettings.primaryColor}
              onChange={(e) => setThemeSettings({ ...themeSettings, primaryColor: e.target.value })}
              className="w-full h-10 rounded-xl border border-gray-300 dark:border-slate-600 cursor-pointer"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Accent Color
            </label>
            <input
              type="color"
              value={themeSettings.accentColor}
              onChange={(e) => setThemeSettings({ ...themeSettings, accentColor: e.target.value })}
              className="w-full h-10 rounded-xl border border-gray-300 dark:border-slate-600 cursor-pointer"
            />
          </div>
        </div>
        <div className="mt-4 space-y-4">
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={themeSettings.compactMode}
              onChange={(e) => setThemeSettings({ ...themeSettings, compactMode: e.target.checked })}
              className="w-4 h-4 rounded bg-gray-100 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-gray-900 dark:text-white">Compact Mode</span>
              <p className="text-xs text-gray-600 dark:text-gray-400">Reduce spacing and padding for more content</p>
            </div>
          </label>
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={themeSettings.enableAnimations}
              onChange={(e) => setThemeSettings({ ...themeSettings, enableAnimations: e.target.checked })}
              className="w-4 h-4 rounded bg-gray-100 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-gray-900 dark:text-white">Enable Animations</span>
              <p className="text-xs text-gray-600 dark:text-gray-400">Animate transitions and interactions</p>
            </div>
          </label>
        </div>
      </div>
    </div>
  )

  const renderApiSettings = () => (
    <div className="space-y-6">
      <div className="card rounded-2xl p-6 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">API Keys</h3>
        <div className="space-y-4">
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Google Analytics Key
            </label>
            <input
              type="password"
              value={apiSettings.googleAnalyticsKey}
              onChange={(e) => setApiSettings({ ...apiSettings, googleAnalyticsKey: e.target.value })}
              placeholder="GA-XXXXXXXXXX-X"
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              YouTube API Key
            </label>
            <input
              type="password"
              value={apiSettings.youtubeApiKey}
              onChange={(e) => setApiSettings({ ...apiSettings, youtubeApiKey: e.target.value })}
              placeholder="AIzaSyXXXXXXXXXXXXXXXXXXXXXXX"
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
        </div>
      </div>

      <div className="card rounded-2xl p-6 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">Service URLs</h3>
        <div className="space-y-4">
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              File Upload URL
            </label>
            <input
              type="url"
              value={apiSettings.fileUploadUrl}
              onChange={(e) => setApiSettings({ ...apiSettings, fileUploadUrl: e.target.value })}
              placeholder="https://api.example.com/upload"
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              CDN URL
            </label>
            <input
              type="url"
              value={apiSettings.cdnUrl}
              onChange={(e) => setApiSettings({ ...apiSettings, cdnUrl: e.target.value })}
              placeholder="https://cdn.example.com"
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
        </div>
      </div>

      <div className="card rounded-2xl p-6 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">API Rate Limiting</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Rate Limit (requests per minute)
            </label>
            <input
              type="number"
              value={apiSettings.apiRateLimit}
              onChange={(e) => setApiSettings({ ...apiSettings, apiRateLimit: parseInt(e.target.value) })}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
        </div>
        <div className="mt-4">
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={apiSettings.enableApiRateLimit}
              onChange={(e) => setApiSettings({ ...apiSettings, enableApiRateLimit: e.target.checked })}
              className="w-4 h-4 rounded bg-gray-100 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-gray-900 dark:text-white">Enable Rate Limiting</span>
              <p className="text-xs text-gray-600 dark:text-gray-400">Limit API requests per minute</p>
            </div>
          </label>
        </div>
      </div>
    </div>
  )

  const renderNotificationSettings = () => (
    <div className="space-y-6">
      <div className="card rounded-2xl p-6 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">Email Alerts</h3>
        <div className="space-y-4">
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={notificationSettings.enablePushNotifications}
              onChange={(e) => setNotificationSettings({ ...notificationSettings, enablePushNotifications: e.target.checked })}
              className="w-4 h-4 rounded bg-gray-100 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-gray-900 dark:text-white">Enable Push Notifications</span>
              <p className="text-xs text-gray-600 dark:text-gray-400">Send push notifications for important events</p>
            </div>
          </label>
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={notificationSettings.adminAlerts}
              onChange={(e) => setNotificationSettings({ ...notificationSettings, adminAlerts: e.target.checked })}
              className="w-4 h-4 rounded bg-gray-100 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-gray-900 dark:text-white">Admin Alerts</span>
              <p className="text-xs text-gray-600 dark:text-gray-400">Critical system notifications to admins</p>
            </div>
          </label>
        </div>
      </div>

      <div className="card rounded-2xl p-6 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">Webhook URLs</h3>
        <div className="space-y-4">
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Slack Webhook
            </label>
            <input
              type="url"
              value={notificationSettings.slackWebhook}
              onChange={(e) => setNotificationSettings({ ...notificationSettings, slackWebhook: e.target.value })}
              placeholder="https://hooks.slack.com/services/..."
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Discord Webhook
            </label>
            <input
              type="url"
              value={notificationSettings.discordWebhook}
              onChange={(e) => setNotificationSettings({ ...notificationSettings, discordWebhook: e.target.value })}
              placeholder="https://discord.com/api/webhooks/..."
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
        </div>
      </div>
    </div>
  )

  const renderContentSettings = () => (
    <div className="space-y-6">
      <div className="card rounded-2xl p-6 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">Content Policies</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Max Content Size (MB)
            </label>
            <input
              type="number"
              value={contentSettings.maxContentSize}
              onChange={(e) => setContentSettings({ ...contentSettings, maxContentSize: parseInt(e.target.value) })}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Content Retention (days)
            </label>
            <input
              type="number"
              value={contentSettings.contentRetentionDays}
              onChange={(e) => setContentSettings({ ...contentSettings, contentRetentionDays: parseInt(e.target.value) })}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
        </div>
        <div className="mt-4 space-y-4">
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={contentSettings.autoApproveContent}
              onChange={(e) => setContentSettings({ ...contentSettings, autoApproveContent: e.target.checked })}
              className="w-4 h-4 rounded bg-gray-100 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-gray-900 dark:text-white">Auto Approve Content</span>
              <p className="text-xs text-gray-600 dark:text-gray-400">Automatically approve uploaded content</p>
            </div>
          </label>
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={contentSettings.enableComments}
              onChange={(e) => setContentSettings({ ...contentSettings, enableComments: e.target.checked })}
              className="w-4 h-4 rounded bg-gray-100 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-gray-900 dark:text-white">Enable Comments</span>
              <p className="text-xs text-gray-600 dark:text-gray-400">Allow users to comment on content</p>
            </div>
          </label>
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={contentSettings.enableContentVersioning}
              onChange={(e) => setContentSettings({ ...contentSettings, enableContentVersioning: e.target.checked })}
              className="w-4 h-4 rounded bg-gray-100 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-gray-900 dark:text-white">Content Versioning</span>
              <p className="text-xs text-gray-600 dark:text-gray-400">Keep version history for content changes</p>
            </div>
          </label>
        </div>
      </div>
    </div>
  )

  const renderMonitoringSettings = () => (
    <div className="space-y-6">
      <div className="card rounded-2xl p-6 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">Logging & Monitoring</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Log Level
            </label>
            <select
              value={monitoringSettings.logLevel}
              onChange={(e) => setMonitoringSettings({ ...monitoringSettings, logLevel: e.target.value })}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white"
            >
              <option value="debug">Debug</option>
              <option value="info">Info</option>
              <option value="warn">Warning</option>
              <option value="error">Error</option>
            </select>
          </div>
        </div>
        <div className="mt-4 space-y-4">
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={monitoringSettings.enableAuditLogs}
              onChange={(e) => setMonitoringSettings({ ...monitoringSettings, enableAuditLogs: e.target.checked })}
              className="w-4 h-4 rounded bg-gray-100 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-gray-900 dark:text-white">Enable Audit Logs</span>
              <p className="text-xs text-gray-600 dark:text-gray-400">Track all admin activities</p>
            </div>
          </label>
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={monitoringSettings.enableErrorTracking}
              onChange={(e) => setMonitoringSettings({ ...monitoringSettings, enableErrorTracking: e.target.checked })}
              className="w-4 h-4 rounded bg-gray-100 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-gray-900 dark:text-white">Error Tracking</span>
              <p className="text-xs text-gray-600 dark:text-gray-400">Monitor and log system errors</p>
            </div>
          </label>
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={monitoringSettings.performanceMonitoring}
              onChange={(e) => setMonitoringSettings({ ...monitoringSettings, performanceMonitoring: e.target.checked })}
              className="w-4 h-4 rounded bg-gray-100 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-gray-900 dark:text-white">Performance Monitoring</span>
              <p className="text-xs text-gray-600 dark:text-gray-400">Track application performance metrics</p>
            </div>
          </label>
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={monitoringSettings.uptimeMonitoring}
              onChange={(e) => setMonitoringSettings({ ...monitoringSettings, uptimeMonitoring: e.target.checked })}
              className="w-4 h-4 rounded bg-gray-100 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-gray-900 dark:text-white">Uptime Monitoring</span>
              <p className="text-xs text-gray-600 dark:text-gray-400">Monitor service availability</p>
            </div>
          </label>
        </div>
      </div>
    </div>
  )

  const renderLegalSettings = () => (
    <div className="space-y-6">
      <div className="card rounded-2xl p-6 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">Legal Documents</h3>
        <div className="space-y-4">
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Privacy Policy URL
            </label>
            <input
              type="url"
              value={legalSettings.privacyPolicyUrl}
              onChange={(e) => setLegalSettings({ ...legalSettings, privacyPolicyUrl: e.target.value })}
              placeholder="https://yoursite.com/privacy"
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Terms of Service URL
            </label>
            <input
              type="url"
              value={legalSettings.termsOfServiceUrl}
              onChange={(e) => setLegalSettings({ ...legalSettings, termsOfServiceUrl: e.target.value })}
              placeholder="https://yoursite.com/terms"
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Cookie Policy URL
            </label>
            <input
              type="url"
              value={legalSettings.cookiePolicy}
              onChange={(e) => setLegalSettings({ ...legalSettings, cookiePolicy: e.target.value })}
              placeholder="https://yoursite.com/cookies"
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
        </div>
      </div>

      <div className="card rounded-2xl p-6 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">Compliance Settings</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Data Retention Policy (days)
            </label>
            <input
              type="number"
              value={legalSettings.dataRetentionPolicy}
              onChange={(e) => setLegalSettings({ ...legalSettings, dataRetentionPolicy: parseInt(e.target.value) })}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white placeholder:text-gray-500 dark:placeholder:text-gray-400"
            />
          </div>
        </div>
        <div className="mt-4 space-y-4">
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={legalSettings.gdprCompliance}
              onChange={(e) => setLegalSettings({ ...legalSettings, gdprCompliance: e.target.checked })}
              className="w-4 h-4 rounded bg-gray-100 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-gray-900 dark:text-white">GDPR Compliance</span>
              <p className="text-xs text-gray-600 dark:text-gray-400">Comply with GDPR data protection regulations</p>
            </div>
          </label>
        </div>
      </div>
    </div>
  )

  const renderRegionalSettings = () => (
    <div className="space-y-6">
      <div className="card rounded-2xl p-6 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-600 shadow-sm">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">Regional Preferences</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Default Language
            </label>
            <select
              value={regionalSettings.defaultLanguage}
              onChange={(e) => setRegionalSettings({ ...regionalSettings, defaultLanguage: e.target.value })}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white"
            >
              <option value="en">English</option>
              <option value="ms">Bahasa Melayu</option>
              <option value="id">Bahasa Indonesia</option>
              <option value="ar">العربية</option>
            </select>
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Timezone
            </label>
            <select
              value={regionalSettings.timezone}
              onChange={(e) => setRegionalSettings({ ...regionalSettings, timezone: e.target.value })}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white"
            >
              <option value="UTC">UTC</option>
              <option value="Asia/Kuala_Lumpur">Kuala Lumpur</option>
              <option value="Asia/Jakarta">Jakarta</option>
              <option value="Asia/Riyadh">Riyadh</option>
            </select>
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Date Format
            </label>
            <select
              value={regionalSettings.dateFormat}
              onChange={(e) => setRegionalSettings({ ...regionalSettings, dateFormat: e.target.value })}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white"
            >
              <option value="MM/DD/YYYY">MM/DD/YYYY</option>
              <option value="DD/MM/YYYY">DD/MM/YYYY</option>
              <option value="YYYY-MM-DD">YYYY-MM-DD</option>
            </select>
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">
              Currency
            </label>
            <select
              value={regionalSettings.currency}
              onChange={(e) => setRegionalSettings({ ...regionalSettings, currency: e.target.value })}
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 focus:border-blue-500 focus:outline-none text-sm text-gray-900 dark:text-white"
            >
              <option value="USD">USD ($)</option>
              <option value="MYR">MYR (RM)</option>
              <option value="IDR">IDR (Rp)</option>
              <option value="SAR">SAR (﷼)</option>
            </select>
          </div>
        </div>
      </div>
    </div>
  )

  const renderTabContent = () => {
    switch (activeTab) {
      case 'general':
        return renderGeneralSettings()
      case 'security':
        return renderSecuritySettings()
      case 'email':
        return renderEmailSettings()
      case 'database':
        return renderDatabaseSettings()
      case 'theme':
        return renderThemeSettings()
      case 'api':
        return renderApiSettings()
      case 'notifications':
        return renderNotificationSettings()
      case 'content':
        return renderContentSettings()
      case 'monitoring':
        return renderMonitoringSettings()
      case 'legal':
        return renderLegalSettings()
      case 'regional':
        return renderRegionalSettings()
      default:
        return renderGeneralSettings()
    }
  }

  return (
    <DashboardLayout title="Settings" subtitle="Manage system configuration and preferences">
      <div className="space-y-6">

      {/* Message */}
      {message && (
        <div className={`flex items-center gap-3 p-4 rounded-lg ${
          message.type === 'success'
            ? 'bg-emerald-500/10 border border-emerald-500/40 text-emerald-300'
            : 'bg-rose-500/10 border border-rose-500/40 text-rose-300'
        }`}>
          {message.type === 'success' ? <CheckCircle className="w-4 h-4" /> : <XCircle className="w-4 h-4" />}
          <span className="text-sm">{message.text}</span>
        </div>
      )}

      {/* Settings LayoutIcon */}
      <div className="flex flex-col lg:flex-row gap-6">
        {/* Sidebar */}
        <div className="lg:w-64">
          <nav className="space-y-1">
            {tabs.map((tab) => {
              const Icon = tab.icon
              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl text-left transition-colors ${
                    activeTab === tab.id
                      ? 'bg-blue-600/20 border border-blue-500/40 text-blue-600 dark:text-blue-300'
                      : 'text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-slate-700/50 hover:text-gray-900 dark:hover:text-white'
                  }`}
                >
                  <Icon className="w-4 h-4" />
                  <div>
                    <div className="font-medium">{tab.label}</div>
                    <div className="text-xs text-gray-500 dark:text-gray-400">{tab.description}</div>
                  </div>
                </button>
              )
            })}
          </nav>
        </div>

        {/* Content */}
        <div className="flex-1">
          {renderTabContent()}

          {/* Save Button */}
          <div className="flex justify-end gap-3 mt-6">
            <button className="px-6 py-2 rounded-xl bg-gray-100 dark:bg-slate-700 border border-gray-300 dark:border-slate-600 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-slate-600 transition-colors">
              Cancel
            </button>
            <button
              onClick={() => handleSave(activeTab)}
              disabled={loading}
              className="flex items-center gap-2 px-6 py-2 rounded-xl bg-gradient-to-r from-blue-600 to-indigo-600 text-white font-medium hover:from-blue-700 hover:to-indigo-700 transition-all shadow-lg disabled:opacity-50"
            >
              {loading ? <RotateCw className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
              Save Changes
            </button>
          </div>
        </div>
      </div>
      </div>
    </DashboardLayout>
  )
}
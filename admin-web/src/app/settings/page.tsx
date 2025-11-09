'use client'

import { useState } from 'react'
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
  RefreshCw,
  Download,
  Upload,
  Trash2,
  Eye,
  EyeOff,
  Info,
  CheckCircle,
  XCircle
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
      <div className="card p-6">
        <h3 className="text-lg font-semibold text-white mb-4">Site Information</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-2">
              Site Name
            </label>
            <input
              type="text"
              value={generalSettings.siteName}
              onChange={(e) => setGeneralSettings({ ...generalSettings, siteName: e.target.value })}
              className="w-full px-3 py-2 bg-slate-800 border border-slate-600 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-2">
              Admin Email
            </label>
            <input
              type="email"
              value={generalSettings.adminEmail}
              onChange={(e) => setGeneralSettings({ ...generalSettings, adminEmail: e.target.value })}
              className="w-full px-3 py-2 bg-slate-800 border border-slate-600 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50"
            />
          </div>
          <div className="md:col-span-2">
            <label className="block text-sm font-medium text-slate-300 mb-2">
              Site Description
            </label>
            <textarea
              value={generalSettings.siteDescription}
              onChange={(e) => setGeneralSettings({ ...generalSettings, siteDescription: e.target.value })}
              rows={3}
              className="w-full px-3 py-2 bg-slate-800 border border-slate-600 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50"
            />
          </div>
        </div>
      </div>

      <div className="card p-6">
        <h3 className="text-lg font-semibold text-white mb-4">File Upload Settings</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-2">
              Maximum File Size (MB)
            </label>
            <input
              type="number"
              value={generalSettings.maxFileSize}
              onChange={(e) => setGeneralSettings({ ...generalSettings, maxFileSize: parseInt(e.target.value) })}
              className="w-full px-3 py-2 bg-slate-800 border border-slate-600 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-2">
              Allowed File Types
            </label>
            <select
              multiple
              value={generalSettings.allowedFileTypes}
              onChange={(e) => setGeneralSettings({
                ...generalSettings,
                allowedFileTypes: Array.from(e.target.selectedOptions, option => option.value)
              })}
              className="w-full px-3 py-2 bg-slate-800 border border-slate-600 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50"
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

      <div className="card p-6">
        <h3 className="text-lg font-semibold text-white mb-4">System Settings</h3>
        <div className="space-y-4">
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={generalSettings.maintenanceMode}
              onChange={(e) => setGeneralSettings({ ...generalSettings, maintenanceMode: e.target.checked })}
              className="w-4 h-4 rounded bg-slate-700 border border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-white">Maintenance Mode</span>
              <p className="text-xs text-slate-400">Temporarily disable public access to the site</p>
            </div>
          </label>
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={generalSettings.enableRegistration}
              onChange={(e) => setGeneralSettings({ ...generalSettings, enableRegistration: e.target.checked })}
              className="w-4 h-4 rounded bg-slate-700 border border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-white">Enable User Registration</span>
              <p className="text-xs text-slate-400">Allow new users to register accounts</p>
            </div>
          </label>
        </div>
      </div>
    </div>
  )

  const renderSecuritySettings = () => (
    <div className="space-y-6">
      <div className="card p-6">
        <h3 className="text-lg font-semibold text-white mb-4">Authentication Settings</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-2">
              Session Timeout (hours)
            </label>
            <input
              type="number"
              value={securitySettings.sessionTimeout}
              onChange={(e) => setSecuritySettings({ ...securitySettings, sessionTimeout: parseInt(e.target.value) })}
              className="w-full px-3 py-2 bg-slate-800 border border-slate-600 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-2">
              Maximum Login Attempts
            </label>
            <input
              type="number"
              value={securitySettings.maxLoginAttempts}
              onChange={(e) => setSecuritySettings({ ...securitySettings, maxLoginAttempts: parseInt(e.target.value) })}
              className="w-full px-3 py-2 bg-slate-800 border border-slate-600 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-2">
              Lockout Duration (minutes)
            </label>
            <input
              type="number"
              value={securitySettings.lockoutDuration}
              onChange={(e) => setSecuritySettings({ ...securitySettings, lockoutDuration: parseInt(e.target.value) })}
              className="w-full px-3 py-2 bg-slate-800 border border-slate-600 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-2">
              Minimum Password Length
            </label>
            <input
              type="number"
              value={securitySettings.passwordMinLength}
              onChange={(e) => setSecuritySettings({ ...securitySettings, passwordMinLength: parseInt(e.target.value) })}
              className="w-full px-3 py-2 bg-slate-800 border border-slate-600 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50"
            />
          </div>
        </div>
      </div>

      <div className="card p-6">
        <h3 className="text-lg font-semibold text-white mb-4">Security Options</h3>
        <div className="space-y-4">
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={securitySettings.requireEmailVerification}
              onChange={(e) => setSecuritySettings({ ...securitySettings, requireEmailVerification: e.target.checked })}
              className="w-4 h-4 rounded bg-slate-700 border border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-white">Require Email Verification</span>
              <p className="text-xs text-slate-400">Users must verify their email address before accessing the system</p>
            </div>
          </label>
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={securitySettings.enableTwoFactor}
              onChange={(e) => setSecuritySettings({ ...securitySettings, enableTwoFactor: e.target.checked })}
              className="w-4 h-4 rounded bg-slate-700 border border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-white">Enable Two-Factor Authentication</span>
              <p className="text-xs text-slate-400">Require 2FA for admin accounts (coming soon)</p>
            </div>
          </label>
        </div>
      </div>
    </div>
  )

  const renderEmailSettings = () => (
    <div className="space-y-6">
      <div className="card p-6">
        <h3 className="text-lg font-semibold text-white mb-4">SMTP Configuration</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-2">
              SMTP Host
            </label>
            <input
              type="text"
              value={emailSettings.smtpHost}
              onChange={(e) => setEmailSettings({ ...emailSettings, smtpHost: e.target.value })}
              placeholder="smtp.gmail.com"
              className="w-full px-3 py-2 bg-slate-800 border border-slate-600 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-2">
              SMTP Port
            </label>
            <input
              type="number"
              value={emailSettings.smtpPort}
              onChange={(e) => setEmailSettings({ ...emailSettings, smtpPort: parseInt(e.target.value) })}
              className="w-full px-3 py-2 bg-slate-800 border border-slate-600 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-2">
              SMTP Username
            </label>
            <input
              type="text"
              value={emailSettings.smtpUser}
              onChange={(e) => setEmailSettings({ ...emailSettings, smtpUser: e.target.value })}
              className="w-full px-3 py-2 bg-slate-800 border border-slate-600 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-2">
              SMTP Password
            </label>
            <input
              type="password"
              value={emailSettings.smtpPassword}
              onChange={(e) => setEmailSettings({ ...emailSettings, smtpPassword: e.target.value })}
              className="w-full px-3 py-2 bg-slate-800 border border-slate-600 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-2">
              From Email
            </label>
            <input
              type="email"
              value={emailSettings.fromEmail}
              onChange={(e) => setEmailSettings({ ...emailSettings, fromEmail: e.target.value })}
              className="w-full px-3 py-2 bg-slate-800 border border-slate-600 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-2">
              From Name
            </label>
            <input
              type="text"
              value={emailSettings.fromName}
              onChange={(e) => setEmailSettings({ ...emailSettings, fromName: e.target.value })}
              className="w-full px-3 py-2 bg-slate-800 border border-slate-600 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50"
            />
          </div>
        </div>
      </div>

      <div className="card p-6">
        <h3 className="text-lg font-semibold text-white mb-4">Email Options</h3>
        <div className="space-y-4">
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={emailSettings.enableEmailNotifications}
              onChange={(e) => setEmailSettings({ ...emailSettings, enableEmailNotifications: e.target.checked })}
              className="w-4 h-4 rounded bg-slate-700 border border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-white">Enable Email Notifications</span>
              <p className="text-xs text-slate-400">Send email notifications for important events</p>
            </div>
          </label>
        </div>
      </div>

      <div className="card p-6">
        <h3 className="text-lg font-semibold text-white mb-4">Test Email</h3>
        <div className="flex gap-3">
          <input
            type="email"
            placeholder="Enter test email address"
            className="flex-1 px-3 py-2 bg-slate-800 border border-slate-600 rounded-lg text-white placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50"
          />
          <button className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
            Send Test Email
          </button>
        </div>
      </div>
    </div>
  )

  const renderDatabaseSettings = () => (
    <div className="space-y-6">
      <div className="card p-6">
        <h3 className="text-lg font-semibold text-white mb-4">Backup Settings</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-2">
              Backup Frequency
            </label>
            <select
              value={databaseSettings.backupFrequency}
              onChange={(e) => setDatabaseSettings({ ...databaseSettings, backupFrequency: e.target.value })}
              className="w-full px-3 py-2 bg-slate-800 border border-slate-600 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50"
            >
              <option value="hourly">Hourly</option>
              <option value="daily">Daily</option>
              <option value="weekly">Weekly</option>
              <option value="monthly">Monthly</option>
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-2">
              Retention Period (days)
            </label>
            <input
              type="number"
              value={databaseSettings.retentionDays}
              onChange={(e) => setDatabaseSettings({ ...databaseSettings, retentionDays: parseInt(e.target.value) })}
              className="w-full px-3 py-2 bg-slate-800 border border-slate-600 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50"
            />
          </div>
        </div>
        <div className="mt-4 space-y-4">
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={databaseSettings.autoBackup}
              onChange={(e) => setDatabaseSettings({ ...databaseSettings, autoBackup: e.target.checked })}
              className="w-4 h-4 rounded bg-slate-700 border border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-white">Automatic Backups</span>
              <p className="text-xs text-slate-400">Automatically backup database on schedule</p>
            </div>
          </label>
        </div>
      </div>

      <div className="card p-6">
        <h3 className="text-lg font-semibold text-white mb-4">Database Operations</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <button
            onClick={handleBackup}
            disabled={loading}
            className="flex items-center justify-center gap-2 px-4 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50"
          >
            {loading ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Download className="w-4 h-4" />}
            Create Backup
          </button>
          <button className="flex items-center justify-center gap-2 px-4 py-3 bg-slate-700 text-white rounded-lg hover:bg-slate-600 transition-colors">
            <Upload className="w-4 h-4" />
            Restore Backup
          </button>
        </div>
      </div>

      <div className="card p-6">
        <h3 className="text-lg font-semibold text-white mb-4">Performance Settings</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-2">
              Max Database Connections
            </label>
            <input
              type="number"
              value={databaseSettings.maxConnections}
              onChange={(e) => setDatabaseSettings({ ...databaseSettings, maxConnections: parseInt(e.target.value) })}
              className="w-full px-3 py-2 bg-slate-800 border border-slate-600 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50"
            />
          </div>
        </div>
        <div className="mt-4">
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={databaseSettings.enableAnalytics}
              onChange={(e) => setDatabaseSettings({ ...databaseSettings, enableAnalytics: e.target.checked })}
              className="w-4 h-4 rounded bg-slate-700 border border-slate-600 text-blue-500 focus:ring-2 focus:ring-blue-500/50"
            />
            <div>
              <span className="text-sm font-medium text-white">Enable Analytics</span>
              <p className="text-xs text-slate-400">Collect usage analytics for reporting</p>
            </div>
          </label>
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
      default:
        return renderGeneralSettings()
    }
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-white">Settings</h1>
        <p className="text-slate-400 mt-1">Manage system configuration and preferences</p>
      </div>

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

      {/* Settings Layout */}
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
                  className={`w-full flex items-center gap-3 px-4 py-3 rounded-lg text-left transition-colors ${
                    activeTab === tab.id
                      ? 'bg-blue-600/20 border border-blue-500/40 text-blue-300'
                      : 'text-slate-300 hover:bg-slate-800/50 hover:text-white'
                  }`}
                >
                  <Icon className="w-4 h-4" />
                  <div>
                    <div className="font-medium">{tab.label}</div>
                    <div className="text-xs text-slate-400">{tab.description}</div>
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
            <button className="px-6 py-2 bg-slate-700 text-white rounded-lg hover:bg-slate-600 transition-colors">
              Cancel
            </button>
            <button
              onClick={() => handleSave(activeTab)}
              disabled={loading}
              className="flex items-center gap-2 px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50"
            >
              {loading ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
              Save Changes
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
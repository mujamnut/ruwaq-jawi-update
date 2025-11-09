'use client'

import { useState } from 'react'
import {
  CheckSquare,
  Square,
  Trash2,
  Download,
  Eye,
  EyeOff,
  Archive,
  MoreHorizontal,
  Loader2
} from 'lucide-react'
import { supabase } from '@/lib/supabase'

interface BulkOperationsProps<T> {
  selectedItems: string[]
  items: T[]
  itemType: 'books' | 'videos' | 'categories' | 'users'
  onSelectionChange: (selectedIds: string[]) => void
  onItemsUpdate: () => void
  onLoadingChange?: (loading: boolean) => void
}

interface BulkAction {
  id: string
  label: string
  icon: React.ComponentType<{ className?: string }>
  action: (selectedIds: string[]) => Promise<void>
  requiresConfirmation?: boolean
  confirmationMessage?: string
  variant?: 'danger' | 'primary' | 'secondary'
}

export function BulkOperations<T extends { id: string; is_active?: boolean }>({
  selectedItems,
  items,
  itemType,
  onSelectionChange,
  onItemsUpdate,
  onLoadingChange
}: BulkOperationsProps<T>) {
  const [loading, setLoading] = useState(false)
  const [actionLoading, setActionLoading] = useState<string | null>(null)

  const handleSelectAll = () => {
    if (selectedItems.length === items.length) {
      onSelectionChange([])
    } else {
      onSelectionChange(items.map(item => item.id))
    }
  }

  const executeBulkAction = async (action: BulkAction, actionId: string) => {
    if (selectedItems.length === 0) return

    if (action.requiresConfirmation && action.confirmationMessage) {
      const confirmed = confirm(
        `${action.confirmationMessage}\n\nThis action will affect ${selectedItems.length} item(s).`
      )
      if (!confirmed) return
    }

    try {
      setActionLoading(actionId)
      setLoading(true)
      onLoadingChange?.(true)

      await action.action(selectedItems)

      // Clear selection after successful action
      onSelectionChange([])

      // Refresh data
      onItemsUpdate()
    } catch (error) {
      console.error('Bulk action failed:', error)
      alert('Failed to perform bulk action. Please try again.')
    } finally {
      setActionLoading(null)
      setLoading(false)
      onLoadingChange?.(false)
    }
  }

  const getBulkActions = (): BulkAction[] => {
    const commonActions: BulkAction[] = [
      {
        id: 'export',
        label: 'Export Selected',
        icon: Download,
        action: async (ids: string[]) => {
          // Export functionality will be implemented separately
          console.log('Exporting items:', ids)
          alert('Export functionality will be available soon!')
        },
        variant: 'secondary'
      }
    ]

    switch (itemType) {
      case 'books':
        return [
          ...commonActions,
          {
            id: 'delete',
            label: 'Delete Selected',
            icon: Trash2,
            action: async (ids: string[]) => {
              const { error } = await supabase
                .from('ebooks')
                .delete()
                .in('id', ids)
              if (error) throw error
            },
            requiresConfirmation: true,
            confirmationMessage: 'Are you sure you want to delete the selected books? This action cannot be undone.',
            variant: 'danger'
          },
          {
            id: 'activate',
            label: 'Activate Selected',
            icon: Eye,
            action: async (ids: string[]) => {
              const { error } = await supabase
                .from('ebooks')
                .update({ is_active: true })
                .in('id', ids)
              if (error) throw error
            },
            variant: 'primary'
          },
          {
            id: 'deactivate',
            label: 'Deactivate Selected',
            icon: EyeOff,
            action: async (ids: string[]) => {
              const { error } = await supabase
                .from('ebooks')
                .update({ is_active: false })
                .in('id', ids)
              if (error) throw error
            },
            variant: 'secondary'
          }
        ]

      case 'videos':
        return [
          ...commonActions,
          {
            id: 'delete',
            label: 'Delete Selected',
            icon: Trash2,
            action: async (ids: string[]) => {
              const { error } = await supabase
                .from('video_kitab')
                .delete()
                .in('id', ids)
              if (error) throw error
            },
            requiresConfirmation: true,
            confirmationMessage: 'Are you sure you want to delete the selected videos? This action cannot be undone.',
            variant: 'danger'
          },
          {
            id: 'activate',
            label: 'Activate Selected',
            icon: Eye,
            action: async (ids: string[]) => {
              const { error } = await supabase
                .from('video_kitab')
                .update({ is_active: true })
                .in('id', ids)
              if (error) throw error
            },
            variant: 'primary'
          },
          {
            id: 'deactivate',
            label: 'Deactivate Selected',
            icon: EyeOff,
            action: async (ids: string[]) => {
              const { error } = await supabase
                .from('video_kitab')
                .update({ is_active: false })
                .in('id', ids)
              if (error) throw error
            },
            variant: 'secondary'
          }
        ]

      case 'categories':
        return [
          ...commonActions,
          {
            id: 'delete',
            label: 'Delete Selected',
            icon: Trash2,
            action: async (ids: string[]) => {
              const { error } = await supabase
                .from('categories')
                .delete()
                .in('id', ids)
              if (error) throw error
            },
            requiresConfirmation: true,
            confirmationMessage: 'Are you sure you want to delete the selected categories? This will also affect content in these categories.',
            variant: 'danger'
          },
          {
            id: 'activate',
            label: 'Activate Selected',
            icon: Eye,
            action: async (ids: string[]) => {
              const { error } = await supabase
                .from('categories')
                .update({ is_active: true })
                .in('id', ids)
              if (error) throw error
            },
            variant: 'primary'
          },
          {
            id: 'deactivate',
            label: 'Deactivate Selected',
            icon: EyeOff,
            action: async (ids: string[]) => {
              const { error } = await supabase
                .from('categories')
                .update({ is_active: false })
                .in('id', ids)
              if (error) throw error
            },
            variant: 'secondary'
          }
        ]

      case 'users':
        return [
          ...commonActions,
          {
            id: 'activate',
            label: 'Activate Selected',
            icon: Eye,
            action: async (ids: string[]) => {
              const { error } = await supabase
                .from('profiles')
                .update({ is_active: true })
                .in('id', ids)
              if (error) throw error
            },
            variant: 'primary'
          },
          {
            id: 'deactivate',
            label: 'Deactivate Selected',
            icon: EyeOff,
            action: async (ids: string[]) => {
              const { error } = await supabase
                .from('profiles')
                .update({ is_active: false })
                .in('id', ids)
              if (error) throw error
            },
            variant: 'secondary'
          }
        ]

      default:
        return commonActions
    }
  }

  const actions = getBulkActions()

  if (items.length === 0) return null

  return (
    <>
      {/* Select All Checkbox */}
      <div className="flex items-center gap-3 p-3 rounded-lg bg-slate-900/80 border border-slate-700/80 mb-4">
        <button
          onClick={handleSelectAll}
          className="flex items-center gap-2 text-xs text-slate-300 hover:text-slate-100 transition-colors"
        >
          {selectedItems.length === items.length ? (
            <CheckSquare className="w-4 h-4 text-blue-400" />
          ) : (
            <Square className="w-4 h-4" />
          )}
          {selectedItems.length === items.length ? 'Deselect All' : 'Select All'}
          {selectedItems.length > 0 && selectedItems.length < items.length && (
            <span className="text-slate-500">({selectedItems.length} selected)</span>
          )}
        </button>

        {selectedItems.length > 0 && (
          <div className="flex items-center gap-2 ml-auto">
            <span className="text-xs text-slate-400">
              {selectedItems.length} item{selectedItems.length !== 1 ? 's' : ''} selected
            </span>

            <div className="flex items-center gap-1">
              {actions.map((action) => {
                const Icon = action.icon
                const isLoading = actionLoading === action.id

                return (
                  <button
                    key={action.id}
                    onClick={() => executeBulkAction(action, action.id)}
                    disabled={loading || isLoading}
                    className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${
                      action.variant === 'danger'
                        ? 'bg-rose-600/10 border border-rose-500/40 text-rose-300 hover:bg-rose-600/20'
                        : action.variant === 'primary'
                        ? 'bg-blue-600/10 border border-blue-500/40 text-blue-300 hover:bg-blue-600/20'
                        : 'bg-slate-700/50 border border-slate-600/40 text-slate-300 hover:bg-slate-700/70'
                    } disabled:opacity-50 disabled:cursor-not-allowed`}
                    title={action.label}
                  >
                    {isLoading ? (
                      <Loader2 className="w-3.5 h-3.5 animate-spin" />
                    ) : (
                      <Icon className="w-3.5 h-3.5" />
                    )}
                    <span className="hidden sm:inline">{action.label}</span>
                  </button>
                )
              })}
            </div>
          </div>
        )}
      </div>

      {/* Checkbox Styles */}
      <style jsx>{`
        .bulk-checkbox {
          appearance: none;
          width: 16px;
          height: 16px;
          border: 1px solid #475569;
          border-radius: 4px;
          background: #0f172a;
          cursor: pointer;
          position: relative;
          transition: all 0.2s;
        }

        .bulk-checkbox:checked {
          background: #3b82f6;
          border-color: #3b82f6;
        }

        .bulk-checkbox:checked::after {
          content: '✓';
          position: absolute;
          top: -2px;
          left: 2px;
          color: white;
          font-size: 12px;
          font-weight: bold;
        }

        .bulk-checkbox:hover {
          border-color: #64748b;
        }

        .bulk-checkbox:checked:hover {
          border-color: #60a5fa;
        }

        .bulk-checkbox:disabled {
          opacity: 0.5;
          cursor: not-allowed;
        }
      `}</style>
    </>
  )
}

// Export a checkbox component for individual items
export function BulkCheckbox({
  itemId,
  isSelected,
  onToggle,
  disabled = false
}: {
  itemId: string
  isSelected: boolean
  onToggle: (itemId: string, checked: boolean) => void
  disabled?: boolean
}) {
  return (
    <input
      type="checkbox"
      className="bulk-checkbox"
      checked={isSelected}
      onChange={(e) => onToggle(itemId, e.target.checked)}
      disabled={disabled}
    />
  )
}
'use client'

import { useState, useEffect } from 'react'
import {
  Calendar,
  ChevronLeft,
  ChevronRight,
  X,
  Check,
  Clock,
  TrendingUp,
  Download
} from 'lucide-react'

interface DateRange {
  start: string
  end: string
}

interface DateRangePickerProps {
  value: DateRange
  onChange: (range: DateRange) => void
  onClose?: () => void
  presets?: Array<{
    key: string
    label: string
    range: () => DateRange
  }>
  maxDate?: Date
  minDate?: Date
  isOpen?: boolean
}

const defaultPresets = [
  {
    key: 'today',
    label: 'Today',
    range: () => {
      const today = new Date()
      return {
        start: today.toISOString().split('T')[0],
        end: today.toISOString().split('T')[0]
      }
    }
  },
  {
    key: 'yesterday',
    label: 'Yesterday',
    range: () => {
      const yesterday = new Date()
      yesterday.setDate(yesterday.getDate() - 1)
      return {
        start: yesterday.toISOString().split('T')[0],
        end: yesterday.toISOString().split('T')[0]
      }
    }
  },
  {
    key: '7d',
    label: 'Last 7 Days',
    range: () => {
      const end = new Date()
      const start = new Date()
      start.setDate(start.getDate() - 6)
      return {
        start: start.toISOString().split('T')[0],
        end: end.toISOString().split('T')[0]
      }
    }
  },
  {
    key: '30d',
    label: 'Last 30 Days',
    range: () => {
      const end = new Date()
      const start = new Date()
      start.setDate(start.getDate() - 29)
      return {
        start: start.toISOString().split('T')[0],
        end: end.toISOString().split('T')[0]
      }
    }
  },
  {
    key: '90d',
    label: 'Last 90 Days',
    range: () => {
      const end = new Date()
      const start = new Date()
      start.setDate(start.getDate() - 89)
      return {
        start: start.toISOString().split('T')[0],
        end: end.toISOString().split('T')[0]
      }
    }
  },
  {
    key: '1y',
    label: 'Last Year',
    range: () => {
      const end = new Date()
      const start = new Date()
      start.setFullYear(start.getFullYear() - 1)
      return {
        start: start.toISOString().split('T')[0],
        end: end.toISOString().split('T')[0]
      }
    }
  },
  {
    key: 'mtd',
    label: 'Month to Date',
    range: () => {
      const end = new Date()
      const start = new Date(end.getFullYear(), end.getMonth(), 1)
      return {
        start: start.toISOString().split('T')[0],
        end: end.toISOString().split('T')[0]
      }
    }
  },
  {
    key: 'qtd',
    label: 'Quarter to Date',
    range: () => {
      const end = new Date()
      const start = new Date(end.getFullYear(), Math.floor(end.getMonth() / 3) * 3, 1)
      return {
        start: start.toISOString().split('T')[0],
        end: end.toISOString().split('T')[0]
      }
    }
  },
  {
    key: 'ytd',
    label: 'Year to Date',
    range: () => {
      const end = new Date()
      const start = new Date(end.getFullYear(), 0, 1)
      return {
        start: start.toISOString().split('T')[0],
        end: end.toISOString().split('T')[0]
      }
    }
  }
]

export default function DateRangePicker({
  value,
  onChange,
  onClose,
  presets = defaultPresets,
  maxDate = new Date(),
  minDate = new Date(2020, 0, 1),
  isOpen = true
}: DateRangePickerProps) {
  const [internalValue, setInternalValue] = useState<DateRange>(value)
  const [showCustom, setShowCustom] = useState(false)
  const [currentMonth, setCurrentMonth] = useState(new Date())

  useEffect(() => {
    setInternalValue(value)
  }, [value])

  const handlePresetClick = (preset: typeof defaultPresets[0]) => {
    const range = preset.range()
    setInternalValue(range)
    onChange(range)
    onClose?.()
  }

  const handleCustomSubmit = () => {
    onChange(internalValue)
    onClose?.()
  }

  const getDaysInMonth = (date: Date) => {
    return new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate()
  }

  const getFirstDayOfMonth = (date: Date) => {
    return new Date(date.getFullYear(), date.getMonth(), 1).getDay()
  }

  const renderCalendar = () => {
    const daysInMonth = getDaysInMonth(currentMonth)
    const firstDay = getFirstDayOfMonth(currentMonth)
    const days = []

    // Empty cells for days before month starts
    for (let i = 0; i < firstDay; i++) {
      days.push(<div key={`empty-${i}`} className="p-2" />)
    }

    // Days of the month
    for (let day = 1; day <= daysInMonth; day++) {
      const date = new Date(currentMonth.getFullYear(), currentMonth.getMonth(), day)
      const dateStr = date.toISOString().split('T')[0]
      const isSelected = dateStr >= internalValue.start && dateStr <= internalValue.end
      const isStart = dateStr === internalValue.start
      const isEnd = dateStr === internalValue.end
      const isDisabled = date > maxDate || date < minDate

      days.push(
        <button
          key={day}
          onClick={() => {
            if (isDisabled) return

            if (!internalValue.start || (internalValue.start && internalValue.end)) {
              // Start new selection
              setInternalValue({ start: dateStr, end: '' })
            } else if (dateStr < internalValue.start) {
              // Selecting earlier date
              setInternalValue({ start: dateStr, end: internalValue.start })
            } else {
              // Selecting end date
              setInternalValue({ ...internalValue, end: dateStr })
            }
          }}
          disabled={isDisabled}
          className={`
            p-2 text-sm rounded-lg transition-all
            ${isDisabled ? 'text-gray-400 cursor-not-allowed' : 'text-gray-700 hover:bg-gray-200 cursor-pointer'}
            ${isSelected ? 'bg-blue-500/20 text-blue-300' : ''}
            ${isStart ? 'bg-blue-500 text-white' : ''}
            ${isEnd ? 'bg-blue-500 text-white' : ''}
          `}
        >
          {day}
        </button>
      )
    }

    return days
  }

  const monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ]

  const navigateMonth = (direction: 'prev' | 'next') => {
    const newMonth = new Date(currentMonth)
    if (direction === 'prev') {
      newMonth.setMonth(newMonth.getMonth() - 1)
    } else {
      newMonth.setMonth(newMonth.getMonth() + 1)
    }
    setCurrentMonth(newMonth)
  }

  const formatDisplayDate = (date: DateRange) => {
    if (!date.start) return 'Select date range'

    const start = new Date(date.start)
    const end = date.end ? new Date(date.end) : start

    if (date.start === date.end) {
      return start.toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
        year: 'numeric'
      })
    }

    const sameMonth = start.getMonth() === end.getMonth() && start.getFullYear() === end.getFullYear()
    const sameYear = start.getFullYear() === end.getFullYear()

    if (sameMonth) {
      return `${start.toLocaleDateString('en-US', { month: 'short' })} ${start.getDate()} - ${end.getDate()}, ${start.getFullYear()}`
    } else if (sameYear) {
      return `${start.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })} - ${end.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}, ${start.getFullYear()}`
    } else {
      return `${start.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })} - ${end.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}`
    }
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl border border-gray-300/50 shadow-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-300/50">
          <div className="flex items-center gap-3">
            <Calendar className="w-5 h-5 text-blue-400" />
            <h3 className="text-lg font-semibold text-gray-900">Select Date Range</h3>
          </div>
          <button
            onClick={onClose}
            className="p-2 rounded-lg hover:bg-gray-100/50 transition-colors"
          >
            <X className="w-4 h-4 text-gray-600" />
          </button>
        </div>

        {/* Current Selection Display */}
        <div className="px-6 py-4 bg-gray-100/30 border-b border-gray-300/50">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <Clock className="w-4 h-4 text-gray-600" />
              <span className="text-sm text-gray-700">
                {formatDisplayDate(internalValue)}
              </span>
            </div>
            <button
              onClick={handleCustomSubmit}
              disabled={!internalValue.start}
              className="px-4 py-2 bg-blue-500 text-white text-sm rounded-lg hover:bg-blue-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
            >
              <Check className="w-4 h-4" />
              Apply
            </button>
          </div>
        </div>

        <div className="flex">
          {/* Presets Sidebar */}
          <div className="w-64 p-6 border-r border-gray-300/50">
            <h4 className="text-sm font-medium text-gray-700 mb-4">Quick Presets</h4>
            <div className="space-y-2">
              {presets.map((preset) => {
                const range = preset.range()
                const isActive = internalValue.start === range.start && internalValue.end === range.end

                return (
                  <button
                    key={preset.key}
                    onClick={() => handlePresetClick(preset)}
                    className={`w-full text-left px-3 py-2 rounded-lg text-sm transition-colors ${
                      isActive
                        ? 'bg-blue-500/20 text-blue-300 border border-blue-500/40'
                        : 'text-gray-700 hover:bg-gray-100/50'
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <span>{preset.label}</span>
                      <TrendingUp className="w-3 h-3 opacity-50" />
                    </div>
                  </button>
                )
              })}
            </div>

            <div className="mt-6 pt-6 border-t border-gray-300/50">
              <button
                onClick={() => setShowCustom(!showCustom)}
                className={`w-full text-left px-3 py-2 rounded-lg text-sm transition-colors flex items-center justify-between ${
                  showCustom
                    ? 'bg-blue-500/20 text-blue-300 border border-blue-500/40'
                    : 'text-gray-700 hover:bg-gray-100/50'
                }`}
              >
                <span>Custom Range</span>
                <Calendar className="w-3 h-3 opacity-50" />
              </button>
            </div>
          </div>

          {/* Calendar */}
          <div className="flex-1 p-6">
            {showCustom && (
              <>
                {/* Month Navigation */}
                <div className="flex items-center justify-between mb-6">
                  <button
                    onClick={() => navigateMonth('prev')}
                    className="p-2 rounded-lg hover:bg-gray-100/50 transition-colors"
                  >
                    <ChevronLeft className="w-4 h-4 text-gray-600" />
                  </button>
                  <h4 className="text-lg font-medium text-gray-900">
                    {monthNames[currentMonth.getMonth()]} {currentMonth.getFullYear()}
                  </h4>
                  <button
                    onClick={() => navigateMonth('next')}
                    className="p-2 rounded-lg hover:bg-gray-100/50 transition-colors"
                  >
                    <ChevronRight className="w-4 h-4 text-gray-600" />
                  </button>
                </div>

                {/* Week Days */}
                <div className="grid grid-cols-7 gap-1 mb-2">
                  {['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((day) => (
                    <div key={day} className="text-center text-xs font-medium text-gray-600 p-2">
                      {day}
                    </div>
                  ))}
                </div>

                {/* Calendar GridIcon */}
                <div className="grid grid-cols-7 gap-1">
                  {renderCalendar()}
                </div>
              </>
            )}

            {!showCustom && (
              <div className="flex items-center justify-center h-64">
                <div className="text-center">
                  <Calendar className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                  <p className="text-gray-600 mb-2">Select a preset or choose custom range</p>
                  <button
                    onClick={() => setShowCustom(true)}
                    className="text-sm text-blue-400 hover:text-blue-300"
                  >
                    Open Calendar
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Footer Actions */}
        <div className="p-6 border-t border-gray-300/50">
          <div className="flex items-center justify-between">
            <div className="text-xs text-gray-600">
              Selected: {internalValue.start ? formatDisplayDate(internalValue) : 'No selection'}
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={() => {
                  setInternalValue({ start: '', end: '' })
                  onChange({ start: '', end: '' })
                }}
                className="px-4 py-2 text-sm text-gray-700 hover:bg-gray-100/50 rounded-lg transition-colors"
              >
                Clear
              </button>
              <button
                onClick={handleCustomSubmit}
                disabled={!internalValue.start}
                className="px-4 py-2 bg-blue-500 text-white text-sm rounded-lg hover:bg-blue-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
              >
                <Check className="w-4 h-4" />
                Apply Range
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

// Export preset ranges for use elsewhere
export { defaultPresets }
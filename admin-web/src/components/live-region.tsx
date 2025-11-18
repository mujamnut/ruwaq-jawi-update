'use client'

import { useEffect, useRef, useState } from 'react'

interface LiveRegionProps {
  message?: string
  politeness?: 'polite' | 'assertive'
  className?: string
}

export function LiveRegion({ message, politeness = 'polite', className = '' }: LiveRegionProps) {
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (ref.current && message) {
      ref.current.textContent = message
    }
  }, [message])

  return (
    <div
      ref={ref}
      aria-live={politeness}
      aria-atomic="true"
      className={`sr-only ${className}`}
    />
  )
}

// Hook untuk mengakses live region
export function useLiveRegion() {
  const [messages, setMessages] = useState<Record<string, string>>({})

  const announce = (id: string, message: string, politeness: 'polite' | 'assertive' = 'polite') => {
    setMessages(prev => ({
      ...prev,
      [id]: message
    }))
  }

  const clear = (id: string) => {
    setMessages(prev => {
      const newMessages = { ...prev }
      delete newMessages[id]
      return newMessages
    })
  }

  return { announce, clear, messages }
}
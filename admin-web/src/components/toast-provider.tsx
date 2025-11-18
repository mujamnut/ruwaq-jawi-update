'use client'

import { Toaster } from 'sonner'

export function ToastProvider() {
  return (
    <Toaster
      position="top-right"
      expand={false}
      richColors
      closeButton
      style={{
        '--toast-bg': 'hsl(0 0% 100%)',
        '--toast-text': 'hsl(222.2 84% 4.9%)',
        '--toast-border': 'hsl(214.3 31.8% 91.4%)',
      } as React.CSSProperties}
    />
  )
}
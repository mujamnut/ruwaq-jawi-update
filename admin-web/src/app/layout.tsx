import './globals.css'
import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import { AuthProvider } from '@/contexts/auth-context'
import { ThemeProvider } from '@/contexts/theme-context'
import { ToastProvider } from '@/components/toast-provider'
import QueryProvider from '@/components/query-provider'
import { ErrorBoundary } from '@/components/error-boundary'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'Maktabah Ruwaq Jawi - Admin',
  description: 'Admin dashboard for Maktabah Ruwaq Jawi mobile app',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={`${inter.className} bg-white dark:bg-slate-900 text-gray-900 dark:text-white transition-colors duration-300`}>
        <ThemeProvider>
          <QueryProvider>
            <ErrorBoundary>
              <AuthProvider>
                <a
                  href="#main-content"
                  className="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 bg-blue-600 text-white px-4 py-2 rounded-lg z-50"
                >
                  Skip to main content
                </a>
                {children}
                <ToastProvider />
              </AuthProvider>
            </ErrorBoundary>
          </QueryProvider>
        </ThemeProvider>
      </body>
    </html>
  )
}

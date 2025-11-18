'use client'

import { useState, useEffect } from 'react'

export function useScreenWidth() {
  const [screenWidth, setScreenWidth] = useState(0)

  useEffect(() => {
    // Set initial width
    setScreenWidth(window.innerWidth)

    // Add resize listener
    const handleResize = () => {
      setScreenWidth(window.innerWidth)
    }

    window.addEventListener('resize', handleResize)

    // Cleanup
    return () => {
      window.removeEventListener('resize', handleResize)
    }
  }, [])

  return screenWidth
}
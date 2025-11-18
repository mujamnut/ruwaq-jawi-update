import { useState, useCallback } from 'react'
import { z } from 'zod'

export interface UseFormOptions<T> {
  initialValues: T
  validationSchema?: z.ZodSchema<T>
  onSubmit: (values: T) => Promise<void> | void
  onSuccess?: () => void
  onError?: (error: Error) => void
}

export interface UseFormReturn<T> {
  values: T
  errors: Partial<Record<keyof T, string>>
  touched: Partial<Record<keyof T, boolean>>
  isSubmitting: boolean
  isValid: boolean
  handleChange: (field: keyof T, value: any) => void
  handleBlur: (field: keyof T) => void
  handleSubmit: (e?: React.FormEvent) => void
  resetForm: () => void
  setFieldValue: (field: keyof T, value: any) => void
  setError: (field: keyof T, error: string) => void
  clearError: (field: keyof T) => void
}

export function useForm<T extends Record<string, any>>(options: UseFormOptions<T>): UseFormReturn<T> {
  const [values, setValues] = useState<T>(options.initialValues)
  const [errors, setErrors] = useState<Partial<Record<keyof T, string>>>({})
  const [touched, setTouched] = useState<Partial<Record<keyof T, boolean>>>({})
  const [isSubmitting, setIsSubmitting] = useState(false)

  const validateField = useCallback((field: keyof T, value: any): string | null => {
    if (!options.validationSchema) return null

    try {
      options.validationSchema.parse({ ...values, [field]: value })
      return null
    } catch (error) {
      if (error instanceof z.ZodError) {
        const fieldError = error.issues.find(err => err.path.includes(field as string))
        return fieldError?.message || null
      }
      return 'Validation error'
    }
  }, [options.validationSchema, values])

  const validateForm = useCallback((): boolean => {
    if (!options.validationSchema) return true

    try {
      options.validationSchema.parse(values)
      setErrors({})
      return true
    } catch (error) {
      if (error instanceof z.ZodError) {
        const newErrors: Partial<Record<keyof T, string>> = {}
        error.issues.forEach((err: any) => {
          const field = err.path[0] as keyof T
          newErrors[field] = err.message
        })
        setErrors(newErrors)
      }
      return false
    }
  }, [options.validationSchema, values])

  const handleChange = useCallback((field: keyof T, value: any) => {
    setValues(prev => ({ ...prev, [field]: value }))

    if (touched[field]) {
      const error = validateField(field, value)
      setErrors(prev => ({ ...prev, [field]: error || undefined }))
    }
  }, [touched, validateField])

  const handleBlur = useCallback((field: keyof T) => {
    setTouched(prev => ({ ...prev, [field]: true }))
    const error = validateField(field, values[field])
    setErrors(prev => ({ ...prev, [field]: error || undefined }))
  }, [validateField, values])

  const handleSubmit = useCallback(async (e?: React.FormEvent) => {
    e?.preventDefault()

    // Mark all fields as touched
    const allTouched = Object.keys(values).reduce((acc, key) => {
      acc[key as keyof T] = true
      return acc
    }, {} as Partial<Record<keyof T, boolean>>)
    setTouched(allTouched)

    // Validate form
    if (!validateForm()) return

    setIsSubmitting(true)
    try {
      await options.onSubmit(values)
      options.onSuccess?.()
    } catch (error) {
      options.onError?.(error instanceof Error ? error : new Error('Unknown error'))
    } finally {
      setIsSubmitting(false)
    }
  }, [values, validateForm, options])

  const resetForm = useCallback(() => {
    setValues(options.initialValues)
    setErrors({})
    setTouched({})
    setIsSubmitting(false)
  }, [options.initialValues])

  const setFieldValue = useCallback((field: keyof T, value: any) => {
    setValues(prev => ({ ...prev, [field]: value }))
  }, [])

  const setError = useCallback((field: keyof T, error: string) => {
    setErrors(prev => ({ ...prev, [field]: error }))
  }, [])

  const clearError = useCallback((field: keyof T) => {
    setErrors(prev => ({ ...prev, [field]: undefined }))
  }, [])

  const isValid = options.validationSchema ? Object.keys(errors).length === 0 : true

  return {
    values,
    errors,
    touched,
    isSubmitting,
    isValid,
    handleChange,
    handleBlur,
    handleSubmit,
    resetForm,
    setFieldValue,
    setError,
    clearError,
  }
}

// Hook for file uploads
export interface UseFileUploadOptions {
  accept?: string
  multiple?: boolean
  maxSize?: number
  onUpload?: (files: File[]) => Promise<void>
  onError?: (error: Error) => void
}

export interface UseFileUploadReturn {
  files: File[]
  isUploading: boolean
  dragActive: boolean
  selectedFiles: File[]
  errors: string[]
  handleDrag: (e: React.DragEvent) => void
  handleDragEnter: (e: React.DragEvent) => void
  handleDragLeave: (e: React.DragEvent) => void
  handleDrop: (e: React.DragEvent) => void
  handleFileSelect: (files: File[]) => void
  removeFile: (index: number) => void
  clearFiles: () => void
  uploadFiles: () => Promise<void>
}

export function useFileUpload(options: UseFileUploadOptions = {}): UseFileUploadReturn {
  const [files, setFiles] = useState<File[]>([])
  const [isUploading, setIsUploading] = useState(false)
  const [dragActive, setDragActive] = useState(false)
  const [errors, setErrors] = useState<string[]>([])

  const validateFiles = useCallback((fileList: File[]): string[] => {
    const newErrors: string[] = []

    Array.from(fileList).forEach(file => {
      // Check file size
      if (options.maxSize && file.size > options.maxSize) {
        newErrors.push(`File "${file.name}" is too large. Maximum size is ${options.maxSize / 1024 / 1024}MB`)
      }

      // Check file type
      if (options.accept && !options.accept.split(',').some(type => {
        if (type.startsWith('.')) {
          return file.name.toLowerCase().endsWith(type.toLowerCase())
        }
        return file.type.includes(type.replace('*', ''))
      })) {
        newErrors.push(`File "${file.name}" is not a valid type. Accepted types: ${options.accept}`)
      }
    })

    return newErrors
  }, [options.maxSize, options.accept])

  const handleDrag = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
  }, [])

  const handleDragEnter = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    setDragActive(true)
  }, [])

  const handleDragLeave = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    setDragActive(false)
  }, [])

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    setDragActive(false)

    const droppedFiles = Array.from(e.dataTransfer.files)
    if (!options.multiple) {
      handleFileSelect([droppedFiles[0]])
    } else {
      handleFileSelect(droppedFiles)
    }
  }, [options.multiple])

  const handleFileSelect = useCallback((fileList: File[]) => {
    const validationErrors = validateFiles(fileList)

    if (validationErrors.length > 0) {
      setErrors(validationErrors)
      options.onError?.(new Error(validationErrors.join(', ')))
      return
    }

    setErrors([])

    if (!options.multiple) {
      setFiles(fileList.slice(0, 1))
    } else {
      setFiles(prev => [...prev, ...fileList])
    }
  }, [validateFiles, options.multiple, options.onError])

  const removeFile = useCallback((index: number) => {
    setFiles(prev => prev.filter((_, i) => i !== index))
  }, [])

  const clearFiles = useCallback(() => {
    setFiles([])
    setErrors([])
  }, [])

  const uploadFiles = useCallback(async () => {
    if (files.length === 0) return

    setIsUploading(true)
    try {
      await options.onUpload?.(files)
      setFiles([])
    } catch (error) {
      options.onError?.(error instanceof Error ? error : new Error('Upload failed'))
    } finally {
      setIsUploading(false)
    }
  }, [files, options])

  const selectedFiles = files

  return {
    files,
    isUploading,
    dragActive,
    selectedFiles,
    errors,
    handleDrag,
    handleDragEnter,
    handleDragLeave,
    handleDrop,
    handleFileSelect,
    removeFile,
    clearFiles,
    uploadFiles,
  }
}
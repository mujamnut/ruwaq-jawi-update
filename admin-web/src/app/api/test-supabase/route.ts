import { NextRequest, NextResponse } from 'next/server'
import { supabaseAdmin } from '@/lib/supabase'

export async function GET(request: NextRequest) {
  try {
    console.log('Testing Supabase connection...')

    // Test basic connection
    const { data, error } = await supabaseAdmin
      .from('user_subscriptions')
      .select('count')
      .limit(1)

    console.log('Supabase test result:', { data, error })

    if (error) {
      console.error('Supabase connection error:', error)
      return NextResponse.json({
        success: false,
        error: error.message,
        hint: error.hint,
        details: error
      }, { status: 400 })
    }

    return NextResponse.json({
      success: true,
      message: 'Supabase connection working',
      data: data
    })

  } catch (err) {
    console.error('Unexpected error:', err)
    return NextResponse.json({
      success: false,
      error: 'Unexpected error occurred',
      details: err
    }, { status: 500 })
  }
}
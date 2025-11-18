import { NextRequest, NextResponse } from 'next/server'
import { supabaseAdmin } from '@/lib/supabase'

export async function GET(request: NextRequest) {
  try {
    console.log('Testing payments data...')

    // Test basic connection to payments table
    const { data: payments, error: paymentsError } = await supabaseAdmin
      .from('payments')
      .select('*')
      .limit(5)

    console.log('Payments test result:', { payments, error: paymentsError })

    if (paymentsError) {
      console.error('Payments table error:', paymentsError)
      return NextResponse.json({
        success: false,
        error: paymentsError.message,
        hint: paymentsError.hint,
        details: paymentsError
      }, { status: 400 })
    }

    // Test if there are any payments
    const { data: paymentsCount, error: countError } = await supabaseAdmin
      .from('payments')
      .select('count', { count: 'exact', head: true })

    console.log('Payments count result:', { count: paymentsCount, error: countError })

    // Test users table to see user data structure
    const { data: users, error: usersError } = await supabaseAdmin
      .from('users')
      .select('*')
      .limit(3)

    console.log('Users test result:', { users, error: usersError })

    // Test profiles table if it exists
    let profilesData = null
    let profilesError = null
    try {
      const { data: profiles, error: profilesErr } = await supabaseAdmin
        .from('profiles')
        .select('*')
        .limit(3)
      profilesData = profiles
      profilesError = profilesErr
      console.log('Profiles test result:', { profiles, error: profilesErr })
    } catch (err) {
      console.log('Profiles table does not exist or is not accessible:', err)
    }

    return NextResponse.json({
      success: true,
      message: 'Payments data test successful',
      data: {
        paymentsCount: paymentsCount?.[0]?.count || 0,
        samplePayments: payments || [],
        hasProfilesTable: !profilesError,
        sampleProfiles: profilesData || [],
        sampleUsers: users || [],
        errors: {
          payments: paymentsError,
          count: countError,
          users: usersError,
          profiles: profilesError
        }
      }
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
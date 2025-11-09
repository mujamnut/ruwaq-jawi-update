// Temporary script to create admin user
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://ckgxglvozrsognqqkpkk.supabase.co'
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNrZ3hnbHZvenJzb2ducXFrcGtrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYyOTIwMDYsImV4cCI6MjA3MTg2ODAwNn0.AnTcS1uSC83m7pYT9UxAb_enhcEGCIor49AhuyCTkiQ'

const supabase = createClient(supabaseUrl, supabaseAnonKey)

async function createAdminUser() {
  try {
    // Create user with known credentials
    const { data, error } = await supabase.auth.admin.createUser({
      email: 'admin@ruwaq.app',
      password: 'RuwaqAdmin2024!',
      email_confirm: true,
      user_metadata: {
        role: 'admin',
        full_name: 'Admin User'
      }
    })

    if (error) {
      console.error('Error creating user:', error)
      return
    }

    console.log('User created:', data)

    // Create profile record
    if (data.user) {
      const { error: profileError } = await supabase
        .from('profiles')
        .insert({
          id: data.user.id,
          email: data.user.email,
          full_name: 'Admin User',
          role: 'admin',
          subscription_status: 'active'
        })

      if (profileError) {
        console.error('Error creating profile:', profileError)
      } else {
        console.log('Profile created successfully')
      }
    }
  } catch (error) {
    console.error('Unexpected error:', error)
  }
}

createAdminUser()
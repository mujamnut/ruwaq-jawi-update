-- Create admin_users table for better admin management
CREATE TABLE IF NOT EXISTS admin_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR UNIQUE NOT NULL,
  name VARCHAR NOT NULL,
  role VARCHAR DEFAULT 'admin',
  permissions JSONB DEFAULT '["read", "write", "delete", "admin"]',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_admin_users_email ON admin_users(email);
CREATE INDEX IF NOT EXISTS idx_admin_users_is_active ON admin_users(is_active);

-- Insert default admin user
INSERT INTO admin_users (email, name, role, permissions)
VALUES ('mujj4m@gmail.com', 'Main Admin', 'super_admin', '["read", "write", "delete", "admin", "manage_users"]')
ON CONFLICT (email) DO NOTHING;
-- Combined migrations file

-- Drop community tables (from 20240312_drop_community_tables.sql)
DROP TABLE IF EXISTS public.community_comments CASCADE;
DROP TABLE IF EXISTS public.post_votes CASCADE;
DROP TABLE IF EXISTS public.community_posts CASCADE;
DROP VIEW IF EXISTS public.posts_with_users CASCADE;
DROP FUNCTION IF EXISTS public.update_post_vote_count CASCADE;

-- Create profiles table (from 20240000000000_create_profiles.sql)
create table if not exists profiles (
  id uuid references auth.users on delete cascade not null primary key,
  full_name text,
  username text unique,
  website text,
  avatar_url text,
  bio text,
  updated_at timestamp with time zone,

  constraint username_length check (char_length(username) >= 3)
);

-- Set up Row Level Security (RLS)
alter table profiles enable row level security;

-- Create profile policies
create policy "Public profiles are viewable by everyone."
  on profiles for select
  using ( true );

create policy "Users can insert their own profile."
  on profiles for insert
  with check ( auth.uid() = id );

create policy "Users can update their own profile."
  on profiles for update
  using ( auth.uid() = id );

-- Create users table (from 20231213_users_table.sql)
create table if not exists public.users (
    id uuid references auth.users(id) primary key,
    email text not null,
    credits integer default 0 not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS for users
alter table public.users enable row level security;

-- Create user policies
create policy "Users can view their own data"
    on public.users for select
    using (auth.uid() = id);

create policy "Users can update their own data"
    on public.users for update
    using (auth.uid() = id);

-- Create user_credits table (from 20240311_create_user_credits.sql)
CREATE TABLE IF NOT EXISTS user_credits (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    credits INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    UNIQUE(user_id)
);

-- Enable RLS for user_credits
ALTER TABLE IF EXISTS user_credits ENABLE ROW LEVEL SECURITY;

-- Create an index on user_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_credits_user_id ON user_credits(user_id);

-- Create user_credits policies
CREATE POLICY "Users can view their own credits"
    ON user_credits FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own credits"
    ON user_credits FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own credits"
    ON user_credits FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- Grant necessary permissions
GRANT ALL ON user_credits TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE user_credits_id_seq TO authenticated;

-- Create subscription_plans table (from 20240000000001_create_subscriptions.sql)
CREATE TABLE IF NOT EXISTS subscription_plans (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  description text,
  price_id text NOT NULL, -- Stripe Price ID
  amount numeric(10,2) NOT NULL,
  currency text NOT NULL DEFAULT 'usd',
  interval text NOT NULL, -- 'month' or 'year'
  active boolean DEFAULT true,
  features jsonb,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create customer_subscriptions table
CREATE TABLE IF NOT EXISTS customer_subscriptions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid REFERENCES auth.users NOT NULL,
  subscription_id text NOT NULL, -- Stripe Subscription ID
  status text NOT NULL,
  price_id text NOT NULL,
  quantity integer DEFAULT 1,
  cancel_at_period_end boolean DEFAULT false,
  cancel_at timestamp with time zone,
  canceled_at timestamp with time zone,
  current_period_start timestamp with time zone NOT NULL,
  current_period_end timestamp with time zone NOT NULL,
  created timestamp with time zone NOT NULL,
  ended_at timestamp with time zone,
  trial_start timestamp with time zone,
  trial_end timestamp with time zone
);

-- Create billing_history table
CREATE TABLE IF NOT EXISTS billing_history (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid REFERENCES auth.users NOT NULL,
  subscription_id uuid REFERENCES customer_subscriptions,
  amount numeric(10,2) NOT NULL,
  currency text NOT NULL DEFAULT 'usd',
  status text NOT NULL,
  invoice_url text,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Add RLS policies
ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE billing_history ENABLE ROW LEVEL SECURITY;

-- Policies for subscription_plans
CREATE POLICY "Allow public read access to active plans" ON subscription_plans
  FOR SELECT USING (active = true);

-- Policies for customer_subscriptions
CREATE POLICY "Users can view their own subscriptions" ON customer_subscriptions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own subscriptions" ON customer_subscriptions
  FOR UPDATE USING (auth.uid() = user_id);

-- Policies for billing_history
CREATE POLICY "Users can view their own billing history" ON billing_history
  FOR SELECT USING (auth.uid() = user_id);

-- Create customers table (from 20240000000002_create_customers.sql)
CREATE TABLE IF NOT EXISTS customers (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid REFERENCES auth.users NOT NULL,
  stripe_customer_id text NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(user_id),
  UNIQUE(stripe_customer_id)
);

-- Enable RLS for customers
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

-- Policies for customers
CREATE POLICY "Users can view their own customer data" ON customers
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Service role can manage all customer data" ON customers
  USING (auth.jwt()->>'role' = 'service_role');

-- Indexes for customers
CREATE INDEX IF NOT EXISTS customers_user_id_idx ON customers(user_id);
CREATE INDEX IF NOT EXISTS customers_stripe_customer_id_idx ON customers(stripe_customer_id);

-- Create trigger functions
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE OR REPLACE FUNCTION update_user_credits_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Insert into profiles
  INSERT INTO public.profiles (id)
  VALUES (NEW.id);
  
  -- Insert into users
  INSERT INTO public.users (id, email, credits)
  VALUES (NEW.id, NEW.email, 0)
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers
DROP TRIGGER IF EXISTS update_user_credits_updated_at ON user_credits;
CREATE TRIGGER update_user_credits_updated_at
    BEFORE UPDATE ON user_credits
    FOR EACH ROW
    EXECUTE FUNCTION update_user_credits_updated_at();

DROP TRIGGER IF EXISTS handle_updated_at ON public.users;
CREATE TRIGGER handle_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Insert default subscription plans
INSERT INTO subscription_plans (name, description, price_id, amount, interval, features) VALUES
('Starter', 'Perfect for side projects and small startups', 'price_1QTPalGI6vk81n8V8PtyW1ow', 99.00, 'month', '["Up to 5 team members", "Basic analytics", "Community support", "5GB storage", "API access"]'),
('Pro', 'Best for growing businesses', 'price_1QTPbgGI6vk81n8VgYFOi983', 249.00, 'month', '["Unlimited team members", "Advanced analytics", "Priority support", "50GB storage", "API access", "Custom integrations"]'),
('Enterprise', 'For large scale applications', 'price_1QTPcUGI6vk81n8V9567pzL9', 999.00, 'month', '["Unlimited everything", "White-label options", "24/7 phone support", "500GB storage", "API access", "Custom development"]')
ON CONFLICT (id) DO NOTHING;
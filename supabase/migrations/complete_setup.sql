-- Complete SaaS Kit Database Setup
-- This file combines all migrations in the correct order

BEGIN;

-- ==========================================
-- 1. Drop existing objects to start clean
-- ==========================================
DROP TABLE IF EXISTS public.community_comments CASCADE;
DROP TABLE IF EXISTS public.post_votes CASCADE;
DROP TABLE IF EXISTS public.community_posts CASCADE;
DROP VIEW IF EXISTS public.posts_with_users CASCADE;
DROP FUNCTION IF EXISTS public.update_post_vote_count CASCADE;
DROP FUNCTION IF EXISTS public.handle_updated_at CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user CASCADE;
DROP FUNCTION IF EXISTS public.update_user_credits_updated_at CASCADE;

-- Make sure to drop triggers first
DROP TRIGGER IF EXISTS handle_updated_at ON public.users CASCADE;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users CASCADE;
DROP TRIGGER IF EXISTS update_user_credits_updated_at ON user_credits CASCADE;

-- Drop tables if they exist
DROP TABLE IF EXISTS public.billing_history CASCADE;
DROP TABLE IF EXISTS public.customer_subscriptions CASCADE;
DROP TABLE IF EXISTS public.subscription_plans CASCADE;
DROP TABLE IF EXISTS public.customers CASCADE;
DROP TABLE IF EXISTS public.user_credits CASCADE;
DROP TABLE IF EXISTS public.subscriptions CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;

-- ==========================================
-- 2. Create utility functions
-- ==========================================
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_user_credits_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- 3. Create tables in dependency order
-- ==========================================

-- Create users table
CREATE TABLE public.users (
    id uuid REFERENCES auth.users(id) PRIMARY KEY,
    email text NOT NULL,
    credits integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at timestamp with time zone DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Create profiles table
CREATE TABLE public.profiles (
  id uuid REFERENCES auth.users ON DELETE CASCADE NOT NULL PRIMARY KEY,
  full_name text,
  username text UNIQUE,
  website text,
  avatar_url text,
  bio text,
  updated_at timestamp with time zone,
  CONSTRAINT username_length CHECK (char_length(username) >= 3)
);

-- Create user_credits table
CREATE TABLE public.user_credits (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    credits INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    UNIQUE(user_id)
);

-- Create customers table
CREATE TABLE public.customers (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid REFERENCES auth.users NOT NULL,
  stripe_customer_id text NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(user_id),
  UNIQUE(stripe_customer_id)
);

-- Create subscription plans table
CREATE TABLE public.subscription_plans (
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

-- Create customer subscriptions table
CREATE TABLE public.customer_subscriptions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid REFERENCES auth.users NOT NULL,
  subscription_id text NOT NULL, -- Stripe Subscription ID
  plan_id uuid REFERENCES subscription_plans NOT NULL,
  status text NOT NULL,
  current_period_start timestamp with time zone NOT NULL,
  current_period_end timestamp with time zone NOT NULL,
  cancel_at_period_end boolean DEFAULT false,
  canceled_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create billing history table
CREATE TABLE public.billing_history (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid REFERENCES auth.users NOT NULL,
  subscription_id uuid REFERENCES customer_subscriptions,
  amount numeric(10,2) NOT NULL,
  currency text NOT NULL DEFAULT 'usd',
  status text NOT NULL,
  invoice_url text,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create legacy subscriptions table
CREATE TABLE public.subscriptions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    status text NOT NULL,
    plan_id text NOT NULL,
    current_period_end timestamp with time zone NOT NULL,
    cancel_at_period_end boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ==========================================
-- 4. Create indexes
-- ==========================================
CREATE INDEX idx_user_credits_user_id ON user_credits(user_id);
CREATE INDEX customers_user_id_idx ON customers(user_id);
CREATE INDEX customers_stripe_customer_id_idx ON customers(stripe_customer_id);

-- ==========================================
-- 5. Enable RLS on all tables
-- ==========================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_credits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

-- ==========================================
-- 6. Create RLS policies
-- ==========================================
-- Users table policies
CREATE POLICY "Users can view their own data"
    ON public.users FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update their own data"
    ON public.users FOR UPDATE
    USING (auth.uid() = id);

-- Profiles table policies
CREATE POLICY "Public profiles are viewable by everyone."
  ON profiles FOR SELECT
  USING (true);

CREATE POLICY "Users can insert their own profile."
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile."
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- User credits policies
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

-- Customers policies
CREATE POLICY "Users can view their own customer data" ON customers
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Service role can manage all customer data" ON customers
  USING (auth.jwt()->>'role' = 'service_role');

-- Subscription plans policies
CREATE POLICY "Allow public read access to active plans" ON subscription_plans
  FOR SELECT USING (active = true);

-- Customer subscriptions policies
CREATE POLICY "Users can view their own subscriptions" ON customer_subscriptions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own subscriptions" ON customer_subscriptions
  FOR UPDATE USING (auth.uid() = user_id);

-- Billing history policies
CREATE POLICY "Users can view their own billing history" ON billing_history
  FOR SELECT USING (auth.uid() = user_id);

-- Legacy subscriptions policies
CREATE POLICY "Users can view own subscription data"
    ON public.subscriptions
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- ==========================================
-- 7. Create triggers
-- ==========================================
CREATE TRIGGER handle_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_updated_at
    BEFORE UPDATE ON public.subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_updated_at
    BEFORE UPDATE ON subscription_plans
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_updated_at
    BEFORE UPDATE ON customer_subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_updated_at
    BEFORE UPDATE ON customers
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER update_user_credits_updated_at
    BEFORE UPDATE ON user_credits
    FOR EACH ROW
    EXECUTE FUNCTION update_user_credits_updated_at();

-- ==========================================
-- 8. Create function to handle new users
-- ==========================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert into profiles
    INSERT INTO public.profiles (id)
    VALUES (NEW.id)
    ON CONFLICT (id) DO NOTHING;
    
    -- Insert into users
    INSERT INTO public.users (id, email, credits)
    VALUES (NEW.id, NEW.email, 0)
    ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email;
    
    -- Insert into user_credits
    INSERT INTO public.user_credits (user_id, credits)
    VALUES (NEW.id, 0)
    ON CONFLICT (user_id) DO NOTHING;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new user
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- ==========================================
-- 9. Grant necessary permissions
-- ==========================================
GRANT ALL ON user_credits TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE user_credits_id_seq TO authenticated;

-- ==========================================
-- 10. Insert default subscription plans
-- ==========================================
INSERT INTO subscription_plans (name, description, price_id, amount, interval, features) 
VALUES
('Starter', 'Perfect for side projects and small startups', 'price_starter', 99.00, 'month', '["Up to 5 team members", "Basic analytics", "Community support", "5GB storage", "API access"]'),
('Pro', 'Best for growing businesses', 'price_pro', 249.00, 'month', '["Unlimited team members", "Advanced analytics", "Priority support", "50GB storage", "API access", "Custom integrations"]'),
('Enterprise', 'For large scale applications', 'price_enterprise', 999.00, 'month', '["Unlimited everything", "White-label options", "24/7 phone support", "500GB storage", "API access", "Custom development"]')
ON CONFLICT DO NOTHING;

COMMIT; 
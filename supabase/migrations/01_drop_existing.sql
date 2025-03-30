-- Step 1: Drop existing objects to start clean
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
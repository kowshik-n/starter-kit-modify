-- Step 6: Create RLS policies
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
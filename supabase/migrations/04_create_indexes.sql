-- Step 4: Create indexes
CREATE INDEX idx_user_credits_user_id ON user_credits(user_id);
CREATE INDEX customers_user_id_idx ON customers(user_id);
CREATE INDEX customers_stripe_customer_id_idx ON customers(stripe_customer_id); 
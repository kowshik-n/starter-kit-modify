-- Step 10: Insert default subscription plans
INSERT INTO subscription_plans (name, description, price_id, amount, interval, features) 
VALUES
('Starter', 'Perfect for side projects and small startups', 'price_starter', 99.00, 'month', '["Up to 5 team members", "Basic analytics", "Community support", "5GB storage", "API access"]'),
('Pro', 'Best for growing businesses', 'price_pro', 249.00, 'month', '["Unlimited team members", "Advanced analytics", "Priority support", "50GB storage", "API access", "Custom integrations"]'),
('Enterprise', 'For large scale applications', 'price_enterprise', 999.00, 'month', '["Unlimited everything", "White-label options", "24/7 phone support", "500GB storage", "API access", "Custom development"]')
ON CONFLICT DO NOTHING; 
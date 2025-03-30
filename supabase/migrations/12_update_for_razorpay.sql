-- Update customers table to use Razorpay
ALTER TABLE customers 
RENAME COLUMN stripe_customer_id TO razorpay_customer_id;

-- Update subscription_plans table
ALTER TABLE subscription_plans
RENAME COLUMN price_id TO plan_id;

-- Update default plans
UPDATE subscription_plans 
SET plan_id = 'plan_starter_razorpay', 
    amount = 999.00
WHERE name = 'Starter';

UPDATE subscription_plans 
SET plan_id = 'plan_pro_razorpay', 
    amount = 2499.00
WHERE name = 'Pro';

UPDATE subscription_plans 
SET plan_id = 'plan_enterprise_razorpay', 
    amount = 9999.00
WHERE name = 'Enterprise'; 
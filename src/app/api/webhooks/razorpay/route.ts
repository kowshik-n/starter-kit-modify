import { NextResponse } from 'next/server'
import { headers } from 'next/headers'
import { createClientComponentClient } from '@supabase/auth-helpers-nextjs'
import crypto from 'crypto'

const webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET!

export async function POST(req: Request) {
  try {
    const body = await req.text()
    const headersList = headers()
    const signature = headersList.get('x-razorpay-signature')

    if (!signature) {
      return NextResponse.json(
        { error: 'Missing signature header' },
        { status: 400 }
      )
    }

    // Verify webhook signature
    const expectedSignature = crypto
      .createHmac('sha256', webhookSecret)
      .update(body)
      .digest('hex')

    if (expectedSignature !== signature) {
      return NextResponse.json(
        { error: 'Invalid signature' },
        { status: 400 }
      )
    }

    const event = JSON.parse(body)
    const supabase = createClientComponentClient()

    // Handle the event
    switch (event.event) {
      case 'subscription.authenticated': {
        const subscription = event.payload.subscription.entity
        
        // Add subscription to database
        await supabase.from('customer_subscriptions').insert({
          user_id: subscription.notes.userId,
          subscription_id: subscription.id,
          status: subscription.status,
          price_id: subscription.plan_id,
          quantity: subscription.quantity,
          cancel_at_period_end: false,
          current_period_start: new Date(subscription.current_start * 1000).toISOString(),
          current_period_end: new Date(subscription.current_end * 1000).toISOString(),
          created: new Date(subscription.created_at * 1000).toISOString(),
        })
        
        break
      }

      case 'subscription.updated': {
        const subscription = event.payload.subscription.entity
        
        // Update subscription in database
        await supabase
          .from('customer_subscriptions')
          .update({
            status: subscription.status,
            cancel_at_period_end: subscription.has_scheduled_changes,
            current_period_start: new Date(subscription.current_start * 1000).toISOString(),
            current_period_end: new Date(subscription.current_end * 1000).toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq('subscription_id', subscription.id)
        
        break
      }

      case 'subscription.cancelled': {
        const subscription = event.payload.subscription.entity
        
        // Update subscription in database
        await supabase
          .from('customer_subscriptions')
          .update({
            status: 'cancelled',
            cancel_at_period_end: false,
            canceled_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq('subscription_id', subscription.id)
        
        break
      }

      case 'payment.captured': {
        const payment = event.payload.payment.entity
        
        // Add to billing history
        await supabase.from('billing_history').insert({
          user_id: payment.notes.userId,
          amount: payment.amount / 100, // Convert from paise to rupees
          currency: payment.currency,
          status: 'succeeded',
          invoice_url: payment.invoice_id ? `https://dashboard.razorpay.com/app/invoices/${payment.invoice_id}` : null,
          created_at: new Date().toISOString(),
        })
        
        break
      }
    }

    return NextResponse.json({ received: true })
  } catch (err) {
    console.error('Error processing webhook:', err)
    return NextResponse.json(
      { error: 'Error processing webhook' },
      { status: 400 }
    )
  }
} 
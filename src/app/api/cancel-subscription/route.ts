import { NextResponse } from 'next/server'
import { createClientComponentClient } from '@supabase/auth-helpers-nextjs'
import { razorpay } from '@/lib/razorpay'

export async function POST(req: Request) {
  try {
    const body = await req.json()
    const { subscriptionId } = body

    const supabase = createClientComponentClient()

    // Get the subscription from database
    const { data: subscription } = await supabase
      .from('customer_subscriptions')
      .select('subscription_id')
      .eq('id', subscriptionId)
      .single()

    if (!subscription) {
      return NextResponse.json(
        { error: 'Subscription not found' },
        { status: 404 }
      )
    }

    // Cancel the subscription
    await razorpay.subscriptions.cancel(subscription.subscription_id, {
      cancel_at_cycle_end: true,
    })

    // Update subscription in database
    await supabase
      .from('customer_subscriptions')
      .update({
        cancel_at_period_end: true,
        updated_at: new Date().toISOString(),
      })
      .eq('id', subscriptionId)

    return NextResponse.json({ success: true })
  } catch (err) {
    console.error('Error canceling subscription:', err)
    return NextResponse.json(
      { error: 'Error canceling subscription' },
      { status: 500 }
    )
  }
} 
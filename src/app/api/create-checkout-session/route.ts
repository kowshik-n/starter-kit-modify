import { NextResponse } from 'next/server'
import { cookies } from 'next/headers'
import { createRouteHandlerClient } from '@supabase/auth-helpers-nextjs'
import { razorpay } from '@/lib/razorpay'

export async function POST(req: Request) {
  try {
    const body = await req.json()
    const { priceId } = body

    if (!priceId) {
      return NextResponse.json(
        { error: 'Price ID is required' },
        { status: 400 }
      )
    }

    // Initialize Supabase client with cookies
    const supabase = createRouteHandlerClient({ cookies })

    // Get the user from the session
    const { data, error: sessionError } = await supabase.auth.getSession()
    
    if (sessionError) {
      console.error('Session error:', sessionError)
      return NextResponse.json(
        { error: 'Authentication error' },
        { status: 401 }
      )
    }

    const session = data.session
    if (!session?.user) {
      console.error('No session or user found')
      return NextResponse.json(
        { error: 'Please log in to continue' },
        { status: 401 }
      )
    }

    const userId = session.user.id
    const customerEmail = session.user.email

    // Get the price details from the database
    const { data: priceData } = await supabase
      .from('subscription_plans')
      .select('amount, name, interval')
      .eq('price_id', priceId)
      .single()

    if (!priceData) {
      return NextResponse.json(
        { error: 'Price not found' },
        { status: 404 }
      )
    }

    // Create or retrieve Razorpay customer
    const { data: existingCustomer } = await supabase
      .from('customers')
      .select('razorpay_customer_id')
      .eq('user_id', userId)
      .single()

    let customerId: string

    if (existingCustomer?.razorpay_customer_id) {
      customerId = existingCustomer.razorpay_customer_id
    } else {
      // Create a new Razorpay customer
      const customer = await razorpay.customers.create({
        name: customerEmail?.split('@')[0] || 'Customer',
        email: customerEmail,
        notes: {
          userId: userId,
        },
      })
      customerId = customer.id

      await supabase.from('customers').insert({
        user_id: userId,
        razorpay_customer_id: customerId,
      })
    }

    // Calculate amount in paise (Razorpay uses smallest currency unit)
    const amountInPaise = Math.round(priceData.amount * 100)

    // Create a subscription
    const subscription = await razorpay.subscriptions.create({
      plan_id: priceId,
      customer_id: customerId,
      total_count: 12, // For 12 months, adjust as needed
      quantity: 1,
      notes: {
        userId: userId,
      },
    })

    // Create a payment link for the subscription
    const paymentLink = await razorpay.paymentLink.create({
      amount: amountInPaise,
      currency: 'INR',
      accept_partial: false,
      description: `Subscription to ${priceData.name} plan`,
      customer: {
        name: customerEmail?.split('@')[0] || 'Customer',
        email: customerEmail,
      },
      notify: {
        email: true,
      },
      reminder_enable: true,
      notes: {
        userId: userId,
        subscriptionId: subscription.id,
      },
      callback_url: `${process.env.NEXT_PUBLIC_APP_URL}/dashboard/billing?success=true&subscription_id=${subscription.id}`,
      callback_method: 'get',
    })

    return NextResponse.json({ url: paymentLink.short_url, subscriptionId: subscription.id })
  } catch (err) {
    console.error('Error creating checkout session:', err)
    return NextResponse.json(
      { error: 'Error creating checkout session' },
      { status: 500 }
    )
  }
} 
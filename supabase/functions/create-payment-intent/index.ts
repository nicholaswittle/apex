import Stripe from 'https://esm.sh/stripe@14.21.0?target=deno'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type, apikey, x-client-info',
}

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

function paymentIntentIdFromClientSecret(clientSecret: string): string | null {
  const match = clientSecret.match(/^(pi_[A-Za-z0-9]+)/)
  return match?.[1] ?? null
}

async function requireUser(req: Request) {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    return { error: json(401, { error: 'Missing authorization header' }) }
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!
  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  })

  const { data: { user }, error } = await userClient.auth.getUser()
  if (error || !user) {
    return { error: json(401, { error: 'Unauthorized' }) }
  }

  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!serviceRoleKey) {
    return { error: json(503, { error: 'Billing backend is not configured' }) }
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey)
  return { user, adminClient }
}

async function resolveStripeCustomer(
  stripe: Stripe,
  adminClient: ReturnType<typeof createClient>,
  user: { id: string; email?: string | null; user_metadata?: Record<string, unknown> },
) {
  const profile = await adminClient
    .from('profiles')
    .select('email, role')
    .eq('id', user.id)
    .maybeSingle()

  const existingId = user.user_metadata?.stripe_customer_id
  if (typeof existingId === 'string' && existingId.length > 0) {
    return existingId
  }

  const customer = await stripe.customers.create({
    email: profile.data?.email ?? user.email ?? undefined,
    metadata: { supabase_user_id: user.id },
  })

  await adminClient.auth.admin.updateUserById(user.id, {
    user_metadata: {
      ...user.user_metadata,
      stripe_customer_id: customer.id,
    },
  })

  return customer.id
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return json(405, { error: 'Method not allowed' })
  }

  const stripeSecret = Deno.env.get('STRIPE_SECRET_KEY')
  if (!stripeSecret) {
    return json(503, { error: 'STRIPE_SECRET_KEY is not configured' })
  }

  const auth = await requireUser(req)
  if ('error' in auth && auth.error) return auth.error
  const { user, adminClient } = auth

  let body: Record<string, unknown>
  try {
    body = await req.json()
  } catch {
    return json(400, { error: 'Malformed JSON body' })
  }

  const stripe = new Stripe(stripeSecret, { apiVersion: '2023-10-16' })
  const action = typeof body.action === 'string' ? body.action : 'create'

  if (action === 'activate_subscription') {
    const paymentIntentId =
      (typeof body.paymentIntentId === 'string' && body.paymentIntentId) ||
      (typeof body.paymentIntent === 'string'
        ? paymentIntentIdFromClientSecret(body.paymentIntent)
        : null)

    if (!paymentIntentId) {
      return json(400, { error: 'Missing paymentIntentId' })
    }

    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId)
    if (paymentIntent.status !== 'succeeded') {
      return json(402, {
        error: 'Payment has not succeeded yet',
        status: paymentIntent.status,
      })
    }

    const customerId = typeof paymentIntent.customer === 'string'
      ? paymentIntent.customer
      : paymentIntent.customer?.id

    const ownerCustomerId = user.user_metadata?.stripe_customer_id
    if (
      customerId &&
      typeof ownerCustomerId === 'string' &&
      ownerCustomerId.length > 0 &&
      customerId !== ownerCustomerId
    ) {
      return json(403, { error: 'Payment intent does not belong to this account' })
    }

    const { error: updateError } = await adminClient
      .from('profiles')
      .update({ subscription_status: 'active' })
      .eq('id', user.id)

    if (updateError) {
      return json(500, { error: updateError.message })
    }

    return json(200, { activated: true, subscription_status: 'active' })
  }

  if (action === 'cancel_subscription') {
    const { error: updateError } = await adminClient
      .from('profiles')
      .update({ subscription_status: 'inactive' })
      .eq('id', user.id)

    if (updateError) {
      return json(500, { error: updateError.message })
    }

    return json(200, { cancelled: true, subscription_status: 'inactive' })
  }

  const amount = Number(body.amount)
  const currency = typeof body.currency === 'string' ? body.currency.toLowerCase() : 'usd'

  if (!Number.isFinite(amount) || amount <= 0) {
    return json(400, { error: 'Missing or invalid amount' })
  }

  const customerId = await resolveStripeCustomer(stripe, adminClient, user)

  const ephemeralKey = await stripe.ephemeralKeys.create(
    { customer: customerId },
    { apiVersion: '2023-10-16' },
  )

  const paymentIntent = await stripe.paymentIntents.create({
    amount: Math.round(amount),
    currency,
    customer: customerId,
    automatic_payment_methods: { enabled: true },
    metadata: {
      supabase_user_id: user.id,
      product: 'apex_scheduler_subscription',
    },
  })

  if (!paymentIntent.client_secret) {
    return json(500, { error: 'Stripe did not return a client secret' })
  }

  return json(200, {
    paymentIntent: paymentIntent.client_secret,
    paymentIntentId: paymentIntent.id,
    ephemeralKey: ephemeralKey.secret,
    customer: customerId,
  })
})

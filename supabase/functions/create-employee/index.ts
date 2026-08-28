// Supabase Edge Function: create-employee
//
// Why this exists as a server-side function instead of something the
// Flutter app does directly: creating a *login* for someone else requires
// Supabase's admin API, which needs the project's secret "service role"
// key. That key must never be shipped inside a mobile app (it bypasses
// every RLS policy) — so this privileged step lives here instead, on
// Supabase's servers, where the secret key stays out of reach.
//
// Flow:
//   1. Read the caller's own access token from the Authorization header.
//   2. Look up the caller's profile *as that caller* (via the anon key +
//      their token, so normal RLS applies) to confirm they're an owner.
//   3. Only then use the privileged (service role) client to create the
//      new auth user and insert their `profiles` row in the same company.
//
// CORS: the web build calls this from a browser, which sends a preflight
// OPTIONS request before the real POST. Without the headers below the
// browser blocks the response before our code runs, and Flutter just
// reports a generic "Failed to fetch" — see register-company's comment for
// the full story on why this only shows up when calling from a browser.
//
// Deploy via the Supabase Dashboard: Edge Functions -> Create a new
// function -> name it "create-employee" -> paste this file's contents ->
// Deploy. No local CLI/Docker needed for this.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { email, password, full_name, phone } = await req.json()

    if (!email || !password || !full_name) {
      return jsonResponse({ error: 'email, password and full_name are required' }, 400)
    }
    if (typeof password !== 'string' || password.length < 6) {
      return jsonResponse({ error: 'password must be at least 6 characters' }, 400)
    }

    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return jsonResponse({ error: 'Missing Authorization header' }, 401)
    }

    // Scoped to the CALLER's own session — used only to verify who is
    // calling. Normal RLS policies apply to every query made with this
    // client, exactly as if the app itself had made the query.
    const callerClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    )

    const {
      data: { user: caller },
    } = await callerClient.auth.getUser()

    if (!caller) {
      return jsonResponse({ error: 'Invalid session' }, 401)
    }

    const { data: callerProfile, error: profileError } = await callerClient
      .from('profiles')
      .select('role, company_id')
      .eq('id', caller.id)
      .single()

    if (profileError || !callerProfile || callerProfile.role !== 'owner') {
      return jsonResponse({ error: 'Only an owner can add employees' }, 403)
    }

    // Privileged client — only ever used after the owner check above, and
    // never exposed to the app itself.
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const { data: created, error: createError } = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    })

    if (createError || !created.user) {
      return jsonResponse({ error: createError?.message ?? 'Could not create user' }, 400)
    }

    const { error: insertError } = await adminClient.from('profiles').insert({
      id: created.user.id,
      company_id: callerProfile.company_id,
      role: 'employee',
      full_name,
      phone: phone ?? null,
    })

    if (insertError) {
      // Don't leave a login with no profile behind if this step fails.
      await adminClient.auth.admin.deleteUser(created.user.id)
      return jsonResponse({ error: insertError.message }, 400)
    }

    return jsonResponse({ id: created.user.id }, 200)
  } catch (err) {
    return jsonResponse({ error: String(err) }, 500)
  }
})

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  })
}

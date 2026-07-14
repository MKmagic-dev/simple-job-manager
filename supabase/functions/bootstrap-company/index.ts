// Supabase Edge Function: bootstrap-company
//
// Why this exists: creating the very *first* owner account for a brand new
// client company is a chicken-and-egg problem — normal employee creation
// (see create-employee) requires the caller to already be an owner, but for
// a fresh company there is no owner yet. This function is the one-time
// "day zero" step: it creates the company row, the owner's login, and the
// owner's profile, all in one go.
//
// Because there's no existing owner to check against, this function is
// protected by a shared secret instead (BOOTSTRAP_SECRET, set as a function
// secret in the Supabase Dashboard) rather than by checking the caller's
// role. Anyone with that secret can create a new company + owner in this
// project, so keep it private — treat it like a password.
//
// Since every client gets their own separate Supabase project (see
// supabase/migrations for the schema each fresh project needs), this
// function gets deployed once per new client project and run exactly once
// per company: to create that company's first owner account.
//
// Deploy via the Supabase Dashboard: Edge Functions -> Create a new
// function -> name it "bootstrap-company" -> paste this file's contents ->
// Deploy. Then set the BOOTSTRAP_SECRET secret (Edge Functions -> Manage
// secrets, or Project Settings -> Edge Functions).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (req: Request) => {
  try {
    const { secret, company_name, owner_email, owner_password, owner_full_name } = await req.json()

    const expectedSecret = Deno.env.get('BOOTSTRAP_SECRET')
    if (!expectedSecret || secret !== expectedSecret) {
      return jsonResponse({ error: 'Unauthorized' }, 401)
    }

    if (!company_name || !owner_email || !owner_password || !owner_full_name) {
      return jsonResponse(
        { error: 'company_name, owner_email, owner_password and owner_full_name are required' },
        400,
      )
    }
    if (typeof owner_password !== 'string' || owner_password.length < 6) {
      return jsonResponse({ error: 'owner_password must be at least 6 characters' }, 400)
    }

    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const { data: company, error: companyError } = await adminClient
      .from('companies')
      .insert({ name: company_name })
      .select()
      .single()

    if (companyError || !company) {
      return jsonResponse({ error: companyError?.message ?? 'Could not create company' }, 400)
    }

    const { data: created, error: createError } = await adminClient.auth.admin.createUser({
      email: owner_email,
      password: owner_password,
      email_confirm: true,
    })

    if (createError || !created.user) {
      // Don't leave an orphaned company behind if the owner login couldn't be created.
      await adminClient.from('companies').delete().eq('id', company.id)
      return jsonResponse({ error: createError?.message ?? 'Could not create owner user' }, 400)
    }

    const { error: insertError } = await adminClient.from('profiles').insert({
      id: created.user.id,
      company_id: company.id,
      role: 'owner',
      full_name: owner_full_name,
    })

    if (insertError) {
      await adminClient.auth.admin.deleteUser(created.user.id)
      await adminClient.from('companies').delete().eq('id', company.id)
      return jsonResponse({ error: insertError.message }, 400)
    }

    return jsonResponse({ company_id: company.id, owner_id: created.user.id }, 200)
  } catch (err) {
    return jsonResponse({ error: String(err) }, 500)
  }
})

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

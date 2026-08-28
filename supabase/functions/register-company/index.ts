// Supabase Edge Function: register-company
//
// Public self-registration: anyone can call this to create a brand new
// company and become its first owner, no approval step. (An earlier version
// of this app required an admin to manually approve every new company —
// that requirement was dropped since it just meant building throwaway
// "pending approval" plumbing for something meant to be automatic from the
// start. An admin can still delete a company/account after the fact if
// something's wrong — see the admin panel in the Flutter app.)
//
// This still needs to run with the privileged (service role) client because
// creating a *login* for the new owner requires Supabase's admin API — see
// create-employee's comment for why that can't happen directly from the app.
//
// Deploy via the Supabase Dashboard: Edge Functions -> Create a new
// function -> name it "register-company" -> paste this file's contents ->
// Deploy. No secrets needed — this one is intentionally public.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

Deno.serve(async (req: Request) => {
  try {
    const { company_name, owner_email, owner_password, owner_full_name } = await req.json()

    if (!company_name || !owner_email || !owner_password || !owner_full_name) {
      return jsonResponse(
        { error: 'company_name, owner_email, owner_password and owner_full_name are required' },
        400,
      )
    }
    if (typeof company_name !== 'string' || company_name.trim().length === 0) {
      return jsonResponse({ error: 'company_name cannot be empty' }, 400)
    }
    if (typeof owner_email !== 'string' || !EMAIL_PATTERN.test(owner_email)) {
      return jsonResponse({ error: 'owner_email is not a valid email address' }, 400)
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
      .insert({ name: company_name.trim() })
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

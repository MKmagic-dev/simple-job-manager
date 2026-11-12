// Supabase Edge Function: remove-employee
//
// An owner removes an employee: the employee's login is deleted at once (so
// they can't sign in any more), their personal data is wiped, and their
// profile stays as an empty "Konto usunięte" row so the shifts, tasks and
// files they were part of stay in the company without their name.
//
// Only an owner of the same company can call this, and only for an employee.
// Employees cannot delete their own accounts.
//
// Flow:
//   1. The caller's token identifies them; their profile must be an owner.
//   2. The target must be an employee of the same company.
//   3. With the service-role client: remove team links, wipe personal data,
//      delete the avatar file and the login.
//
// Deploy via the Supabase Dashboard: Edge Functions -> Create a new function
// -> name it "remove-employee" -> paste this file -> Deploy.

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
    const { profile_id } = await req.json()
    if (!profile_id || typeof profile_id !== 'string') {
      return jsonResponse({ error: 'profile_id is required' }, 400)
    }

    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return jsonResponse({ error: 'Missing Authorization header' }, 401)
    }

    // Caller's own session: normal RLS applies to these queries.
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

    const { data: callerProfile, error: callerError } = await callerClient
      .from('profiles')
      .select('role, company_id')
      .eq('id', caller.id)
      .single()
    if (callerError || !callerProfile || callerProfile.role !== 'owner') {
      return jsonResponse({ error: 'Only an owner can remove an employee' }, 403)
    }

    // Privileged client: bypasses RLS, used only after the checks above.
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const { data: target, error: targetError } = await adminClient
      .from('profiles')
      .select('id, role, company_id')
      .eq('id', profile_id)
      .single()
    if (targetError || !target) {
      return jsonResponse({ error: 'Employee not found' }, 404)
    }
    if (target.company_id !== callerProfile.company_id) {
      return jsonResponse({ error: 'Employee not found' }, 404)
    }
    if (target.role !== 'employee') {
      return jsonResponse({ error: 'Only an employee can be removed this way' }, 403)
    }

    // Personal links to projects, tasks and notes go; shifts and tasks stay.
    await adminClient.from('project_members').delete().eq('employee_id', profile_id)
    await adminClient.from('task_assignees').delete().eq('employee_id', profile_id)
    await adminClient.from('note_recipients').delete().eq('employee_id', profile_id)
    await adminClient.from('shift_change_requests').delete().eq('employee_id', profile_id)

    // Avatar: the bucket keeps one folder per user id.
    const { data: avatarFiles } = await adminClient.storage
      .from('avatars')
      .list(profile_id)
    if (avatarFiles && avatarFiles.length > 0) {
      await adminClient.storage
        .from('avatars')
        .remove(avatarFiles.map((file) => `${profile_id}/${file.name}`))
    }

    // Empty profile row: the name disappears, the row keeps the links.
    const { error: wipeError } = await adminClient
      .from('profiles')
      .update({
        full_name: 'Konto usunięte',
        phone: null,
        avatar_url: null,
        deleted_at: new Date().toISOString(),
      })
      .eq('id', profile_id)
    if (wipeError) {
      return jsonResponse({ error: 'Could not wipe the employee' }, 500)
    }

    // Login last, so the person can't sign in while the rest is removed.
    const { error: deleteError } = await adminClient.auth.admin.deleteUser(profile_id)
    if (deleteError) {
      return jsonResponse({ error: 'Could not delete the login' }, 500)
    }

    return jsonResponse({ ok: true }, 200)
  } catch (error) {
    return jsonResponse({ error: String(error) }, 500)
  }
})

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

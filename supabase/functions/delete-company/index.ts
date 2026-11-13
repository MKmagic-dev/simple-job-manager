// Supabase Edge Function: delete-company
//
// The owner deletes the whole company: all its data, its files and every login
// that belongs to it. This is irreversible, so it runs only after the owner
// confirmed a one-time code that was e-mailed to them (see the app).
//
// Only an owner of the company can call this. The caller is identified by
// their own token; the privileged work runs with the service-role key.
//
// Order: database (one transaction), then storage files, then the logins.
//
// Deploy via the Supabase Dashboard: Edge Functions -> Deploy a new function ->
// Via Editor -> name it "delete-company" -> paste this file -> Deploy.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Buckets whose files are stored under <companyId>/...
const companyBuckets = [
  'task-attachments',
  'shift-attachments',
  'project-attachments',
  'instruction-attachments',
]

// Buckets whose files are stored under <userId>/... (one folder per person).
const userBuckets = ['avatars', 'work-photos']

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return jsonResponse({ error: 'Missing Authorization header' }, 401)
    }

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
      return jsonResponse({ error: 'Only an owner can delete the company' }, 403)
    }

    const companyId = callerProfile.company_id as string

    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // Everyone who belongs to the company, collected before their rows go.
    const { data: people, error: peopleError } = await adminClient
      .from('profiles')
      .select('id')
      .eq('company_id', companyId)
    if (peopleError) {
      return jsonResponse({ error: 'Could not read the company' }, 500)
    }
    const personIds = (people ?? []).map((row) => row.id as string)

    // 1. Database.
    const { error: dbError } = await adminClient.rpc('delete_company_data', {
      p_company: companyId,
    })
    if (dbError) {
      return jsonResponse({ error: 'Could not delete the company data' }, 500)
    }

    // 2. Files. A failure here must not leave logins behind, so it is logged
    // and the logins are still removed.
    for (const bucket of companyBuckets) {
      await removeFolder(adminClient, bucket, companyId)
    }
    for (const bucket of userBuckets) {
      for (const personId of personIds) {
        await removeFolder(adminClient, bucket, personId)
      }
    }

    // 3. Logins, last.
    for (const personId of personIds) {
      const { error } = await adminClient.auth.admin.deleteUser(personId)
      if (error) {
        console.error('Could not delete login', personId, error.message)
      }
    }

    return jsonResponse({ ok: true }, 200)
  } catch (error) {
    return jsonResponse({ error: String(error) }, 500)
  }
})

// Removes every file under `prefix` in `bucket`, walking subfolders.
async function removeFolder(
  // deno-lint-ignore no-explicit-any
  client: any,
  bucket: string,
  prefix: string,
): Promise<void> {
  const { data, error } = await client.storage.from(bucket).list(prefix, {
    limit: 1000,
  })
  if (error || !data) {
    console.error('Could not list', bucket, prefix, error?.message)
    return
  }

  const files: string[] = []
  for (const item of data) {
    const path = `${prefix}/${item.name}`
    if (item.id === null) {
      // A folder: walk into it.
      await removeFolder(client, bucket, path)
    } else {
      files.push(path)
    }
  }

  if (files.length > 0) {
    const { error: removeError } = await client.storage.from(bucket).remove(files)
    if (removeError) {
      console.error('Could not remove files', bucket, removeError.message)
    }
  }
}

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

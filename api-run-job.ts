import { createSupabaseServerClient } from '@backend/supabaseServerClient.ts';
import { configure, tasks } from '@trigger.dev/sdk';
import type { runJob } from '@trigger/runJob';
import type { APIRoute } from 'astro';

interface EnvVars {
  publicSupabaseUrl: string;
  publicSupabaseApiKey: string;
  iiifProjectId: string;
  iiifUrl: string;
  vaultTenantPath?: string;
}

console.log('CUSTOM API RUN-JOB FILE LOADED');

configure({
  secretKey:
    process?.env.TRIGGER_SECRET_KEY || import.meta.env.TRIGGER_SECRET_KEY,
  baseURL:
    process?.env.TRIGGER_SERVER_URL || import.meta.env.TRIGGER_SERVER_URL,
});

export const POST: APIRoute = async ({ cookies, request }) => {
  console.log('================ API RUN-JOB HIT ================');

  try {
    // Verify if the user is logged in
    const supabase = await createSupabaseServerClient(request, cookies);

    if (!supabase) {
      console.error('No supabase client');

      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
      });
    }

    console.log('Supabase client created');

    // Get the user
    const userResp = await supabase.auth.getUser();

    if (userResp.error) {
      console.error('Failed to get user');
      console.error(userResp.error);

      return new Response(JSON.stringify({ error: 'Failed to get user' }), {
        status: 500,
      });
    }

    const user = userResp.data;
    const id = user.user.id;

    console.log(`User ID=${id}`);

    // Is the user an Org Admin?
    const orgAdminResp = await supabase.rpc('is_admin_organization', {
      user_id: id,
    });

    if (orgAdminResp.error) {
      console.error('Failed to get org admin response');
      console.error(orgAdminResp.error);

      return new Response(
        JSON.stringify({ error: 'Failed to get org admin response' }),
        { status: 500 }
      );
    }

    console.log(`is_admin=${orgAdminResp.data}`);

    if (!orgAdminResp.data) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
      });
    }

    const { jobId, ...rest } = await request.json();

    console.log(`jobId=${jobId}`);

    const sessionResp = await supabase.auth.getSession();

    if (sessionResp.error) {
      console.error('Failed to get session');
      console.error(sessionResp.error);

      return new Response(JSON.stringify({ error: 'Failed to get session' }), {
        status: 500,
      });
    }

    if (!sessionResp.data) {
      console.error('No session data');

      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
      });
    }

    const token = sessionResp.data.session?.access_token || '';

    console.log(`token present=${!!token}`);

    const envVars: EnvVars = {
      publicSupabaseUrl:
        process?.env.SUPABASE_SERVERCLIENT_URL ||
        import.meta.env.SUPABASE_SERVERCLIENT_URL ||
        process?.env.PUBLIC_SUPABASE ||
        import.meta.env.PUBLIC_SUPABASE,

      publicSupabaseApiKey:
        process?.env.PUBLIC_SUPABASE_API_KEY ||
        import.meta.env.PUBLIC_SUPABASE_API_KEY,

      iiifProjectId:
        process?.env.IIIF_PROJECT_ID ||
        import.meta.env.IIIF_PROJECT_ID,

      iiifUrl:
        process?.env.IIIF_URL ||
        import.meta.env.IIIF_URL,
    };

    console.log('ENV VARS');
    console.log(
      JSON.stringify(
        {
          publicSupabaseUrl: envVars.publicSupabaseUrl,
          publicSupabaseApiKeyPresent: !!envVars.publicSupabaseApiKey,
          iiifProjectId: envVars.iiifProjectId,
          iiifUrl: envVars.iiifUrl,
        },
        null,
        2
      )
    );

    const OP_VAULT_NAME =
      process?.env.OP_VAULT_NAME ||
      import.meta.env.OP_VAULT_NAME;

    const OP_ITEM_NAME =
      process?.env.OP_ITEM_NAME ||
      import.meta.env.OP_ITEM_NAME;

    if (OP_VAULT_NAME && OP_ITEM_NAME) {
      envVars['vaultTenantPath'] =
        `${OP_VAULT_NAME}/${OP_ITEM_NAME}`;
    }

    console.log('TRIGGER CONFIG');
    console.log({
      triggerSecretKeyPresent: !!(
        process?.env.TRIGGER_SECRET_KEY ||
        import.meta.env.TRIGGER_SECRET_KEY
      ),

      triggerServerUrl:
        process?.env.TRIGGER_SERVER_URL ||
        import.meta.env.TRIGGER_SERVER_URL,

      triggerProjectId:
        process?.env.TRIGGER_PROJECT_ID ||
        import.meta.env.TRIGGER_PROJECT_ID,
    });

    console.log('TRIGGER PAYLOAD');
    console.log(
      JSON.stringify(
        {
          jobId,
          tokenPresent: !!token,
          ...envVars,
          ...rest,
        },
        null,
        2
      )
    );

    const handle = await tasks.trigger<typeof runJob>('run-job', {
      jobId,
      token,
      ...envVars,
      ...rest,
    });

    console.log('TRIGGER HANDLE');
    console.log(handle);

    if (handle) {
      console.log(`Run created: ${handle.id}`);

      return new Response(
        JSON.stringify({
          message: `Job is running with handle: ${handle.id}`,
        }),
        {
          status: 200,
          headers: {
            'Content-Type': 'application/json',
          },
        }
      );
    }

    console.error('Trigger returned null handle');

    return new Response(
      JSON.stringify({
        message: 'Failed to execute job',
      }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (error) {
    console.error('TRIGGER ERROR');
    console.error(error);

    return new Response(
      JSON.stringify({
        error: String(error),
      }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
        },
      }
    );
  }
};
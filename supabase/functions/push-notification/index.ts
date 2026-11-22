import { createClient } from 'npm:@supabase/supabase-js@2';
import { JWT } from 'npm:google-auth-library@9.15.1';

type RecordPayload = Record<string, unknown>;

type RuntimeConfig = {
  supabaseUrl: string;
  supabaseKey: string;
  webhookSecret: string;
  serviceAccount: Record<string, unknown>;
  projectId: string;
};

type DeliveryFailure = {
  httpStatus: number | null;
  code: string;
  details: string[];
};

function runtimeConfig(): { config?: RuntimeConfig; missing?: string[]; error?: string } {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')?.trim();
  const webhookSecret = Deno.env.get('PUSH_WEBHOOK_SECRET')?.trim();
  const serviceAccountRaw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');

  // Prefer Supabase's current named secret-key environment and retain the
  // legacy service-role variable as a compatibility fallback.
  let supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')?.trim();
  if (!supabaseKey) {
    const secretKeysRaw = Deno.env.get('SUPABASE_SECRET_KEYS');
    if (secretKeysRaw) {
      try {
        const keys = JSON.parse(secretKeysRaw) as Record<string, unknown>;
        const defaultKey = keys.default;
        if (typeof defaultKey === 'string') supabaseKey = defaultKey.trim();
      } catch {
        return { error: 'SUPABASE_SECRET_KEYS is not valid JSON.' };
      }
    }
  }

  const missing = [
    ...(!supabaseUrl ? ['SUPABASE_URL'] : []),
    ...(!supabaseKey ? ['SUPABASE_SERVICE_ROLE_KEY or SUPABASE_SECRET_KEYS.default'] : []),
    ...(!webhookSecret ? ['PUSH_WEBHOOK_SECRET'] : []),
    ...(!serviceAccountRaw ? ['FIREBASE_SERVICE_ACCOUNT'] : []),
  ];
  if (missing.length > 0) return { missing };

  let serviceAccount: Record<string, unknown>;
  try {
    const parsed: unknown = JSON.parse(serviceAccountRaw!);
    if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
      return { error: 'FIREBASE_SERVICE_ACCOUNT must contain a JSON object.' };
    }
    serviceAccount = parsed as Record<string, unknown>;
  } catch {
    return { error: 'FIREBASE_SERVICE_ACCOUNT is not valid JSON.' };
  }

  const email = serviceAccount.client_email;
  const privateKey = serviceAccount.private_key;
  const projectId = Deno.env.get('FCM_PROJECT_ID')?.trim() ||
    (typeof serviceAccount.project_id === 'string' ? serviceAccount.project_id.trim() : '');
  const invalid = [
    ...(typeof email !== 'string' || !email.trim() ? ['client_email'] : []),
    ...(typeof privateKey !== 'string' || !privateKey.trim() ? ['private_key'] : []),
    ...(!projectId ? ['FCM_PROJECT_ID or service-account project_id'] : []),
  ];
  if (invalid.length > 0) {
    return { error: `Firebase service-account configuration is missing: ${invalid.join(', ')}.` };
  }

  return {
    config: {
      supabaseUrl: supabaseUrl!,
      supabaseKey: supabaseKey!,
      webhookSecret: webhookSecret!,
      serviceAccount,
      projectId,
    },
  };
}

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8' },
  });
}

function fcmFailureDetails(responseBody: string): { code: string; details: string[] } {
  try {
    const payload = JSON.parse(responseBody);
    const error = payload?.error;
    const details = Array.isArray(error?.details)
      ? error.details
          .map((item: Record<string, unknown>) => item.errorCode ?? item.reason ?? item['@type'])
          .filter((value: unknown): value is string => typeof value === 'string')
          .slice(0, 5)
      : [];
    return {
      code: typeof error?.status === 'string' ? error.status : 'FCM_ERROR',
      details,
    };
  } catch {
    return { code: 'INVALID_FCM_ERROR_RESPONSE', details: [] };
  }
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 });

  const configResult = runtimeConfig();
  if (!configResult.config) {
    if (configResult.missing) {
      console.error('Push function configuration is missing required environment variables.', {
        missing: configResult.missing,
      });
      return jsonResponse({ error: 'Push function is not configured.' }, 503);
    }
    console.error('Push function configuration is invalid.', { error: configResult.error });
    return jsonResponse({ error: 'Push function configuration is invalid.' }, 503);
  }
  const config = configResult.config;

  const providedSecret = request.headers.get('x-klubb-webhook-secret');
  if (!providedSecret || providedSecret !== config.webhookSecret) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  try {
    const webhook: unknown = await request.json();
    if (webhook === null || typeof webhook !== 'object' || Array.isArray(webhook)) {
      return jsonResponse({ error: 'Webhook payload must be a JSON object.' }, 400);
    }
    const payload = webhook as Record<string, unknown>;
    const table = typeof payload.table === 'string' ? payload.table : '';
    const record = payload.record;
    if (payload.type !== 'INSERT' || !['announcements', 'club_events', 'club_chat_messages'].includes(table)) {
      return jsonResponse({ ignored: true });
    }
    if (payload.schema !== undefined && payload.schema !== 'public') {
      return jsonResponse({ error: 'Webhook schema is not supported.' }, 400);
    }
    if (record === null || typeof record !== 'object' || Array.isArray(record)) {
      return jsonResponse({ error: 'Webhook record must be an object.' }, 400);
    }
    const row = record as RecordPayload;

    const clubId = String(row.club_id ?? '');
    if (!clubId) return jsonResponse({ error: 'Missing club_id' }, 400);

    const supabase = createClient(config.supabaseUrl, config.supabaseKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: club, error: clubError } = await supabase
      .from('clubs')
      .select('name')
      .eq('id', clubId)
      .maybeSingle();
    if (clubError) throw clubError;
    const clubName = club?.name ?? 'your club';
    const senderId = String(table === 'club_chat_messages' ? row.sender_id ?? '' : row.created_by ?? '');

    let title: string;
    let body: string;
    let kind: string;
    if (table === 'announcements') {
      kind = 'announcement';
      title = `New announcement in ${clubName}`;
      body = String(row.title ?? 'A new announcement was posted.');
    } else if (table === 'club_events') {
      kind = 'event';
      title = `New event in ${clubName}`;
      body = String(row.title ?? 'A new event was created.');
    } else {
      kind = 'chat_message';
      title = `New message in ${clubName}`;
      body = String(row.message ?? 'A new message was posted.')
        .replace(/\s+/g, ' ')
        .slice(0, 180);
    }

    const { data: members, error: memberError } = await supabase
      .from('club_members')
      .select('user_id, role')
      .eq('club_id', clubId);
    if (memberError) throw memberError;

    const executivesOnly = row.visibility === 'executives';
    const executiveRoles = new Set(['owner', 'admin', 'executive', 'president', 'vice_president']);
    const eligibleRecipientIds = (members ?? [])
      .filter((member) => member.user_id !== senderId)
      .filter((member) => !executivesOnly || executiveRoles.has(String(member.role ?? 'member').toLowerCase()))
      .map((member) => String(member.user_id));
    if (eligibleRecipientIds.length === 0) return jsonResponse({ sent: 0, failed: 0, recipients: 0 });

    const { data: mutedPreferences, error: preferenceError } = await supabase
      .from('club_notification_preferences')
      .select('user_id')
      .eq('club_id', clubId)
      .eq('muted', true)
      .in('user_id', eligibleRecipientIds);
    if (preferenceError) throw preferenceError;
    const mutedUserIds = new Set((mutedPreferences ?? []).map((item) => String(item.user_id)));
    const recipientIds = eligibleRecipientIds.filter((userId) => !mutedUserIds.has(userId));
    if (recipientIds.length === 0) {
      return jsonResponse({ sent: 0, failed: 0, recipients: 0, devices: 0 });
    }

    const { data: devices, error: deviceError } = await supabase
      .from('device_push_tokens')
      .select('token')
      .in('user_id', recipientIds);
    if (deviceError) throw deviceError;
    if (!devices?.length) {
      return jsonResponse({ sent: 0, failed: 0, recipients: recipientIds.length, devices: 0 });
    }

    const serviceAccount = config.serviceAccount;
    const email = serviceAccount.client_email as string;
    const privateKey = (serviceAccount.private_key as string).replace(/\\n/g, '\n');
    const googleAuth = new JWT({
      email,
      key: privateKey,
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    });
    const { token: accessToken } = await googleAuth.getAccessToken();
    if (!accessToken) throw new Error('Google OAuth did not return an access token.');

    let sent = 0;
    let failed = 0;
    const failures: DeliveryFailure[] = [];
    await Promise.all(devices.map(async ({ token: installationId }) => {
      try {
        const response = await fetch(
          `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(config.projectId)}/messages:send`,
          {
            method: 'POST',
            headers: {
              authorization: `Bearer ${accessToken}`,
              'content-type': 'application/json',
            },
            body: JSON.stringify({
              message: {
                fid: installationId,
                notification: { title, body },
                data: { kind, club_id: clubId },
                android: { priority: 'HIGH', notification: { channel_id: 'klubb_updates' } },
                apns: { payload: { aps: { sound: 'default' } } },
              },
            }),
          },
        );
        if (response.ok) {
          sent += 1;
          return;
        }

        const responseBody = await response.text();
        const failure = fcmFailureDetails(responseBody);
        failed += 1;
        if (failures.length < 20) failures.push({ httpStatus: response.status, ...failure });
        console.error('FCM notification delivery failed.', {
          httpStatus: response.status,
          fcmCode: failure.code,
          details: failure.details,
        });
        if (failure.details.includes('UNREGISTERED')) {
          try {
            const { error: deleteError } = await supabase
              .from('device_push_tokens')
              .delete()
              .eq('token', installationId);
            if (deleteError) console.error('Could not remove unregistered FID.', deleteError.message);
          } catch (error) {
            console.error('Could not remove unregistered FID.', {
              error: error instanceof Error ? error.message : String(error),
            });
          }
        }
      } catch (error) {
        failed += 1;
        if (failures.length < 20) {
          failures.push({ httpStatus: null, code: 'NETWORK_OR_SEND_ERROR', details: [] });
        }
        console.error('FCM notification request failed before a response was received.', {
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }));

    const summary = {
      sent,
      failed,
      recipients: recipientIds.length,
      devices: devices.length,
      failureSamples: failures,
    };
    if (failed === devices.length) {
      return jsonResponse({ error: 'All FCM deliveries failed.', ...summary }, 502);
    }
    if (failed > 0) {
      return jsonResponse({ error: 'Some FCM deliveries failed.', ...summary }, 502);
    }
    return jsonResponse(summary);
  } catch (error) {
    console.error('Push webhook processing failed.', {
      error: error instanceof Error ? error.message : String(error),
    });
    return jsonResponse({ error: 'Push webhook processing failed.' }, 500);
  }
});

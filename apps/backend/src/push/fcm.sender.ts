import { createSign } from 'node:crypto';

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const TOKEN_URL = 'https://oauth2.googleapis.com/token';

const b64 = (v: object) => Buffer.from(JSON.stringify(v)).toString('base64url');

/** Minimal Firebase Cloud Messaging (HTTP v1) client: signs its own service-account JWT, no SDK needed. */
export class FcmSender {
  private readonly account: ServiceAccount;
  private cached: { token: string; expiresAt: number } | null = null;

  constructor(serviceAccountJson: string) {
    const parsed = JSON.parse(serviceAccountJson) as Partial<ServiceAccount>;
    if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
      throw new Error('FCM_SERVICE_ACCOUNT_JSON must contain project_id, client_email and private_key.');
    }
    this.account = parsed as ServiceAccount;
  }

  private async accessToken(): Promise<string> {
    const now = Math.floor(Date.now() / 1000);
    if (this.cached && this.cached.expiresAt - 60 > now) return this.cached.token;

    const unsigned = `${b64({ alg: 'RS256', typ: 'JWT' })}.${b64({
      iss: this.account.client_email,
      scope: SCOPE,
      aud: TOKEN_URL,
      iat: now,
      exp: now + 3600,
    })}`;
    const signature = createSign('RSA-SHA256').update(unsigned).sign(this.account.private_key).toString('base64url');

    const res = await fetch(TOKEN_URL, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: `${unsigned}.${signature}`,
      }),
      signal: AbortSignal.timeout(8000),
    });
    if (!res.ok) throw new Error(`Google token endpoint answered ${res.status}`);
    const body = (await res.json()) as { access_token: string; expires_in: number };
    this.cached = { token: body.access_token, expiresAt: now + body.expires_in };
    return body.access_token;
  }

  /** Returns false when FCM says the token is dead (the caller should delete it). */
  async send(token: string, title: string): Promise<boolean> {
    const res = await fetch(`https://fcm.googleapis.com/v1/projects/${this.account.project_id}/messages:send`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${await this.accessToken()}` },
      body: JSON.stringify({ message: { token, notification: { title } } }),
      signal: AbortSignal.timeout(8000),
    });
    if (res.status === 404 || res.status === 400) return false;
    if (!res.ok) throw new Error(`FCM answered ${res.status}`);
    return true;
  }
}

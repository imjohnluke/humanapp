import { AppStoreServerAPIClient, Environment, SignedDataVerifier } from 'npm:@apple/app-store-server-library@3.1.0';
import { Buffer } from 'node:buffer';
import { rootCertificates } from './roots.ts';
import { appID, bundleID, validateTransaction, accessExpiry } from './policy.ts';

const url = Deno.env.get('SUPABASE_URL') ?? '';
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const headers = { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, 'Content-Type': 'application/json' };
export const billingConfigured = () => Boolean(Deno.env.get('APPLE_IAP_PRIVATE_KEY') && Deno.env.get('APPLE_IAP_KEY_ID') && Deno.env.get('APPLE_IAP_ISSUER_ID'));
export const purchasesAvailable = () => billingConfigured() && Boolean(Deno.env.get('OPENAI_API_KEY')) && Deno.env.get('APPLE_BILLING_ENABLED') === 'true';
export function json(value: unknown, status = 200) { return Response.json(value, { status, headers: { 'Cache-Control': 'no-store' } }); }
export async function db(path: string, body?: unknown) {
  const response = await fetch(`${url}/rest/v1/${path}`, { method: body === undefined ? 'GET' : 'POST', headers,
    body: body === undefined ? undefined : JSON.stringify(body), signal: AbortSignal.timeout(10000) });
  if (!response.ok) throw new Error('database_unavailable');
  return response.json();
}
export async function authenticatedUser(request: Request): Promise<string | null> {
  const bearer = request.headers.get('Authorization') ?? '';
  if (!/^Bearer \S+$/.test(bearer)) return null;
  const response = await fetch(`${url}/auth/v1/user`, { headers: { apikey: serviceKey, Authorization: bearer }, signal: AbortSignal.timeout(10000) });
  if (!response.ok) return null;
  const user = await response.json();
  return typeof user.id === 'string' ? user.id : null;
}
export async function access(user: string) {
  const rows = await db(`pro_access?user_id=eq.${encodeURIComponent(user)}&select=expires_at`);
  const expiry = rows[0]?.expires_at ?? null;
  return { is_pro: Boolean(expiry && Date.parse(expiry) > Date.now()), expires_at: expiry, purchases_available: purchasesAvailable() };
}
function verifier(environment: Environment) {
  return new SignedDataVerifier(rootCertificates.map(c => Buffer.from(c, 'base64')), true, environment, bundleID, appID);
}
async function verified(payload: string, kind: 'transaction' | 'notification') {
  for (const environment of [Environment.PRODUCTION, Environment.SANDBOX]) {
    try {
      const v = verifier(environment);
      const decoded = kind === 'transaction' ? await v.verifyAndDecodeTransaction(payload) : await v.verifyAndDecodeNotification(payload);
      return { decoded, environment, verifier: v };
    } catch { /* Try the other Apple-signed environment; never accept local StoreKit signatures. */ }
  }
  throw new Error('invalid_signature');
}
export async function notificationTransaction(payload: string): Promise<string | null> {
  const { decoded } = await verified(payload, 'notification');
  const notification = decoded as { notificationType?: string; data?: { signedTransactionInfo?: string } };
  if (notification.notificationType === 'TEST') return null;
  return notification.data?.signedTransactionInfo ?? null;
}
export async function reconcile(signedTransaction: string, expectedUser?: string) {
  if (!billingConfigured()) throw new Error('billing_unavailable');
  const verifiedInput = await verified(signedTransaction, 'transaction');
  const initial = verifiedInput.decoded as import('./policy.ts').TransactionData;
  const user = validateTransaction(initial, expectedUser);
  if (verifiedInput.environment === Environment.SANDBOX) {
    const testers = await db(`apple_sandbox_testers?user_id=eq.${encodeURIComponent(user)}&select=expires_at`);
    if (!testers.some((t: { expires_at: string }) => Date.parse(t.expires_at) > Date.now())) throw new Error('sandbox_not_enabled');
  }
  const client = new AppStoreServerAPIClient(Deno.env.get('APPLE_IAP_PRIVATE_KEY')!.replace(/\\n/g, '\n'),
    Deno.env.get('APPLE_IAP_KEY_ID')!, Deno.env.get('APPLE_IAP_ISSUER_ID')!, bundleID, verifiedInput.environment);
  // Fetch current status from Apple instead of granting access from a replayable old transaction.
  const latest = await client.getAllSubscriptionStatuses(initial.originalTransactionId!);
  if (latest.bundleId !== bundleID) throw new Error('invalid_transaction');
  let found = false;
  for (const group of latest.data ?? []) for (const item of group.lastTransactions ?? []) {
    if (item.originalTransactionId !== initial.originalTransactionId || !item.signedTransactionInfo) continue;
    const t = await verifiedInput.verifier.verifyAndDecodeTransaction(item.signedTransactionInfo);
    validateTransaction(t, user);
    if (t.originalTransactionId !== initial.originalTransactionId) throw new Error('invalid_transaction');
    const renewal = item.signedRenewalInfo ? await verifiedInput.verifier.verifyAndDecodeRenewalInfo(item.signedRenewalInfo) : undefined;
    if (renewal && renewal.originalTransactionId !== t.originalTransactionId) throw new Error('invalid_transaction');
    await db('rpc/record_apple_subscription', {
      p_original_id: t.originalTransactionId, p_environment: verifiedInput.environment, p_user_id: user, p_product_id: t.productId,
      p_expires_at: new Date(accessExpiry(t, item.status ?? 0, renewal?.gracePeriodExpiresDate)).toISOString(),
      p_signed_at: new Date(Math.max(t.signedDate!, renewal?.signedDate ?? 0)).toISOString(),
    });
    found = true;
  }
  if (!found) throw new Error('subscription_not_found');
  return access(user);
}
export async function smallJSON(request: Request) {
  if (!request.body) throw new Error('invalid_body');
  const reader = request.body.getReader(); const chunks: Uint8Array[] = []; let size = 0;
  while (true) { const { done, value } = await reader.read(); if (done) break;
    size += value.length; if (size > 65536) { await reader.cancel(); throw new Error('invalid_body'); } chunks.push(value); }
  const bytes = new Uint8Array(size); let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  return JSON.parse(new TextDecoder().decode(bytes));
}

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHandler, validateEstimate } from './handler.ts';

const id = '11111111-1111-4111-8111-111111111111';
const config = { supabaseURL: 'https://test.supabase.co', serviceKey: 'server-secret', openaiKey: 'openai-secret', model: 'test-model' };
const estimate = { can_estimate: true, amount_ml: 250, capacity_ml: 500, confidence: 'medium', container: 'Glass', explanation: 'Visible half-full glass; scale is approximate.' };
const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
function request(method = 'POST', body: Uint8Array = jpeg) {
  return new Request('https://example.com', { method, headers: { Authorization: 'Bearer user-token', 'Content-Type': 'image/jpeg' }, body: method === 'POST' ? body : undefined });
}
function setup(options: { pro?: boolean; authStatus?: number; quota?: boolean; modelOutput?: unknown; modelStatus?: string; refusal?: boolean; openaiStatus?: number; providerCode?: string; accessStatus?: number } = {}) {
  const calls: { url: string; init?: RequestInit }[] = [];
  const fetcher = async (url: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(url), init });
    const path = String(url);
    if (path.endsWith('/user')) return Response.json({ id, user_metadata: { is_pro: true } }, { status: options.authStatus ?? 200 });
    if (path.includes('pro_access')) return Response.json(options.pro === false ? [] : [{ expires_at: '2099-01-01T00:00:00Z' }], { status: options.accessStatus ?? 200 });
    if (path.includes('reserve_photo_estimate')) return Response.json(options.quota ?? true);
    assert.equal(path, 'https://api.openai.com/v1/responses');
    if (options.providerCode) return Response.json({ error: { code: options.providerCode, message: 'private provider details' } }, { status: options.openaiStatus ?? 429 });
    return Response.json({ status: options.modelStatus ?? 'completed', output: [{ content: options.refusal ? [{ type: 'refusal', refusal: 'no' }] : [{ type: 'output_text', text: JSON.stringify(options.modelOutput ?? estimate) }] }] }, { status: options.openaiStatus ?? 200 });
  };
  return { calls, handler: createHandler(config, fetcher as typeof fetch) };
}
test('success uses authenticated user, server key and image input; does not store response', async () => {
  const { handler, calls } = setup();
  const result = await handler(request());
  assert.equal(result.status, 200); assert.deepEqual(await result.json(), estimate);
  assert.equal(calls.length, 4);
  const payload = JSON.parse(calls[3].init!.body as string);
  assert.equal(payload.store, false); assert.equal(payload.text.format.strict, true);
  assert.match(payload.input[0].content[1].image_url, /^data:image\/jpeg;base64,/);
  assert.equal(JSON.parse(calls[2].init!.body as string).p_user_id, id);
});
test('access check never sends a photo to OpenAI or spends quota', async () => {
  const { handler, calls } = setup(); const result = await handler(request('GET'));
  assert.deepEqual(await result.json(), { is_pro: true, available: true }); assert.equal(calls.length, 2);
});
test('missing bearer, invalid auth and non-Pro are rejected before AI', async () => {
  const missing = setup(); assert.equal((await missing.handler(new Request('https://example.com'))).status, 401); assert.equal(missing.calls.length, 0);
  for (const [options, status, count] of [[{ authStatus: 401 }, 401, 1], [{ pro: false }, 403, 2], [{ quota: false }, 429, 3], [{ accessStatus: 500 }, 503, 2]] as const) {
    const { handler, calls } = setup(options); assert.equal((await handler(request())).status, status); assert.equal(calls.length, count);
  }
});
test('rejects invalid, oversized and non-JPEG input before quota', async () => {
  for (const bytes of [new Uint8Array([1, 2, 3, 4]), new Uint8Array(2 * 1024 * 1024 + 1)]) {
    const { handler, calls } = setup(); assert.equal((await handler(request('POST', bytes))).status, 400); assert.equal(calls.length, 2);
  }
  const { handler } = setup(); const bad = request(); bad.headers.set('Content-Type', 'application/json');
  assert.equal((await handler(bad)).status, 415);
});
test('unavailable key fails closed', async () => {
  const handler = createHandler({ ...config, openaiKey: '' }, async url => String(url).endsWith('/user') ? Response.json({ id }) : Response.json([{ expires_at: '2099-01-01' }]));
  assert.equal((await handler(request())).status, 503);
});
test('refusals, incomplete outputs and impossible amounts never become logs', async () => {
  for (const options of [
    { refusal: true }, { modelStatus: 'incomplete' },
    { modelOutput: { ...estimate, amount_ml: 9000 } },
    { modelOutput: { ...estimate, amount_ml: 600 } },
    { modelOutput: { ...estimate, amount_ml: -10 } },
    { modelOutput: { ...estimate, can_estimate: false, amount_ml: null, capacity_ml: null } },
  ]) assert.equal((await setup(options).handler(request())).status, 422);
  assert.equal((await setup({ openaiStatus: 429 }).handler(request())).status, 502);
});
test('network failure returns a generic error without secret/provider details', async () => {
  const result = await createHandler(config, async () => { throw new Error('secret'); })(request());
  assert.equal(result.status, 503); assert.doesNotMatch(await result.text(), /secret/);
});
test('validates confidence and bounds independently of the model schema', () => {
  assert.equal(validateEstimate(estimate), true);
  for (const change of [{ amount_ml: 1 }, { amount_ml: 250.5 }, { confidence: 'certain' }, { explanation: '' }, { capacity_ml: 8000 }]) {
    assert.equal(validateEstimate({ ...estimate, ...change }), false);
  }
});

test('provider billing errors are distinguished without disclosing provider messages', async () => {
  const result = await setup({ providerCode: 'insufficient_quota' }).handler(request());
  assert.equal(result.status, 502);
  assert.deepEqual(await result.json(), { error: 'provider_quota' });
  const rate = await setup({ openaiStatus: 429 }).handler(request());
  assert.deepEqual(await rate.json(), { error: 'provider_rate_limit' });
});

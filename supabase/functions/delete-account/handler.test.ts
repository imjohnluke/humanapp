import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHandler } from './handler.ts';

const id = '11111111-1111-4111-8111-111111111111';
const config = { supabaseURL: 'https://test.supabase.co', serviceKey: 'server-secret' };
function request(method = 'POST', authorization = 'Bearer user-token') {
  return new Request('https://example.com', { method, headers: authorization ? { Authorization: authorization } : {} });
}
function setup(options: { authStatus?: number; deleteStatus?: number; userId?: unknown } = {}) {
  const calls: { url: string; init?: RequestInit }[] = [];
  const fetcher = async (url: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(url), init });
    const path = String(url);
    if (path.endsWith('/user')) return Response.json({ id: options.userId ?? id }, { status: options.authStatus ?? 200 });
    assert.equal(path, `https://test.supabase.co/auth/v1/admin/users/${id}`);
    assert.equal(init?.method, 'DELETE');
    const body = JSON.parse(String(init?.body ?? '{}'));
    assert.equal(body.should_soft_delete, false);
    return new Response('{}', { status: options.deleteStatus ?? 200 });
  };
  return { calls, handler: createHandler(config, fetcher as typeof fetch) };
}

test('deletes the authenticated user with the service role and never trusts a request body', async () => {
  const { handler, calls } = setup();
  const result = await handler(request());
  assert.equal(result.status, 200);
  assert.deepEqual(await result.json(), { deleted: true });
  assert.equal(calls.length, 2);
  assert.match(String(calls[0].init?.headers && (calls[0].init.headers as Record<string, string>).Authorization), /^Bearer user-token$/);
  assert.equal((calls[1].init?.headers as Record<string, string>).Authorization, 'Bearer server-secret');
});

test('rejects missing bearer, invalid auth, and missing server configuration before any delete', async () => {
  const missing = setup();
  assert.equal((await missing.handler(request('POST', ''))).status, 401);
  assert.equal(missing.calls.length, 0);
  const unauthorized = setup({ authStatus: 401 });
  assert.equal((await unauthorized.handler(request())).status, 401);
  assert.equal(unauthorized.calls.length, 1);
  const invalidUser = setup({ userId: 'not-a-user' });
  assert.equal((await invalidUser.handler(request())).status, 401);
  assert.equal(invalidUser.calls.length, 1);
  const unavailable = createHandler({ supabaseURL: '', serviceKey: '' }, async () => { throw new Error('secret'); });
  assert.equal((await unavailable(request())).status, 503);
});

test('does not pretend deletion succeeded when Auth or Admin is unavailable', async () => {
  const authDown = setup({ authStatus: 500 });
  assert.equal((await authDown.handler(request())).status, 503);
  assert.equal(authDown.calls.length, 1);
  const deleteDown = setup({ deleteStatus: 500 });
  assert.equal((await deleteDown.handler(request())).status, 503);
  assert.equal(deleteDown.calls.length, 2);
  const crashed = createHandler(config, async () => { throw new Error('secret'); });
  const result = await crashed(request());
  assert.equal(result.status, 503);
  assert.doesNotMatch(await result.text(), /secret/);
});

test('only accepts POST', async () => {
  const { handler, calls } = setup();
  assert.equal((await handler(request('GET'))).status, 405);
  assert.equal((await handler(request('DELETE'))).status, 405);
  assert.equal(calls.length, 0);
});

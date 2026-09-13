import { access, authenticatedUser, json, reconcile, smallJSON } from '../_shared/apple/service.ts';
Deno.serve(async request => {
  if (!['GET', 'POST'].includes(request.method)) return json({ error: 'method_not_allowed' }, 405);
  try {
    const user = await authenticatedUser(request);
    if (!user) return json({ error: 'sign_in_required' }, 401);
    if (request.method === 'GET') return json(await access(user));
    const body = await smallJSON(request);
    if (typeof body.signed_transaction !== 'string') return json({ error: 'invalid_transaction' }, 400);
    return json(await reconcile(body.signed_transaction, user));
  } catch (error) {
    const invalid = error instanceof Error && ['invalid_signature', 'invalid_transaction', 'sandbox_not_enabled', 'invalid_body'].includes(error.message);
    return json({ error: invalid ? 'invalid_transaction' : 'billing_unavailable' }, invalid ? 400 : 503);
  }
});

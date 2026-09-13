import { json, notificationTransaction, reconcile, smallJSON } from '../_shared/apple/service.ts';
Deno.serve(async request => {
  if (request.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  try {
    const body = await smallJSON(request);
    if (typeof body.signedPayload !== 'string') return json({ error: 'invalid_notification' }, 400);
    const transaction = await notificationTransaction(body.signedPayload);
    if (transaction) await reconcile(transaction);
    return json({ received: true });
  } catch (error) {
    const invalid = error instanceof Error && ['invalid_signature', 'invalid_transaction', 'invalid_body'].includes(error.message);
    // Retryable failures return non-2xx so Apple retries delivery.
    return json({ error: invalid ? 'invalid_notification' : 'retry_later' }, invalid ? 400 : 503);
  }
});

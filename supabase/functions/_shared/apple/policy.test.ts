import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateTransaction, accessExpiry } from './policy.ts';
const user = '11111111-1111-4111-8111-111111111111';
const transaction = {
  appAccountToken: user, productId: 'com.humanhydration.pro.monthly', bundleId: 'com.humanhydration.app',
  environment: 'Production', originalTransactionId: '123', expiresDate: 2000000000000, signedDate: 1900000000000,
  type: 'Auto-Renewable Subscription',
};
test('verified transaction policy binds exact product, app and account', () => {
  assert.equal(validateTransaction(transaction, user), user);
  for (const override of [
    { appAccountToken: undefined }, { appAccountToken: '22222222-2222-4222-8222-222222222222' },
    { productId: 'unrelated' }, { bundleId: 'other.app' }, { environment: 'Xcode' },
    { type: 'Consumable' }, { signedDate: undefined },
  ]) assert.throws(() => validateTransaction({ ...transaction, ...override }, user));
});
test('active, grace, expiration, billing retry, revocation and upgrades', () => {
  assert.equal(accessExpiry(transaction, 1), transaction.expiresDate);
  assert.equal(accessExpiry(transaction, 4, 2100000000000), 2100000000000);
  for (const status of [2, 3, 5, 999]) assert.equal(accessExpiry(transaction, status), 0);
  assert.equal(accessExpiry(transaction, 4), 0);
  assert.equal(accessExpiry({ ...transaction, revocationDate: 1900000000001 }, 1), 0);
  assert.equal(accessExpiry({ ...transaction, isUpgraded: true }, 1), 0);
});

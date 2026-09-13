export const productIDs = ['com.humanhydration.pro.monthly', 'com.humanhydration.pro.yearly'];
export const bundleID = 'com.humanhydration.app';
export const appID = 6811384072;
export type TransactionData = {
  originalTransactionId?: string; appAccountToken?: string; productId?: string;
  bundleId?: string; environment?: string; expiresDate?: number; signedDate?: number;
  revocationDate?: number; isUpgraded?: boolean; type?: string;
};
export function validateTransaction(t: TransactionData, expectedUser?: string): string {
  if (!t.appAccountToken || !/^[0-9a-f-]{36}$/i.test(t.appAccountToken) ||
      (expectedUser && t.appAccountToken.toLowerCase() !== expectedUser.toLowerCase()) ||
      !t.originalTransactionId || !t.productId || !productIDs.includes(t.productId) ||
      t.bundleId !== bundleID || t.type !== 'Auto-Renewable Subscription' ||
      !['Production', 'Sandbox'].includes(t.environment ?? '') || !Number.isFinite(t.signedDate)) {
    throw new Error('invalid_transaction');
  }
  return t.appAccountToken.toLowerCase();
}
export function accessExpiry(t: TransactionData, status: number, grace?: number): number {
  if (t.revocationDate || t.isUpgraded || ![1, 4].includes(status)) return 0;
  const expiry = status === 4 ? grace : t.expiresDate;
  if (!Number.isFinite(expiry) || expiry! <= 0) return 0;
  return expiry!;
}

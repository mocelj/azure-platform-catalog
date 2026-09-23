import test from 'node:test';
import assert from 'node:assert/strict';
import { assertModuleGraph, assertPlanBinding, fetchConsumer, summarizeTerraformPlan, summarizeWhatIf, validateDispatch } from '../scripts/trust.mjs';

const sha = 'a'.repeat(40);
const dispatch = { repository: 'mocelj/azure-platform-catalog', ref: 'refs/heads/main', actor: 'mocelj', operation: 'plan', target: 'storage-bicep', consumerSha: sha, enabled: 'true' };
test('dispatch fails closed for forks, branches, actors, malformed hashes and destroy', () => {
  assert.equal(validateDispatch(dispatch), true);
  assert.equal(validateDispatch({ ...dispatch, enabled: 'false' }), false);
  for (const override of [{ repository: 'attacker/repo' }, { ref: 'refs/pull/1/merge' }, { actor: 'other' }, { operation: 'destroy' }, { consumerSha: 'main' }, { target: '../../vm' }, { operation: 'apply', planId: '../path' }]) {
    assert.throws(() => validateDispatch({ ...dispatch, ...override }));
  }
});
test('consumer content is data only and must be a merged main ancestor', async () => {
  const config = { schemaVersion: '1.0', platformApp: 'storage', name: 'ledger', environment: 'demo', size: 'small' };
  const responses = [{ default_branch: 'main' }, { status: 'ahead' }, { type: 'file', encoding: 'base64', size: 200, content: Buffer.from(JSON.stringify(config)).toString('base64') }];
  const fetcher = async () => ({ ok: true, json: async () => responses.shift() });
  assert.deepEqual(await fetchConsumer(sha, 'storage-bicep', null, fetcher), config);
  let index = 0;
  await assert.rejects(fetchConsumer(sha, 'storage-bicep', null, async () => ({ ok: true, json: async () => ++index === 1 ? { default_branch: 'main' } : { status: 'diverged' } })), /not an ancestor/);
});
test('cloud summaries refuse destructive/incomplete results without publishing resource values', () => {
  assert.deepEqual(summarizeTerraformPlan({ resource_changes: [{ change: { actions: ['create'], after: { password: 'synthetic-secret' } } }] }), { create: 1 });
  assert.throws(() => summarizeTerraformPlan({ resource_changes: [{ change: { actions: ['delete', 'create'] } }] }));
  assert.throws(() => summarizeTerraformPlan({ complete: false }));
  assert.deepEqual(summarizeWhatIf({ status: 'Succeeded', changes: [{ changeType: 'Modify', resourceId: 'synthetic-sensitive' }] }), { Modify: 1 });
  for (const changeType of ['Delete', 'Ignore', 'Unsupported']) assert.throws(() => summarizeWhatIf({ changes: [{ changeType }] }));
});
test('saved plans bind config, environment, catalog and consumer, with finite expiry', () => {
  const binding = { target: 'vm-terraform', configHash: '1', environmentHash: '2', toolchainHash: '3', catalogSha: sha, consumerSha: sha };
  const now = Date.now();
  const plan = { schemaVersion: '1.0', ...binding, createdAt: new Date(now).toISOString(), files: { 'app.tfplan': '4'.repeat(64) } };
  assertPlanBinding(plan, binding, now);
  for (const key of Object.keys(binding)) assert.throws(() => assertPlanBinding(plan, { ...binding, [key]: 'changed' }, now));
  assert.throws(() => assertPlanBinding(plan, binding, now + 86_400_001));
  assert.throws(() => assertPlanBinding({ ...plan, createdAt: 'invalid' }, binding, now));
});
test('module graph drift is not covered up by provider lockfiles', () => {
  const original = [{ key: 'storage', source: 'Azure/avm-res-storage-storageaccount/azurerm', version: '0.10.0' }];
  assertModuleGraph(original, original);
  assert.throws(() => assertModuleGraph([{ ...original[0], version: '0.11.0' }], original));
  assert.throws(() => assertModuleGraph(original, []));
});

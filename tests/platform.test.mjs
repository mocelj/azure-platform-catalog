import test from 'node:test';
import assert from 'node:assert/strict';
import { bind, canonical, catalog, hash, parseArguments, readJson, root, validateCatalogPin, validateConfig, validateEnvironment } from '../scripts/platform.mjs';
import { join } from 'node:path';

const config = { schemaVersion: '1.0', platformApp: 'storage', name: 'ledger', environment: 'demo', size: 'small' };
const environment = () => readJson(join(root, 'environments', 'demo.example.json'));

test('consumer release metadata must match the immutable workflow pin', () => {
  const pin = { repository: 'mocelj/azure-platform-catalog', version: '0.1.0', commit: 'a'.repeat(40) };
  validateCatalogPin(pin, pin.commit);
  for (const edit of [{ commit: 'main' }, { repository: 'attacker/repo' }, { version: '9.9.9' }, { extra: true }]) {
    assert.throws(() => validateCatalogPin({ ...pin, ...edit }));
  }
  assert.throws(() => validateCatalogPin(pin, 'b'.repeat(40)), /does not match/);
});
test('config accepts approved sizes and rejects unknown security inputs', () => {
  for (const size of ['small', 'medium']) assert.equal(validateConfig({ ...config, size }, 'storage-bicep').size, size);
  for (const extra of [{ publicNetworkAccess: 'Enabled' }, { image: 'attacker/image' }, { module: 'evil' }, { engine: 'terraform' }, { settings: {} }]) {
    assert.throws(() => validateConfig({ ...config, ...extra }, 'storage-bicep'), /rejected/);
  }
});
test('invalid names, environment, size, versions and target paths fail closed', () => {
  for (const value of [{ name: '../other' }, { name: '$(echo test)' }, { size: 'huge' }, { environment: 'prod' }, { schemaVersion: '2.0' }, { name: 'a\nb' }]) {
    assert.throws(() => validateConfig({ ...config, ...value }, 'storage-bicep'));
  }
  assert.throws(() => validateConfig(config, '../vm-bicep'));
  assert.throws(() => validateConfig(config, 'vm-bicep'), /does not match/);
  assert.throws(() => validateConfig(null, 'storage-bicep'));
});
test('all eight bindings are deterministic with separate engine ownership', () => {
  const resourceGroups = new Set();
  const stateKeys = new Set();
  for (const target of catalog.targets) {
    const service = target.replace(/-(bicep|terraform)$/, '');
    const request = { ...config, platformApp: service };
    const first = bind(request, target, environment());
    assert.deepEqual(first, bind(request, target, environment()));
    resourceGroups.add(first.metadata.resourceGroupName);
    stateKeys.add(first.metadata.stateKey);
    const parameters = first.parameters ?? first.values;
    assert.equal(parameters.name, request.name);
    assert.equal(parameters.location, 'swedencentral');
    assert.equal(parameters.tags.engine, first.metadata.engine);
  }
  assert.equal(resourceGroups.size, 8);
  assert.equal(stateKeys.size, 8);
});
test('semantic JSON hashes ignore property order, not values', () => {
  assert.equal(hash({ a: 1, b: { c: 2 } }), hash({ b: { c: 2 }, a: 1 }));
  assert.notEqual(hash(config), hash({ ...config, size: 'medium' }));
  assert.equal(canonical([2, 1]), '[2,1]');
});
test('environment refuses shared workload ownership, subnet reuse, incorrect DNS and synthetic live bindings', () => {
  validateEnvironment(environment());
  assert.throws(() => validateEnvironment(environment(), { live: true }), /Synthetic/);
  const duplicate = environment();
  duplicate.resourceGroups['vm-bicep'] = duplicate.resourceGroups['storage-bicep'];
  assert.throws(() => validateEnvironment(duplicate), /own resource group/);
  const sharedSubnet = environment();
  sharedSubnet.network.containerAppTerraformSubnetResourceId = sharedSubnet.network.containerAppBicepSubnetResourceId;
  assert.throws(() => validateEnvironment(sharedSubnet), /distinct/);
  const wrongDns = environment();
  wrongDns.privateDnsZones.storage = wrongDns.privateDnsZones['web-app'];
  assert.throws(() => validateEnvironment(wrongDns), /DNS/);
});
test('CLI rejects malformed, unknown and repeated flags', () => {
  assert.deepEqual(parseArguments(['validate', '--config', 'a', '--target', 'storage-bicep']).options, { config: 'a', target: 'storage-bicep' });
  for (const args of [['validate', '--config'], ['validate', '--config', 'a', '--config', 'b'], ['validate', '--script', 'x'], ['validate', 'config', 'x']]) {
    assert.throws(() => parseArguments(args));
  }
});

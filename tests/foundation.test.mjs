import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';
import { catalog, readJson, root, validateEnvironment } from '../scripts/platform.mjs';

const main = readFileSync(join(root, 'bootstrap', 'bicep', 'main.bicep'), 'utf8');
const shared = readFileSync(join(root, 'bootstrap', 'bicep', 'shared.bicep'), 'utf8');
const example = readJson(join(root, 'environments', 'demo.example.json'));

test('foundation metadata is synthetic and matches the authoritative environment contract', () => {
  assert.equal(validateEnvironment(example), example);
  assert.equal(example.subscriptionId, '00000000-0000-0000-0000-000000000000');
  assert.deepEqual(Object.keys(example.resourceGroups).sort(), [...catalog.targets].sort());
  assert.equal(new Set(Object.values(example.resourceGroups)).size, 8);
  assert.equal(new Set(Object.values(example.network)).size, 5);
  assert.throws(() => validateEnvironment(example, { live: true }), /Synthetic/);
});

test('Container Apps engines never share an environment subnet', () => {
  assert.notEqual(example.network.containerAppBicepSubnetResourceId, example.network.containerAppTerraformSubnetResourceId);
  assert.equal((shared.match(/delegation: 'Microsoft\.App\/environments'/g) ?? []).length, 2);
  const invalid = structuredClone(example);
  invalid.network.containerAppTerraformSubnetResourceId = invalid.network.containerAppBicepSubnetResourceId;
  assert.throws(() => validateEnvironment(invalid), /distinct/);
});

test('bootstrap is pinned AVM-only composition with separate workload groups', () => {
  for (const source of [main, shared]) {
    assert.doesNotMatch(source, /^\s*resource\s/gm);
    for (const reference of source.matchAll(/br\/public:([^']+)/g)) {
      assert.match(reference[1], /^avm\/(?:res|utl)\/[a-z0-9/-]+:\d+\.\d+\.\d+$/);
    }
    assert.doesNotMatch(source, /output\s+\w*(?:secret|key|password|token)\w*\s/ig);
  }
  assert.match(main, /output environmentMetadata object/);
  assert.match(main, /for target in targets/);
  for (const target of catalog.targets) assert.ok(main.includes(`'${target}'`));
});

test('state storage forbids account-key and public access while preserving recovery and data-plane roles', () => {
  for (const control of [
    'allowSharedKeyAccess: false', 'defaultToOAuthAuthentication: true',
    'allowBlobPublicAccess: false', "publicNetworkAccess: 'Disabled'",
    'supportsHttpsTrafficOnly: true', "minimumTlsVersion: 'TLS1_2'",
    'isVersioningEnabled: true', 'deleteRetentionPolicyDays: 14',
    'containerDeleteRetentionPolicyDays: 14', "name: 'tfstate'", "name: 'plans'",
    "roleDefinitionIdOrName: 'Storage Blob Data Contributor'", "service: 'blob'"
  ]) assert.ok(shared.includes(control), `Missing state control: ${control}`);
  assert.doesNotMatch(main + shared, /listKeys\(|primaryAccessKey|primaryConnectionString/);
});

test('explicit outbound NAT does not open inbound VM management', () => {
  assert.match(shared, /natGatewaySku: 'Standard'/);
  assert.match(shared, /skuName: 'Standard'/);
  assert.match(shared, /availabilityZone: availabilityZone/);
  assert.match(shared, /availabilityZones: \[availabilityZone\]/);
  assert.match(shared, /defaultOutboundAccess: false/);
  assert.equal((shared.match(/natGatewayResourceId: nat\.outputs\.resourceId/g) ?? []).length, 4);
  assert.match(shared, /sourceAddressPrefix: checkedManagementCidr/);
  assert.match(shared, /name: 'DenyAllOtherInbound'/);
  assert.match(shared, /parseCidr\(approvedManagementCidr\)/);
  assert.match(shared, /fail\('approvedManagementCidr must be/);
});

test('federation trusts protected catalog environments, not the consumer repository', () => {
  assert.match(main, /catalogRepository string = 'mocelj\/azure-platform-catalog'/);
  assert.match(shared, /var phases = \['plan', 'apply'\]/);
  assert.match(shared, /subject: 'repo:\$\{catalogRepository\}:environment:demo-\$\{phase\}'/);
  assert.doesNotMatch(shared, /:pull_request|refs\/heads|azure-platform-app-demo/);
  assert.doesNotMatch(main + shared, /roleDefinitionIdOrName: 'Owner'/);
});

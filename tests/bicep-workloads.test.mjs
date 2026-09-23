import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import test from 'node:test';

const root = fileURLToPath(new URL('..', import.meta.url));
const read = (path) => readFileSync(resolve(root, path), 'utf8');
const contract = JSON.parse(read('catalog/implementation-contract.json'));
const platform = JSON.parse(read('catalog/platform.json'));
const dependencies = JSON.parse(read('catalog/bicep-dependencies.json'));
const wrapper = (service) => read(`platform-apps/${service}/bicep/main.bicep`);

for (const service of platform.services) {
  test(`${service}: minimal shared input contract and AVM-only composition`, () => {
    const source = wrapper(service);
    const parameters = [...source.matchAll(/^param (\w+) /gm)].map((m) => m[1]).sort();
    assert.deepEqual(parameters, [
      ...contract.bicepCommonInputs, ...contract.serviceInputs[service],
    ].sort());
    assert.doesNotMatch(source, /^\s*resource\s/m);
    assert.doesNotMatch(source, /deploymentScripts|az rest|listKeys\(|adminPassword:/);
    assert.doesNotMatch(source, /BLOCKED|TODO|:latest\b/);
    assert.match(source, /@allowed\(\['swedencentral'\]\)/);
    assert.match(source, /@allowed\(\['small', 'medium'\]\)/);
    assert.match(source, /var platformTags = union\(tags, \{/);
    assert.match(source, /environment: 'demo'/);
    assert.match(source, /engine: 'bicep'/);
    assert.match(source, /systemAssigned: true/);
    assert.match(source, /workspaceResourceId: logAnalyticsWorkspaceResourceId/);
    assert.doesNotMatch(source, /enableTelemetry: true/);

    const modules = [...source.matchAll(/^module \w+ '([^']+)'/gm)].map((m) => m[1]);
    assert.ok(modules.length > 0);
    assert.deepEqual(modules.sort(), dependencies.modules
      .filter((m) => m.workload === service).map((m) => m.registry).sort());
    assert.equal((source.match(/enableTelemetry: false/g) ?? []).length >= modules.length, true);
    const outputs = [...source.matchAll(/^output (\w+) /gm)].map((m) => m[1]);
    assert.ok(outputs.every((name) => /^(resourceId|resourceName|environmentResourceId)$/.test(name)));
  });

  test(`${service}: local imported example and explicit platform lifecycle`, () => {
    const params = read(`examples/platform/${service}/bicep/main.bicepparam`);
    assert.match(params, new RegExp(`using '../../../../platform-apps/${service}/bicep/main.bicep'`));
    assert.match(params, /00000000-0000-0000-0000-000000000000/);
    const docs = read(`examples/platform/${service}/bicep/README.md`);
    for (const marker of ['restore', 'build', 'build-params', 'what-if', 'deployment group create', 'Cleanup']) {
      assert.ok(docs.includes(marker), `Missing ${marker}`);
    }
  });
}

test('storage hardcodes private Entra-only access and data protection', () => {
  const source = wrapper('storage');
  for (const setting of [
    "publicNetworkAccess: 'Disabled'", 'allowSharedKeyAccess: false',
    'allowBlobPublicAccess: false', 'supportsHttpsTrafficOnly: true',
    "minimumTlsVersion: 'TLS1_2'", 'isVersioningEnabled: true',
    'deleteRetentionPolicyDays: 7', 'containerDeleteRetentionPolicyDays: 7',
    "service: 'blob'",
  ]) assert.ok(source.includes(setting), setting);
});

test('VM is pinned Gen2 Trusted Launch and SSH-only without public IP', () => {
  const source = wrapper('vm');
  assert.match(source, /version: '\d+\.\d+\.\d+'/);
  for (const setting of [
    "publisher: 'Canonical'", "offer: 'ubuntu-24_04-lts'", "sku: 'server'",
    "osType: 'Linux'", "securityType: 'TrustedLaunch'", 'secureBootEnabled: true',
    'vTpmEnabled: true', 'disablePasswordAuthentication: true',
  ]) assert.ok(source.includes(setting), setting);
  assert.doesNotMatch(source, /pipConfiguration|publicIPAddressResourceId|customData:|extensionCustomScriptConfig/);
  assert.match(dependencies.vmImage.version, /^\d+\.\d+\.\d+$/);
  assert.ok(source.includes(`version: '${dependencies.vmImage.version}'`));
});

test('Web App separates ingress PE and outbound integration; no basic publishing', () => {
  const source = wrapper('web-app');
  for (const setting of [
    "publicNetworkAccess: 'Disabled'", 'httpsOnly: true',
    'subnetResourceId: privateEndpointSubnetResourceId',
    'virtualNetworkSubnetResourceId: integrationSubnetResourceId',
    "linuxFxVersion: 'NODE|24-lts'", "ftpsState: 'Disabled'",
    "minTlsVersion: '1.2'", "scmMinTlsVersion: '1.2'",
    'vnetRouteAllEnabled: true', 'allTraffic: true',
    "name: 'ftp', allow: false", "name: 'scm', allow: false",
  ]) assert.ok(source.includes(setting), setting);
});

test('Container Apps uses Private Link and azure-monitor without workspace secrets', () => {
  const source = wrapper('container-app');
  for (const setting of [
    "publicNetworkAccess: 'Disabled'", 'internal: false',
    'infrastructureSubnetResourceId: infrastructureSubnetResourceId',
    "service: 'managedEnvironments'", "workloadProfileType: 'Consumption'",
    "workloadProfileName: 'Consumption'", 'ingressExternal: true',
    'ingressAllowInsecure: false', "destination: 'azure-monitor'",
    'image: platform.containerImage', 'ingressTargetPort: platform.containerPort',
  ]) assert.ok(source.includes(setting), setting);
  assert.doesNotMatch(source, /sharedKey|customerId|listKeys|secrets:/);
  assert.match(platform.containerImage, /@sha256:[a-f0-9]{64}$/);
  assert.equal(platform.containerPort, 80);
});

test('dependency manifest records exact public upstream source and preview APIs', () => {
  for (const module of dependencies.modules) {
    assert.match(module.version, /^\d+\.\d+\.\d+$/);
    assert.ok(module.source.includes(`/${module.module}/${module.version}/${module.module}/main.bicep`));
    assert.ok(module.resourceApis.length > 0);
  }
  assert.ok(dependencies.previewApis.some((api) =>
    api.resourceType === 'Microsoft.Insights/diagnosticSettings'
      && api.apiVersion === '2021-05-01-preview'));
  assert.equal(dependencies.validation.liveDeployed, false);
});

import test from 'node:test';
import assert from 'node:assert/strict';
import { verifyFoundation } from '../scripts/preflight.mjs';

const snapshot = () => ({
  storage: { publicNetworkAccess: 'Disabled', allowSharedKeyAccess: false, allowBlobPublicAccess: false,
    enableHttpsTrafficOnly: true, minimumTlsVersion: 'TLS1_2',
    privateEndpointConnections: [{ privateLinkServiceConnectionState: { status: 'Approved' } }] },
  subnets: {
    vm: { defaultOutboundAccess: false, natGateway: { id: 'synthetic' } },
    webApp: { delegations: [{ serviceName: 'Microsoft.Web/serverFarms' }], natGateway: { id: 'synthetic' } },
    containerAppBicep: { delegations: [{ serviceName: 'Microsoft.App/environments' }], natGateway: { id: 'synthetic' } },
    containerAppTerraform: { delegations: [{ serviceName: 'Microsoft.App/environments' }], natGateway: { id: 'synthetic' } }
  },
  image: { hyperVGeneration: 'V2', architecture: 'x64', features: [{ name: 'SecurityType', value: 'TrustedLaunchSupported' }] },
  dnsAddresses: ['10.40.1.4']
});
test('foundation properties are checked, not inferred from resource IDs', () => {
  verifyFoundation(snapshot());
  const publicStorage = snapshot();
  publicStorage.storage.publicNetworkAccess = 'Enabled';
  assert.throws(() => verifyFoundation(publicStorage), /state storage/);
  const key = snapshot();
  key.storage.allowSharedKeyAccess = true;
  assert.throws(() => verifyFoundation(key));
  const dns = snapshot();
  dns.dnsAddresses = ['52.1.1.1'];
  assert.throws(() => verifyFoundation(dns), /private addresses/);
  const delegation = snapshot();
  delegation.subnets.webApp.delegations = [];
  assert.throws(() => verifyFoundation(delegation), /delegation/);
  const egress = snapshot();
  delete egress.subnets.vm.natGateway;
  assert.throws(() => verifyFoundation(egress), /NAT/);
});

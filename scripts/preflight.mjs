import { spawnSync } from 'node:child_process';
import { lookup } from 'node:dns/promises';
import { appendFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { catalog, readJson, validateEnvironment } from './platform.mjs';

export function verifyFoundation(snapshot) {
  const storage = snapshot.storage;
  if (storage.publicNetworkAccess !== 'Disabled' || storage.allowSharedKeyAccess !== false || storage.allowBlobPublicAccess !== false ||
      storage.enableHttpsTrafficOnly !== true || storage.minimumTlsVersion !== 'TLS1_2') {
    throw new Error('Existing state storage does not meet the private, Entra-only, HTTPS/TLS contract.');
  }
  if (!(storage.privateEndpointConnections ?? []).some((connection) => connection.privateLinkServiceConnectionState?.status === 'Approved')) {
    throw new Error('State storage has no approved private endpoint connection.');
  }
  for (const name of ['webApp', 'containerAppBicep', 'containerAppTerraform']) {
    const expected = name === 'webApp' ? 'Microsoft.Web/serverFarms' : 'Microsoft.App/environments';
    if (!(snapshot.subnets[name]?.delegations ?? []).some((delegation) => delegation.serviceName === expected)) {
      throw new Error(`Missing subnet delegation: ${name}.`);
    }
  }
  if (snapshot.subnets.vm.defaultOutboundAccess !== false) throw new Error('VM subnet must disable implicit default outbound access.');
  for (const name of ['vm', 'webApp', 'containerAppBicep', 'containerAppTerraform']) {
    const subnet = snapshot.subnets[name];
    if (!subnet.natGateway?.id && !subnet.routeTable?.id) throw new Error(`No explicit NAT or approved routing attachment for ${name}.`);
  }
  if (snapshot.image.hyperVGeneration !== 'V2' || snapshot.image.architecture !== 'x64' ||
      !(snapshot.image.features ?? []).some((feature) => feature.name === 'SecurityType' && feature.value.includes('TrustedLaunch'))) {
    throw new Error('The pinned VM image does not meet the generation/architecture/Trusted Launch contract.');
  }
  if (!snapshot.dnsAddresses.length || snapshot.dnsAddresses.some((ip) => !/^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.|f[cd][0-9a-f]{2}:)/i.test(ip))) {
    throw new Error('The state Blob hostname must resolve exclusively to private addresses from this runner.');
  }
}

export async function preflight(environment, diagnosticsFile, { checkImage = true } = {}) {
  validateEnvironment(environment, { live: true });
  const cli = process.platform === 'win32' ? 'az.cmd' : 'az';
  function get(args) {
    const arguments_ = [...args, '--output', 'json', '--only-show-errors'];
    const windows = process.platform === 'win32';
    // Windows Azure CLI is a cmd shim; admit no shell metacharacters to that path.
    if (windows && arguments_.some((arg) => !/^[A-Za-z0-9_:/.,=@-]+$/.test(arg))) {
      throw new Error('This Windows preflight accepts only shell-safe Azure identifiers; use the Linux runner for other existing names.');
    }
    const result = spawnSync(cli, arguments_, { shell: windows, encoding: 'utf8', timeout: 120_000, maxBuffer: 8 * 1024 * 1024 });
    if (result.error || result.status !== 0) {
      if (diagnosticsFile) appendFileSync(diagnosticsFile, `${result.error?.message ?? ''}\n${result.stderr ?? ''}\n`, { mode: 0o600 });
      throw new Error('Read-only foundation preflight failed; inspect private diagnostics and the documented Azure prerequisites.');
    }
    return JSON.parse(result.stdout);
  }
  for (const name of Object.values(environment.resourceGroups)) get(['group', 'show', '--name', name, '--subscription', environment.subscriptionId]);
  const network = environment.network;
  const subnets = {};
  for (const [name, id] of Object.entries({
    vm: network.vmSubnetResourceId, webApp: network.webAppSubnetResourceId,
    containerAppBicep: network.containerAppBicepSubnetResourceId, containerAppTerraform: network.containerAppTerraformSubnetResourceId,
    privateEndpoints: network.privateEndpointSubnetResourceId
  })) subnets[name] = get(['network', 'vnet', 'subnet', 'show', '--ids', id]);
  for (const id of Object.values(environment.privateDnsZones)) get(['resource', 'show', '--ids', id, '--api-version', '2020-06-01']);
  get(['resource', 'show', '--ids', environment.logAnalyticsWorkspaceResourceId, '--api-version', '2023-09-01']);
  const image = catalog.vmImage;
  const snapshot = {
    storage: get(['storage', 'account', 'show', '--name', environment.state.storageAccountName, '--resource-group', environment.state.resourceGroupName]),
    subnets,
    image: checkImage
      ? get(['vm', 'image', 'show', '--location', catalog.location, '--urn', `${image.publisher}:${image.offer}:${image.sku}:${image.version}`])
      : { architecture: image.architecture, hyperVGeneration: image.hyperVGeneration, features: [{ name: 'SecurityType', value: image.securityType }] },
    dnsAddresses: (await lookup(`${environment.state.storageAccountName}.blob.core.windows.net`, { all: true })).map((entry) => entry.address)
  };
  verifyFoundation(snapshot);
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  try {
    if (process.argv.length !== 5 || process.argv[2] !== '--environment' || process.argv[4] !== '--live') {
      throw new Error('Usage: node scripts/preflight.mjs --environment PRIVATE_FILE --live (read-only Azure queries; no provisioning)');
    }
    await preflight(readJson(resolve(process.argv[3])));
    console.log('Read-only foundation properties, image metadata and private state DNS passed. This does not prove runtime workload connectivity or quota.');
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}

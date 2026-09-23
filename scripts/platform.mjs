import Ajv from 'ajv';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

export const root = dirname(dirname(fileURLToPath(import.meta.url)));
export const readJson = (path) => JSON.parse(readFileSync(path, 'utf8'));
export const catalog = readJson(join(root, 'catalog', 'platform.json'));
const ajv = new Ajv({ allErrors: true, strict: true });
const configValidator = ajv.compile(readJson(join(root, 'schemas', 'platform-app.schema.json')));
const environmentValidator = ajv.compile(readJson(join(root, 'schemas', 'environment.schema.json')));
export const canonical = (value) => JSON.stringify(value, (_, item) =>
  item && typeof item === 'object' && !Array.isArray(item)
    ? Object.fromEntries(Object.keys(item).sort().map((key) => [key, item[key]])) : item);
export const hash = (value) => createHash('sha256').update(typeof value === 'string' ? value : canonical(value)).digest('hex');

export function targetParts(target) {
  if (!catalog.targets.includes(target)) throw new Error('Target must be one of the eight platform-owned targets.');
  const engine = target.endsWith('-terraform') ? 'terraform' : 'bicep';
  return { engine, service: target.slice(0, -(engine.length + 1)) };
}

export function validateConfig(config, target) {
  const { service } = targetParts(target);
  if (!configValidator(config)) throw new Error(`Configuration rejected: ${ajv.errorsText(configValidator.errors, { separator: '; ' })}`);
  if (config.platformApp !== service) throw new Error('Configuration platformApp does not match the immutable deployment target.');
  return config;
}

export function validateEnvironment(environment, { live = false } = {}) {
  if (!environmentValidator(environment)) throw new Error(`Environment rejected: ${ajv.errorsText(environmentValidator.errors, { separator: '; ' })}`);
  if (new Set(Object.values(environment.resourceGroups)).size !== 8) throw new Error('Each service/engine target must have its own resource group.');
  if (new Set(Object.values(environment.network)).size !== 5) throw new Error('Workload, integration, environment and private endpoint subnets must be distinct.');
  const prefix = `/subscriptions/${environment.subscriptionId}/resourceGroups/`;
  const ids = [...Object.values(environment.network), ...Object.values(environment.privateDnsZones), environment.logAnalyticsWorkspaceResourceId];
  if (ids.some((id) => !id.startsWith(prefix))) throw new Error('Foundation resources must belong to the configured subscription.');
  const zones = {
    storage: 'privatelink.blob.core.windows.net',
    'web-app': 'privatelink.azurewebsites.net',
    'container-app': `privatelink.${catalog.location}.azurecontainerapps.io`
  };
  for (const [service, zone] of Object.entries(zones)) {
    if (!environment.privateDnsZones[service].endsWith(`/providers/Microsoft.Network/privateDnsZones/${zone}`)) {
      throw new Error(`Incorrect private DNS zone for ${service}.`);
    }
  }
  if (!environment.logAnalyticsWorkspaceResourceId.includes('/providers/Microsoft.OperationalInsights/workspaces/')) {
    throw new Error('A Log Analytics workspace resource ID is required.');
  }
  if (live && environment.subscriptionId === '00000000-0000-0000-0000-000000000000') {
    throw new Error('Synthetic example bindings cannot be used for an Azure-connected operation.');
  }
  return environment;
}

export function bind(config, target, environment) {
  validateConfig(config, target);
  validateEnvironment(environment);
  const { service, engine } = targetParts(target);
  const name = config.name;
  const parameters = {
    name, location: catalog.location, size: config.size,
    logAnalyticsWorkspaceResourceId: environment.logAnalyticsWorkspaceResourceId,
    tags: { purpose: 'platform-demo', environment: 'demo', platformApp: service, engine, catalogVersion: catalog.catalogVersion }
  };
  if (service === 'vm') {
    parameters.subnetResourceId = environment.network.vmSubnetResourceId;
    parameters.sshPublicKey = environment.sshPublicKey;
  } else {
    parameters.privateEndpointSubnetResourceId = environment.network.privateEndpointSubnetResourceId;
    parameters.privateDnsZoneResourceId = environment.privateDnsZones[service];
  }
  if (service === 'web-app') parameters.integrationSubnetResourceId = environment.network.webAppSubnetResourceId;
  if (service === 'container-app') {
    parameters.infrastructureSubnetResourceId = engine === 'bicep'
      ? environment.network.containerAppBicepSubnetResourceId : environment.network.containerAppTerraformSubnetResourceId;
  }
  const metadata = {
    target, engine, service, name, resourceGroupName: environment.resourceGroups[target],
    subscriptionId: environment.subscriptionId, stateKey: `demo/${target}/${config.name}.tfstate`,
    configSha256: hash(config), environmentSha256: hash(environment), catalogVersion: catalog.catalogVersion
  };
  if (engine === 'terraform') {
    const values = Object.fromEntries(Object.entries(parameters).map(([key, value]) =>
      [key.replace(/[A-Z]/g, (letter) => `_${letter.toLowerCase()}`), value]));
    values.resource_group_name = metadata.resourceGroupName;
    return { metadata, values };
  }
  return { metadata, parameters };
}

export function render(config, target, environment, out) {
  const bound = bind(config, target, environment);
  mkdirSync(out, { recursive: true });
  const save = (name, value) => writeFileSync(join(out, name), `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
  save('deployment.json', bound.metadata);
  if (bound.metadata.engine === 'bicep') {
    save('app.parameters.json', {
      $schema: 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#',
      contentVersion: '1.0.0.0',
      parameters: Object.fromEntries(Object.entries(bound.parameters).map(([key, value]) => [key, { value }]))
    });
  } else {
    save('app.tfvars.json', bound.values);
    const backend = {
      resource_group_name: environment.state.resourceGroupName,
      storage_account_name: environment.state.storageAccountName,
      container_name: environment.state.containerName,
      key: bound.metadata.stateKey,
      use_oidc: true,
      use_azuread_auth: true
    };
    writeFileSync(join(out, 'backend.hcl'), Object.entries(backend).map(([key, value]) => `${key} = ${JSON.stringify(value)}`).join('\n') + '\n', { mode: 0o600 });
  }
  return bound.metadata;
}

export function parseArguments(args) {
  const [command, ...rest] = args;
  const options = {};
  const allowed = new Set(['config', 'target', 'environment', 'out', 'directory']);
  for (let index = 0; index < rest.length; index += 2) {
    const key = rest[index]?.replace(/^--/, '');
    if (!rest[index]?.startsWith('--') || !allowed.has(key) || options[key] !== undefined || !rest[index + 1] || rest[index + 1].startsWith('--')) {
      throw new Error('Expected unique --config, --target, --environment, --out or --directory arguments with values.');
    }
    options[key] = rest[index + 1];
  }
  return { command, options };
}

export function run(args) {
  const { command, options } = parseArguments(args);
  if (command === 'check-consumer') {
    if (!options.directory) throw new Error('--directory is required.');
    for (const target of catalog.targets) {
      const { service, engine } = targetParts(target);
      const path = join(resolve(options.directory), 'apps', service, engine, 'platform-app.json');
      if (!existsSync(path)) throw new Error(`Missing consumer configuration: ${service}/${engine}`);
      validateConfig(readJson(path), target);
    }
    console.log('All eight consumer configurations meet the approved contract. No Azure operation was performed.');
    return;
  }
  if (!['validate', 'render'].includes(command) || !options.config || !options.target) {
    throw new Error('Usage: node scripts/platform.mjs validate|render --config FILE --target SERVICE-ENGINE [--environment FILE --out DIR]');
  }
  const config = readJson(resolve(options.config));
  validateConfig(config, options.target);
  if (command === 'render') {
    if (!options.environment || !options.out) throw new Error('render requires an explicit --environment file and --out directory.');
    const metadata = render(config, options.target, readJson(resolve(options.environment)), resolve(options.out));
    console.log(`Rendered ${metadata.target}; configuration SHA256 ${metadata.configSha256}. No Azure operation was performed.`);
  } else {
    console.log(`Approved configuration for ${options.target}. No Azure operation was performed.`);
  }
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  try { run(process.argv.slice(2)); } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}

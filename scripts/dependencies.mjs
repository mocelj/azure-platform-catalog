import { createHash } from 'node:crypto';
import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, relative, resolve } from 'node:path';
import { root, catalog, hash, readJson } from './platform.mjs';
import { normalizedModuleGraph } from './trust.mjs';
import { withoutComments } from './check.mjs';

function moduleFiles(directory) {
  return readdirSync(directory, { withFileTypes: true }).filter((entry) =>
    !entry.isSymbolicLink() && !['.git', '.terraform', 'examples', 'tests'].includes(entry.name)).flatMap((entry) => {
    const path = join(directory, entry.name);
    return entry.isDirectory() ? moduleFiles(path) : /\.tf$/.test(entry.name) ? [path] : [];
  }).sort();
}

export function inspectDependencies(services = catalog.services) {
  const roots = {};
  for (const service of services) {
    const directory = join(root, 'platform-apps', service, 'terraform');
    const manifestPath = join(directory, '.terraform', 'modules', 'modules.json');
    if (!existsSync(manifestPath)) throw new Error(`Initialize ${service} with -backend=false before inspecting dependencies.`);
    const downloaded = readJson(manifestPath);
    const remoteModules = [];
    const seen = new Set();
    const apis = new Set();
    for (const item of downloaded.Modules.filter((module) => module.Key)) {
      const registrySource = item.Source.replace(/^registry\.terraform\.io\//, '');
      if (!item.Source.startsWith('.')) {
        if (!/^Azure\/avm-(res|utl)-[a-z0-9-]+\/(azure|azurerm)$/.test(registrySource) || !/^\d+\.\d+\.\d+$/.test(item.Version ?? '')) {
          throw new Error(`Unapproved resolved dependency: ${item.Source}@${item.Version}`);
        }
      }
      const moduleDirectory = resolve(directory, item.Dir);
      const directFiles = readdirSync(moduleDirectory).filter((name) => name.endsWith('.tf')).sort();
      for (const name of directFiles) {
        const code = withoutComments(readFileSync(join(moduleDirectory, name), 'utf8'));
        for (const match of code.matchAll(/["'](Microsoft\.[A-Za-z0-9./-]+@\d{4}-\d{2}-\d{2}(?:-preview)?)["']/g)) apis.add(match[1]);
        for (const block of code.matchAll(/\bmodule\s+"[^"]+"\s*\{([\s\S]*?)(?=\n\})/g)) {
          const source = block[1].match(/\bsource\s*=\s*"([^"]+)"/)?.[1];
          if (source && !source.startsWith('.') && !/\bversion\s*=\s*"\d+\.\d+\.\d+"/.test(block[1])) {
            throw new Error(`Floating upstream module reference in ${item.Key}/${name}: ${source}`);
          }
        }
      }
      const key = `${item.Source}@${item.Version}`;
      if (!item.Source.startsWith('.') && !seen.has(key)) {
        seen.add(key);
        const files = moduleFiles(moduleDirectory).map((file) => [
          relative(moduleDirectory, file).replaceAll('\\', '/'),
          createHash('sha256').update(readFileSync(file, 'utf8').replaceAll('\r\n', '\n')).digest('hex')
        ]);
        remoteModules.push({
          source: item.Source, version: item.Version,
          registry: `https://registry.terraform.io/modules/${registrySource}/${item.Version}`,
          sourceSha256: hash(files), hashScope: 'Sorted relative .tf paths and LF-normalized contents, excluding tests/examples and tooling directories'
        });
      }
    }
    roots[service] = { resolvedModules: normalizedModuleGraph(downloaded), remoteModules: remoteModules.sort((a, b) => a.source.localeCompare(b.source) || a.version.localeCompare(b.version)), apiVersions: [...apis].sort() };
  }
  return {
    schemaVersion: '1.0',
    terraform: '1.13.5',
    providerVersions: readJson(join(root, 'catalog', 'toolchain.json')).providers,
    apiNote: 'AzAPI API versions are inventoried from the selected .tf closure. AzureRM API choices are fixed by the exact provider release, not a configurable module parameter.',
    validation: {
      azureDeployment: 'Not performed',
      containerAppMocking: 'Terraform 1.13.5 cannot mock the selected environment module ephemeral resource schema, including count-zero resources. Source-contract checks and terraform validate apply; no provider-mocked or live environment coverage is claimed.',
      vmProviderWarnings: 'Upstream AzureRM metric and vm_agent_platform_updates_enabled deprecations; supported by the pinned AzureRM 4.81.0. No upstream source modified.'
    },
    roots
  };
}

try {
  const requestedService = process.argv[3] === '--service' ? process.argv[4] : undefined;
  if (requestedService && !catalog.services.includes(requestedService)) throw new Error('Unknown service.');
  if (process.argv.length > 3 && (!requestedService || process.argv.length !== 5 || process.argv[2] !== '--check')) throw new Error('Only --check accepts --service SERVICE.');
  const actual = inspectDependencies(requestedService ? [requestedService] : catalog.services);
  const manifest = join(root, 'catalog', 'terraform-dependencies.json');
  if (process.argv[2] === '--record') {
    writeFileSync(manifest, `${JSON.stringify(actual, null, 2)}\n`);
    console.log('Recorded reviewed module closure, normalized source hashes and API versions. Commit this file only after reviewing dependency changes.');
  } else if (process.argv.length === 2 || process.argv[2] === '--check') {
    const expected = readJson(manifest);
    if (requestedService) expected.roots = { [requestedService]: expected.roots[requestedService] };
    if (hash(actual) !== hash(expected)) throw new Error('Module source/version/API closure differs from the reviewed release manifest.');
    console.log('Terraform dependency sources, exact versions, content hashes and API inventory match the release.');
  } else throw new Error('Usage: node scripts/dependencies.mjs [--check|--record]');
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}

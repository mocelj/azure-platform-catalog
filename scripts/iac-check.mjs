import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { root, catalog } from './platform.mjs';
import { files } from './check.mjs';
import { assertModuleGraph, normalizedModuleGraph } from './trust.mjs';

const tools = join(root, '.tools');
const bicep = process.env.BICEP_BIN ?? join(tools, process.platform === 'win32' ? 'bicep.exe' : 'bicep');
const terraform = process.env.TERRAFORM_BIN ?? join(tools, process.platform === 'win32' ? 'terraform.exe' : 'terraform');
const out = join(root, 'out', 'compiled');
const cache = join(tools, 'providers');
mkdirSync(out, { recursive: true });
mkdirSync(cache, { recursive: true });
const run = (exe, args, cwd = root) => execFileSync(exe, args, { cwd, stdio: 'inherit', env: { ...process.env, TF_PLUGIN_CACHE_DIR: cache, TF_IN_AUTOMATION: '1' } });
const apis = new Set();
function inventory(value) {
  if (!value || typeof value !== 'object') return;
  if (typeof value.type === 'string' && typeof value.apiVersion === 'string') apis.add(`${value.type}@${value.apiVersion}`);
  for (const child of Object.values(value)) inventory(child);
}

try {
  if (!existsSync(bicep) || !existsSync(terraform)) throw new Error('Install the pinned toolchain first: node scripts/tooling.mjs');
  const bicepFiles = files(root).filter((path) => path.endsWith('.bicep'));
  for (let index = 0; index < bicepFiles.length; index++) {
    const destination = join(out, `template-${index}.json`);
    run(bicep, ['build', bicepFiles[index], '--outfile', destination]);
    inventory(JSON.parse(readFileSync(destination)));
  }
  for (const path of files(root).filter((file) => file.endsWith('.bicepparam'))) {
    run(bicep, ['build-params', path, '--outfile', join(out, `parameters-${files(root).indexOf(path)}.json`)]);
  }
  for (const service of catalog.services) {
    const directory = join(root, 'platform-apps', service, 'terraform');
    run(terraform, ['fmt', '-check', '-recursive'], directory);
    run(terraform, ['init', '-backend=false', '-input=false', '-lockfile=readonly', '-no-color'], directory);
    const dependencies = JSON.parse(readFileSync(join(root, 'catalog', 'terraform-dependencies.json')));
    assertModuleGraph(normalizedModuleGraph(JSON.parse(readFileSync(join(directory, '.terraform', 'modules', 'modules.json')))), dependencies.roots[service].resolvedModules);
    run(terraform, ['validate', '-no-color'], directory);
    if (files(directory).some((file) => file.endsWith('.tftest.hcl'))) {
      run(terraform, ['test', '-no-color', `-var-file=${join(root, 'examples', 'platform', service, 'terraform', '.example.tfvars.json')}`], directory);
    } else {
      console.log(`${service}: Terraform 1.13.5 cannot mock the environment module's ephemeral resource schema. This example is checked through source assertions and terraform validate, without mocked plan or live deployment coverage.`);
    }
  }
  run(process.execPath, [join(root, 'scripts', 'dependencies.mjs'), '--check']);
  writeFileSync(join(out, 'bicep-api-inventory.json'), JSON.stringify([...apis].sort(), null, 2) + '\n');
  console.log(`Build and validation passed for ${bicepFiles.length} Bicep files and four Terraform roots. No resources were deployed; private-network checks are part of the Azure rehearsal.`);
} catch (error) {
  console.error(`Offline IaC validation failed: ${error.message}`);
  process.exitCode = 1;
}

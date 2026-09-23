import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { dirname, isAbsolute, join, relative, resolve } from 'node:path';
import { parse } from 'yaml';
import { root, readJson, catalog } from './platform.mjs';

const ignored = new Set(['.git', '.terraform', '.tools', 'node_modules', 'out', '.local']);
export function files(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    if (ignored.has(entry.name) || entry.isSymbolicLink()) return [];
    const path = join(directory, entry.name);
    return entry.isDirectory() ? files(path) : [path];
  });
}

export function withoutComments(text) {
  return text.replace(/"(?:\\.|[^"\\])*"|'(?:''|\\.|[^'\\])*'|\/\*[\s\S]*?\*\/|\/\/[^\r\n]*|#[^\r\n]*/g,
    (match) => match.startsWith('/*') || match.startsWith('//') || match.startsWith('#') ? ' ' : match);
}

export function inspectSource(path, original, base = root) {
  const errors = [];
  const text = withoutComments(original);
  if (/\.bicep$/.test(path)) {
    if (/^\s*resource\s+\w+\s+/m.test(text)) errors.push('Use an AVM module instead of declaring a Bicep resource in the catalog.');
    for (const match of text.matchAll(/\bmodule\s+\w+\s+'([^']+)'/g)) {
      const source = match[1];
      if (source.startsWith('br/')) {
        if (!/^br\/public:avm\/(?:res|utl)\/[a-z0-9/-]+:\d+\.\d+\.\d+$/.test(source)) errors.push(`Unapproved or unpinned Bicep module: ${source}`);
      } else {
        const destination = resolve(dirname(path), source);
        const traversal = relative(base, destination);
        if (!source.endsWith('.bicep') || traversal.startsWith('..') || isAbsolute(traversal)) errors.push('Local Bicep module must remain inside the catalog.');
      }
    }
  }
  if (/\.tf$/.test(path)) {
    if (/^\s*(resource|provisioner)\s+"/m.test(text)) errors.push('Use an AVM module instead of defining Terraform resources or provisioners in the catalog.');
    for (const match of text.matchAll(/\bdata\s+"([^"]+)"/g)) {
      if (!['azapi_client_config', 'azurerm_client_config', 'azurerm_subscription'].includes(match[1])) errors.push(`Unapproved read-only lookup: ${match[1]}`);
    }
    for (const block of terraformModules(text)) {
      const source = block.match(/(?:^|\n)\s*source\s*=\s*"([^"]+)"/)?.[1];
      if (!source) { errors.push('Specify the AVM source as a literal module reference.'); continue; }
      if (source.startsWith('.')) {
        const traversal = relative(base, resolve(dirname(path), source));
        if (traversal.startsWith('..') || isAbsolute(traversal)) errors.push('Local Terraform module must remain inside the catalog.');
      } else {
        if (!/^Azure\/avm-(?:res|utl)-[a-z0-9-]+\/(?:azurerm|azure)$/.test(source)) errors.push(`Non-AVM Terraform module source: ${source}`);
        if (!/(?:^|\n)\s*version\s*=\s*"\d+\.\d+\.\d+"/.test(block)) errors.push('Every remote module needs an exact version.');
      }
    }
  }

  function terraformModules(text) {
    const result = [];
    for (const start of text.matchAll(/(?:^|\n)\s*module\s+"[^"]+"\s*\{/g)) {
      const offset = start.index + start[0].length;
      let depth = 1;
      let quoted = false;
      let escaped = false;
      let index = offset;
      for (; index < text.length && depth > 0; index++) {
        const char = text[index];
        if (quoted) {
          if (escaped) escaped = false;
          else if (char === '\\') escaped = true;
          else if (char === '"') quoted = false;
        } else if (char === '"') quoted = true;
        else if (char === '{') depth++;
        else if (char === '}') depth--;
      }
      result.push(text.slice(offset, index - 1));
    }
    return result;
  }
  if (/\.(bicep|bicepparam|tf)$/.test(path) && /['"]latest['"]|:latest\b|\?ref=(main|master)\b/i.test(text)) errors.push('Floating infrastructure/image reference.');
  return errors;
}

export function inspectWorkflow(text) {
  const workflow = parse(text);
  const errors = [];
  const triggers = workflow.on ?? {};
  if ('pull_request_target' in triggers || 'workflow_run' in triggers) errors.push('These workflows do not support pull_request_target or workflow_run triggers, which can give PR code elevated access.');
  for (const job of Object.values(workflow.jobs ?? {})) {
    if (job.uses && !job.uses.startsWith('./') && !/@[0-9a-f]{40}$/.test(job.uses)) errors.push('Reusable workflow reference must use a full commit SHA.');
    for (const step of job.steps ?? []) {
      if (step.uses && !step.uses.startsWith('./') && !/@[0-9a-f]{40}$/.test(step.uses)) errors.push('Action reference must use a full commit SHA.');
      if (step.run && /\$\{\{\s*(inputs|github\.event)/.test(step.run)) errors.push('Untrusted expression interpolated into a shell script.');
    }
    const isPrivate = JSON.stringify(job['runs-on'] ?? '').includes('self-hosted');
    if (isPrivate && !('workflow_dispatch' in triggers)) errors.push('Use workflow_dispatch for jobs on the private runner.');
    if (isPrivate && !job.environment) errors.push('Assign a protected GitHub Environment to the private-runner job.');
  }
  return errors;
}

export function check() {
  const failures = [];
  for (const path of files(root)) {
    if (/\.(bicep|bicepparam|tf)$/.test(path)) {
      for (const error of inspectSource(path, readFileSync(path, 'utf8'))) failures.push(`${relative(root, path)}: ${error}`);
    }
    if (path.includes(join('.github', 'workflows')) && /\.ya?ml$/.test(path)) {
      for (const error of inspectWorkflow(readFileSync(path, 'utf8'))) failures.push(`${relative(root, path)}: ${error}`);
    }
  }
  for (const service of catalog.services) for (const engine of catalog.engines) {
    const path = join(root, 'platform-apps', service, engine, engine === 'bicep' ? 'main.bicep' : 'main.tf');
    if (!existsSync(path)) failures.push(`Missing platform app: ${service}/${engine}`);
  }
  const toolchain = readJson(join(root, 'catalog', 'toolchain.json'));
  if (process.versions.node !== toolchain.node) failures.push(`Expected Node ${toolchain.node}, found ${process.versions.node}`);
  if (failures.length) throw new Error(failures.join('\n'));
  console.log('Catalog source, dependency pins and workflow checks passed.');
}

if (process.argv[1] && resolve(process.argv[1]) === join(root, 'scripts', 'check.mjs')) {
  try { check(); } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}

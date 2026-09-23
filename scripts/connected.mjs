import { spawnSync } from 'node:child_process';
import { appendFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import { root, readJson, render, hash, validateEnvironment } from './platform.mjs';
import { assertModuleGraph, assertPlanBinding, fetchConsumer, normalizedModuleGraph, summarizeTerraformPlan, summarizeWhatIf, validateDispatch } from './trust.mjs';
import { preflight } from './preflight.mjs';

const tools = join(root, '.tools');
const bicep = join(tools, process.platform === 'win32' ? 'bicep.exe' : 'bicep');
const terraform = join(tools, process.platform === 'win32' ? 'terraform.exe' : 'terraform');
const work = join(root, '.local', `${process.env.GITHUB_RUN_ID}_${process.env.GITHUB_RUN_ATTEMPT}`);
const digestFile = (file) => createHash('sha256').update(readFileSync(file)).digest('hex');
const allowedFiles = new Set(['app.tfplan', 'app.parameters.json', 'app.template.json']);
const azure = process.platform === 'win32' ? 'az.cmd' : 'az';

function command(executable, args, cwd = root) {
  const result = spawnSync(executable, args, {
    cwd, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, windowsHide: true,
    env: { ...process.env, TF_IN_AUTOMATION: '1', ARM_USE_OIDC: 'true', ARM_USE_MSI: 'false', ARM_USE_CLI: 'false' }
  });
  if (result.error || result.status !== 0 || (args.includes('what-if') && result.stderr?.trim())) {
    appendFileSync(join(work, 'private-diagnostics.log'), `${executable}\n${result.error?.message ?? ''}\n${result.stdout ?? ''}\n${result.stderr ?? ''}\n`, { mode: 0o600 });
    throw new Error('Connected command failed or what-if emitted diagnostics. Inspect the runner-local private diagnostics; no raw cloud output was published.');
  }
  return result.stdout;
}

function blob(environment, action, objectName, file) {
  const args = ['storage', 'blob', action, '--auth-mode', 'login', '--account-name', environment.state.storageAccountName,
    '--container-name', environment.state.planContainerName, '--name', objectName, '--file', file, '--only-show-errors', '--output', 'none'];
  if (action === 'upload') args.push('--overwrite', 'false');
  if (action === 'download') args.push('--overwrite', 'true');
  command(azure, args);
}

async function main() {
  mkdirSync(work, { recursive: true, mode: 0o700 });
  if (!validateDispatch({
    repository: process.env.GITHUB_REPOSITORY, ref: process.env.GITHUB_REF, actor: process.env.GITHUB_ACTOR,
    operation: process.env.OPERATION, target: process.env.TARGET, consumerSha: process.env.CONSUMER_SHA,
    planId: process.env.PLAN_ID, enabled: process.env.ENABLE_AZURE_DEPLOYMENT
  })) throw new Error('Connected execution is disabled.');
  if (process.platform !== 'linux') throw new Error('The connected workflow requires the documented isolated Linux runner.');
  if (!/^[0-9a-f]{40}$/.test(process.env.GITHUB_SHA ?? '') || !/^\d+_\d+$/.test(`${process.env.GITHUB_RUN_ID}_${process.env.GITHUB_RUN_ATTEMPT}`)) {
    throw new Error('Expected an immutable catalog SHA and GitHub run identity.');
  }
  const environment = JSON.parse(process.env.PLATFORM_ENVIRONMENT_JSON ?? '');
  validateEnvironment(environment, { live: true });
  const toolchain = readJson(join(root, 'catalog', 'toolchain.json'));
  if (process.versions.node !== toolchain.node) throw new Error('Private runner Node version does not match the release.');
  const cliVersion = JSON.parse(command(azure, ['version', '--output', 'json']))['azure-cli'];
  if (cliVersion !== toolchain.azureCli) throw new Error('Private runner Azure CLI version does not match the release.');
  if (!existsSync(bicep) || !existsSync(terraform)) throw new Error('Private runner needs the checksum-pinned local IaC tools.');
  const config = await fetchConsumer(process.env.CONSUMER_SHA, process.env.TARGET, process.env.GH_TOKEN);
  const deployment = render(config, process.env.TARGET, environment, work);
  const expected = {
    target: process.env.TARGET, consumerSha: process.env.CONSUMER_SHA, catalogSha: process.env.GITHUB_SHA,
    configHash: hash(config), environmentHash: hash(environment), toolchainHash: hash(toolchain)
  };
  const directory = join(root, 'platform-apps', deployment.service, deployment.engine);
  const initTerraform = () => {
    command(terraform, ['init', '-reconfigure', '-input=false', '-no-color', '-lockfile=readonly', `-backend-config=${join(work, 'backend.hcl')}`], directory);
    const resolved = normalizedModuleGraph(readJson(join(directory, '.terraform', 'modules', 'modules.json')));
    const dependencies = readJson(join(root, 'catalog', 'terraform-dependencies.json'));
    assertModuleGraph(resolved, dependencies.roots?.[deployment.service]?.resolvedModules);
    command(process.execPath, [join(root, 'scripts', 'dependencies.mjs'), '--check', '--service', deployment.service]);
  };
  command(azure, ['account', 'set', '--subscription', environment.subscriptionId]);
  // Regional image discovery is an operator prerequisite, not a reason to grant
  // the workload identity subscription-wide metadata permissions.
  await preflight(environment, join(work, 'private-diagnostics.log'), { checkImage: false });
  if (deployment.engine === 'terraform') initTerraform();
  let plan;
  if (process.env.OPERATION === 'plan') {
    let counts;
    let changeDigest;
    const savedFiles = {};
    if (deployment.engine === 'terraform') {
      const planPath = join(work, 'app.tfplan');
      command(terraform, ['plan', '-input=false', '-no-color', '-lock-timeout=60s', `-var-file=${join(work, 'app.tfvars.json')}`, `-out=${planPath}`], directory);
      counts = summarizeTerraformPlan(JSON.parse(command(terraform, ['show', '-json', planPath], directory)));
      savedFiles['app.tfplan'] = digestFile(planPath);
    } else {
      const template = join(work, 'app.template.json');
      command(bicep, ['build', join(directory, 'main.bicep'), '--outfile', template]);
      const result = JSON.parse(command(azure, ['deployment', 'group', 'what-if', '--resource-group', deployment.resourceGroupName,
        '--name', `golden-path-${deployment.target}`, '--template-file', template, '--parameters', `@${join(work, 'app.parameters.json')}`,
        '--result-format', 'FullResourcePayloads', '--output', 'json']));
      counts = summarizeWhatIf(result);
      changeDigest = hash(result.changes);
      savedFiles['app.template.json'] = digestFile(template);
      savedFiles['app.parameters.json'] = digestFile(join(work, 'app.parameters.json'));
    }
    const planId = `${process.env.GITHUB_RUN_ID}_${process.env.GITHUB_RUN_ATTEMPT}`;
    plan = { schemaVersion: '1.0', ...expected, createdAt: new Date().toISOString(), files: savedFiles, summary: counts, ...(changeDigest ? { changeDigest } : {}) };
    writeFileSync(join(work, 'plan.json'), JSON.stringify(plan), { mode: 0o600 });
    for (const name of Object.keys(savedFiles)) blob(environment, 'upload', `${planId}/${deployment.target}/${name}`, join(work, name));
    blob(environment, 'upload', `${planId}/${deployment.target}/plan.json`, join(work, 'plan.json'));
    const summary = `Plan completed. plan_id=${planId}\nChange counts: ${JSON.stringify(counts)}\nRaw plan is in private Blob storage, not a public artifact. Apply requires environment approval and unchanged bindings.`;
    console.log(summary);
    if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${summary}\n`);
  } else {
    const prefix = `${process.env.PLAN_ID}/${deployment.target}`;
    blob(environment, 'download', `${prefix}/plan.json`, join(work, 'plan.json'));
    plan = readJson(join(work, 'plan.json'));
    assertPlanBinding(plan, expected);
    const required = deployment.engine === 'terraform' ? ['app.tfplan'] : ['app.template.json', 'app.parameters.json'];
    if (JSON.stringify(Object.keys(plan.files).sort()) !== JSON.stringify(required.sort())) throw new Error('Saved plan file set does not match the engine.');
    for (const [name, checksum] of Object.entries(plan.files)) {
      if (!allowedFiles.has(name) || !/^[0-9a-f]{64}$/.test(checksum)) throw new Error('Invalid private plan integrity entry.');
      blob(environment, 'download', `${prefix}/${name}`, join(work, name));
      if (digestFile(join(work, name)) !== checksum) throw new Error('Private plan content changed; refusing apply.');
    }
    if (deployment.engine === 'terraform') {
      summarizeTerraformPlan(JSON.parse(command(terraform, ['show', '-json', join(work, 'app.tfplan')], directory)));
      command(terraform, ['apply', '-input=false', '-no-color', '-lock-timeout=60s', join(work, 'app.tfplan')], directory);
    } else {
      const current = JSON.parse(command(azure, ['deployment', 'group', 'what-if', '--resource-group', deployment.resourceGroupName,
        '--name', `golden-path-${deployment.target}`, '--template-file', join(work, 'app.template.json'),
        '--parameters', `@${join(work, 'app.parameters.json')}`, '--result-format', 'FullResourcePayloads', '--output', 'json']));
      summarizeWhatIf(current);
      if (hash(current.changes) !== plan.changeDigest) throw new Error('ARM what-if changed since approval; create a fresh plan before applying.');
      command(azure, ['deployment', 'group', 'create', '--resource-group', deployment.resourceGroupName,
        '--name', `golden-path-${deployment.target}`, '--mode', 'Incremental', '--template-file', join(work, 'app.template.json'),
        '--parameters', `@${join(work, 'app.parameters.json')}`, '--only-show-errors', '--output', 'none']);
    }
    console.log('Approved infrastructure apply completed. Perform the documented private-network smoke tests; application health is not implied.');
  }
}

try { await main(); } catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}

import { catalog, hash, validateConfig, targetParts } from './platform.mjs';

export function validateDispatch(input) {
  if (input.repository !== 'mocelj/azure-platform-catalog' || input.ref !== 'refs/heads/main' || input.actor !== 'mocelj') {
    throw new Error('Run the Azure workflow as the catalog owner from its protected main branch.');
  }
  if (!['plan', 'apply'].includes(input.operation)) throw new Error('Only plan and apply are supported; destroy is a separate operator procedure.');
  targetParts(input.target);
  if (!/^[0-9a-f]{40}$/.test(input.consumerSha ?? '')) throw new Error('An exact lowercase 40-character consumer commit SHA is required.');
  if (input.operation === 'apply' && !/^\d+_\d+$/.test(input.planId ?? '')) throw new Error('Apply requires the numeric plan_id printed by a successful plan run.');
  return input.enabled === 'true';
}

export async function fetchConsumer(sha, target, token, fetcher = fetch) {
  if (!/^[0-9a-f]{40}$/.test(sha)) throw new Error('Invalid consumer SHA.');
  const { service, engine } = targetParts(target);
  const base = `https://api.github.com/repos/${catalog.consumerRepository}`;
  async function get(path) {
    const response = await fetcher(base + path, {
      headers: { Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      signal: AbortSignal.timeout(30_000)
    });
    if (!response.ok) throw new Error(`Consumer verification failed (GitHub HTTP ${response.status}).`);
    return response.json();
  }
  const repository = await get('');
  if (repository.default_branch !== 'main') throw new Error('Consumer default branch must be main.');
  const comparison = await get(`/compare/${sha}...main`);
  if (!['ahead', 'identical'].includes(comparison.status)) throw new Error('Consumer commit is not an ancestor of main. Merge the configuration PR before running an Azure plan.');
  const file = await get(`/contents/apps/${service}/${engine}/platform-app.json?ref=${sha}`);
  if (file.type !== 'file' || file.encoding !== 'base64' || file.size > 16_384) throw new Error('Consumer input must be a small JSON configuration file.');
  const config = JSON.parse(Buffer.from(file.content, 'base64').toString('utf8'));
  validateConfig(config, target);
  return config;
}

export function summarizeTerraformPlan(plan) {
  if (plan.errored === true || plan.complete === false) throw new Error('Terraform reported an errored or incomplete plan.');
  const counts = {};
  for (const resource of plan.resource_changes ?? []) {
    const actions = resource.change?.actions ?? [];
    if (actions.includes('delete')) throw new Error('This plan deletes or replaces resources. Review it separately; the demo workflow does not apply destructive changes.');
    const action = actions.join('+');
    if (!['no-op', 'create', 'read', 'update'].includes(action)) throw new Error('Unrecognized Terraform change action.');
    counts[action] = (counts[action] ?? 0) + 1;
  }
  return counts;
}

export function summarizeWhatIf(result) {
  if (result.error || (result.status && result.status !== 'Succeeded')) throw new Error('ARM what-if did not succeed.');
  if (!Array.isArray(result.changes)) throw new Error('ARM what-if did not return a changes array.');
  const counts = {};
  for (const change of result.changes) {
    if (!['Create', 'Modify', 'NoChange', 'Deploy'].includes(change.changeType)) {
      throw new Error(`ARM what-if has a destructive or incomplete change (${change.changeType}); manual investigation is required.`);
    }
    counts[change.changeType] = (counts[change.changeType] ?? 0) + 1;
  }
  return counts;
}

export function assertPlanBinding(plan, expected, now = Date.now()) {
  if (plan.schemaVersion !== '1.0') throw new Error('Unsupported saved plan format.');
  for (const key of ['target', 'consumerSha', 'catalogSha', 'configHash', 'environmentHash', 'toolchainHash']) {
    if (plan[key] !== expected[key]) throw new Error(`Saved plan no longer matches ${key}. Generate and review a new plan.`);
  }
  const created = Date.parse(plan.createdAt);
  if (!Number.isFinite(created) || created > now || now - created > 86_400_000) throw new Error('Saved plan is invalid or older than 24 hours; plan again.');
  if (!plan.files || !Object.keys(plan.files).length) throw new Error('Saved plan has no integrity manifest.');
}

export function normalizedModuleGraph(manifest) {
  return (manifest.Modules ?? []).filter((entry) => entry.Key).map((entry) => ({
    key: entry.Key, source: entry.Source, version: entry.Version ?? null
  })).sort((a, b) => a.key.localeCompare(b.key));
}

export function assertModuleGraph(actual, expected) {
  if (!Array.isArray(expected) || expected.length === 0) throw new Error('The release has no resolved module manifest for this target.');
  const sort = (entries) => [...entries].sort((a, b) => a.key.localeCompare(b.key));
  if (hash(sort(actual)) !== hash(sort(expected))) throw new Error('Resolved Terraform modules differ from the release manifest. Review the dependency change before deploying.');
}

import { appendFileSync } from 'node:fs';
import { fetchConsumer, validateDispatch } from './trust.mjs';

try {
  const enabled = validateDispatch({
    repository: process.env.GITHUB_REPOSITORY, ref: process.env.GITHUB_REF, actor: process.env.GITHUB_ACTOR,
    operation: process.env.OPERATION, target: process.env.TARGET, consumerSha: process.env.CONSUMER_SHA,
    planId: process.env.PLAN_ID, enabled: process.env.ENABLE_AZURE_DEPLOYMENT
  });
  if (enabled) await fetchConsumer(process.env.CONSUMER_SHA, process.env.TARGET, process.env.GH_TOKEN);
  appendFileSync(process.env.GITHUB_OUTPUT, `enabled=${enabled}\n`);
  const message = enabled
    ? 'Application configuration verified. The catalog workflow can proceed to the Azure step.'
    : 'Azure execution is disabled; no plan or deployment was run. Complete the environment setup before enabling it.';
  console.log(message);
  if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${message}\n`);
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}

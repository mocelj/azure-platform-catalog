# Validation and connected rehearsal

There are two separate gates: **offline release checks** and an **explicitly authorized Azure-connected rehearsal**. The commands below are instructions; the recorded local evidence is summarized separately. No Azure deployment is part of repository implementation.

Run `node scripts/preflight.mjs --environment environments/demo.local.json --live`
from an authorized private operator host for read-only checks, including current
regional image metadata. The connected workflow checks foundation properties and
private state DNS but uses the catalog's approved image metadata; it does not
grant the workload identity subscription-wide discovery permissions. Image
availability, quota and SKU compatibility remain operator prerequisites.

## Offline release checks

From the catalog root with the pinned Node/npm versions:

```powershell
npm ci --ignore-scripts
npm test
npm run check
node scripts/platform.mjs check-consumer --directory ..\azure-platform-app-demo
node scripts/tooling.mjs
npm run iac:check
```

Run the sample independently:

```powershell
Push-Location ..\azure-platform-app-demo\samples\web-app
npm ci --ignore-scripts
npm test
npm run check
Pop-Location
```

Record command exits and evidence at the exact catalog/consumer commits. Confirm all eight targets, bootstrap, schemas, negative fixtures, renderer parity, pinned dependencies, provider locks, and workflow boundaries are covered by the actual test results. Do not call missing checks “passed.”

Downloads/restores may contact public registries. Offline IaC validation must not connect to the private Terraform backend or deploy Azure resources. A mock provider test demonstrates assertions over mocked configuration; it is not an Azure plan.

### Run one Terraform mock suite

The example variables are not loaded automatically. Storage, VM, and Web App have mock suites; Container Apps does not, for the reason below. After backend-disabled initialization with read-only provider locks, run a supported suite from its workload root using an **explicit `-var-file`**. From the catalog root on Windows:

```powershell
$service = 'storage' # storage, vm, or web-app; Container Apps has no mock suite
$Terraform = (Resolve-Path .\.tools\terraform.exe).Path
$root = (Resolve-Path ".\platform-apps\$service\terraform").Path
$variables = (Resolve-Path ".\examples\platform\$service\terraform\.example.tfvars.json").Path
& $Terraform "-chdir=$root" test "-var-file=$variables"
if ($LASTEXITCODE -ne 0) { throw 'The selected Terraform mock suite failed.' }
```

`-chdir` selects the workload root; the absolute variable-file path avoids resolving it against the wrong directory. Do not run bare `terraform test` and assume the synthetic example values are discovered. On Linux, use the verified local Terraform executable and native paths.

### Recorded local evidence and limits

The integration handoff records these results; they are not publication, hosted-CI, or deployment approval:

| Check | Recorded local result |
| --- | --- |
| Catalog Node tests | 34 passed |
| Consumer contract | All eight requests validate/render; application names remain unchanged, target groups/state keys remain separate, forbidden public-access properties are rejected |
| Pinned Bicep `0.47.16` | Verified compiler; all four workload roots and four parameter files, plus bootstrap `main`, `shared`, and demo parameters compiled with zero warnings |
| Terraform `1.13.5` | All four roots initialize without the backend and validate; accepted upstream VM provider deprecation warnings remain |
| Terraform mock suites | Storage, VM, and Web App: three actual mocked plan runs each, nine passed in total. Container Apps: no mock suite or mocked plan coverage |
| Publication and hosted CI | Pending; no release claim |
| Azure plan/apply and live health | Not run; connected execution remains disabled |

The earlier local compiler-download and environment-schema blockers are resolved. The renderer passes the validated application name unchanged; wrappers own final Azure names. These fixes do not replace fresh-checkout CI evidence.

**Container Apps mock limitation:** Terraform `1.13.5` rejects the upstream ephemeral resource's mock schema even when its `count` is zero. An attempted `override_module` did **not** bypass the failure, so the unsupported Container Apps `.tftest.hcl` file was removed. **Neither its environment, app, nor private endpoint has mocked plan coverage.** Evidence consists only of explicit Node source-contract invariants and real Terraform backend-disabled initialization/validation. Source checks inspect the private-access, subnet, workload-profile, monitoring, image/ingress, and private-endpoint bindings; they do not validate expanded Azure resources or live behavior. `npm run iac:check` explicitly prints this unavailable-test limitation instead of silently reporting the absent suite as passed.

**VM warnings:** the pinned upstream VM AVM emits provider deprecation warnings. They are accepted compatibility warnings for this demo, not a claim of warning-free Terraform validation. Retain them in validation evidence and review them during dependency upgrades; do not patch upstream code or silently change provider pins to suppress them.

Before release, verify documentation links, secret/public-content hygiene, immutable cross-repository pins, and real credential-free CI from fresh checkouts. An initial catalog publication may be explicitly marked **unfinished** to obtain hosted validation; it is not a release or evidence that those checks have passed. Require green hosted checks with the exact pinned compiler and providers before creating the release and final consumer pin.

Repository rules, environment reviewers, Actions settings, and private reporting are service-side settings; committing YAML/CODEOWNERS alone does not configure them.

## Connected prerequisites — all must be satisfied

### Subscription and approved resources

- A designated demo subscription, exact tenant, `swedencentral` region, cost owner, and authorized resource scopes.
- Required providers registered through approved administration; regional availability, quotas, exact VM image/SKU availability, supported runtime, Private Link support, Container Apps workload-profile/subnet/NAT compatibility, and preview API acceptance checked.
- Azure policy/deny assignments, role assignments, locks, and required Marketplace terms reviewed. Offline compilation cannot establish any of these.
- A reviewed [foundation deployment or existing-foundation binding](foundation.md). Existing mode does not adopt or delete customer resources. Use real validated bindings kept out of Git; the zero-subscription example is not a deployment target.
- Distinct resource groups per target; distinct private-endpoint, VM, Web App integration, and per-engine Container Apps infrastructure subnets. Confirm actual CIDR capacity and delegations.

### Private client and runner

- An existing isolated runner registered **only** to the catalog repository, with no customer-sensitive reachability and no persistent powerful Azure credentials. This repository does not provision a runner.
- Explicit route and DNS integration to the approved private endpoints. Validate Blob, Web App site/SCM, and Container Apps environment names from the runner and the private test client.
- Approved egress for GitHub, Entra, Azure management, pinned dependency sources, image registry, and public telemetry. NAT is outbound connectivity, not destination filtering.
- Protection against untrusted contributor jobs: no consumer runner registration; no privileged PR/fork code execution; approvals/restrictions for outside contributions; preferably fresh/disposable execution and workspace cleanup.
- Acknowledgement that this **public-repository self-hosted runner is a demo exception**, not an FSI production recommendation.

### Identity, state, and approval

- Bootstrap administration separated from routine deployment. Resource-group and role-assignment permissions reviewed explicitly; never grant routine deployment subscription Owner just to resolve a failure.
- Catalog/environment-scoped Entra federation configured for the exact intended issuer, subject, and audience; protected branch/environment restrictions verified. No client-secret or ambient-identity fallback.
- Private Blob state access uses OIDC **and** Entra data-plane authorization. Confirm scope and propagation of the Blob role separately from infrastructure permissions. No account-key/SAS retrieval.
- The private `plans` Blob container and retention for saved plans, with source/configuration/environment/target bindings. No raw plan goes to a public artifact. State locking and workflow serialization remain enabled.
- Both plan and apply require an exact consumer SHA already merged into approved `main`. Apply uses its reviewed saved plan/bound inputs, rejects mismatched configuration/catalog/environment hashes and unreviewed destructive changes, and pauses at the protected `demo-apply` environment.
- One presenter's approval is an intentional demo mechanism, **not independent separation of duties**. A real deployment process requires another authorized reviewer and prevention of self-review.

Only after the prerequisites are reviewed should a maintainer enable `ENABLE_AZURE_DEPLOYMENT=true`. Keep it absent/false otherwise.

## Maintainer handoff

Use [`.github/workflows/catalog-dispatch.yml`](../.github/workflows/catalog-dispatch.yml) **in the catalog repository**, from its protected `main`. Its inputs are `operation` (`plan` or `apply`), `target` (one of eight service-engine choices), `consumer_sha` (exact 40-hex commit), and `plan_id` (required for apply).

**Both operations require a consumer commit already merged into approved `main`. There is no premerge Azure preview in this release.** PR validation remains offline, with no private runner or Azure credentials. Do not substitute a consumer branch name, fork, arbitrary repository/path, or catalog ref.

With authenticated GitHub CLI, after all connected prerequisites are met:

```powershell
$target = 'storage-terraform'
$consumerSha = '<merged-consumer-commit-40-hex>'
gh workflow run catalog-dispatch.yml -R mocelj/azure-platform-catalog -f operation=plan -f "target=$target" -f "consumer_sha=$consumerSha"
```

The plan operation uses `demo-plan`. Its private result is stored in the `plans` Blob container; the sanitized completion summary prints `plan_id`. Review the private plan/what-if and limitations, then dispatch apply using the same target, consumer SHA, and printed ID:

```powershell
$planId = '<plan_id-printed-by-successful-plan>'
gh workflow run catalog-dispatch.yml -R mocelj/azure-platform-catalog -f operation=apply -f "target=$target" -f "consumer_sha=$consumerSha" -f "plan_id=$planId"
```

Apply requires explicit approval in the protected **`demo-apply`** environment and matching configuration, catalog, and environment hashes. A changed binding invalidates the saved result: create and review a new plan rather than attempting to reuse it. The ID is not a substitute for approval or a public artifact location.

The consumer's `.github/workflows/validate.yml` and catalog's `reusable-validate.yml` are public-only validation paths. Reusing a workflow does not lend the catalog's repository runner to the consumer. Do not add a PAT/GitHub App credential for automatic dispatch.

Connected operations must read consumer JSON as data, not check out and execute consumer code, workflows, install hooks, or payload. Application release uses a [separately reviewed artifact](https://github.com/mocelj/azure-platform-app-demo/blob/main/docs/web-app-payload.md).

## Rehearsal evidence — initially unverified

| Gate | Evidence to record privately |
| --- | --- |
| Foundation | Approved create/existing mode, scope inventory, ownership, deployment result, and validated bindings |
| State | Private DNS/route, Entra-only initialization, independent state keys, authorization and locking |
| Bicep preview | Exact source/input hashes and reviewed what-if; warnings, ignored/unevaluated resources, and limitations retained |
| Terraform preview | Read-only dependency locks, exact source/input/state target, reviewed plan, protected saved-plan digest/location |
| Apply | Explicit `demo-apply` approval, reviewed `plan_id`, matching config/catalog/environment hashes, merged consumer SHA, serialized target, actual deployment result |
| Private ingress | Positive private-client test and negative Internet test for each service; no bypass via SCM or alternate endpoint |
| Storage | Entra-authorized Blob access and denial of Shared Key/anonymous access |
| VM | Key-only private management from approved source; expected image/security posture, no public IP |
| Web App | Private site/SCM DNS, Entra ZIP payload release, basic publishing still off, real HTTP response |
| Container App | Environment Private Link, disabled public network access, HTTPS private app response, intended image digest/port |
| Egress and logs | Observed intended routes, registry reachability, diagnostics and disclosed public Monitor path |
| Repeat/change | Idempotency review and controlled size change without unintended replacement/deletion |
| Cleanup | Approved target/resource inventory, preserved state/evidence, workload-first teardown, no customer-owned deletion |

Use the [eight platform guides](../README.md#eight-examples-one-developer-contract) for the actual workload entrypoints and commands. Authentication does not itself prove sufficient authorization. Bicep what-if normally requires deployment-equivalent permissions; do not advertise it as read-only or assume `ProviderNoRbac` removes all permission requirements.

Stop when any prerequisite fails. Do not change public access, use key authentication, skip locking, choose a floating image, or introduce non-AVM infrastructure to force a successful demonstration.

## Reporting results

State separately: local checks run, public CI verified, Azure preflight performed, preview performed, deployment performed, health tested, and cleanup performed. Use **not run**, **blocked**, or **unverified** where appropriate. Sanitize public summaries; keep tokens, real bindings, state, plans, resource-sensitive output, and raw logs out of public artifacts.

# Validation and deployment preparation

Both repositories have public `v0.1.0` releases and passing CI. The release checks
cover configuration, source, compilation, and supported Terraform mocks. No Azure
deployment has been performed, so authorization, private connectivity, and workload
health still need to be verified in the target environment.

The platform operator can run
`node scripts/preflight.mjs --environment environments/demo.local.json --live`
from a private host for read-only checks, including current regional image
metadata. The deployment workflow checks foundation properties and private state
DNS but uses catalog image metadata rather than subscription-wide discovery.
Current image availability, quota, and SKU compatibility therefore remain
operator checks.

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

Record results against the catalog and consumer commits under review. These
commands restore dependencies from public registries, but do not connect to
private Terraform state or deploy resources. Mock tests evaluate configuration
with provider responses replaced by test data.

### Run one Terraform mock suite

Storage, VM, and Web App have mock suites. Their example variables must be
supplied explicitly because Terraform does not discover these files automatically.
After backend-disabled initialization, run a suite from the catalog root:

```powershell
$service = 'storage' # storage, vm, or web-app; Container Apps has no mock suite
$Terraform = (Resolve-Path .\.tools\terraform.exe).Path
$root = (Resolve-Path ".\platform-apps\$service\terraform").Path
$variables = (Resolve-Path ".\examples\platform\$service\terraform\.example.tfvars.json").Path
& $Terraform "-chdir=$root" test "-var-file=$variables"
if ($LASTEXITCODE -ne 0) { throw 'The selected Terraform mock suite failed.' }
```

`-chdir` selects the workload root, and the absolute variable path keeps resolution
independent of that change. On Linux, use the local Terraform executable and
native paths.

### Recorded local evidence and limits

The release validation covers:

| Check | Coverage and result |
| --- | --- |
| Catalog Node tests | Passing configuration, source, security, preflight, and workflow checks |
| Consumer contract | All eight requests validate/render; application names remain unchanged, target groups/state keys remain separate, forbidden public-access properties are rejected |
| Bicep `0.47.16` | Four workload roots and four parameter files, plus bootstrap `main`, `shared`, and demo parameters compile with zero warnings |
| Terraform `1.13.5` | All four roots initialize without the backend and validate; accepted upstream VM provider deprecation warnings remain |
| Terraform mock suites | Storage, VM, and Web App: three mocked plan runs each, nine passed in total. Container Apps has no mocked plan coverage |
| Publication and hosted CI | Both `v0.1.0` releases are public; hosted validation passes |
| Azure plan/apply and live health | Not run; connected execution remains disabled |

Container Apps has source-contract checks and real Terraform initialization/validation
only. Terraform `1.13.5` cannot mock an ephemeral resource schema in the upstream
environment module, even at count zero. This leaves the environment, app, and
private endpoint without mocked plan coverage. Source tests check private access,
subnet and profile settings, monitoring, image/ingress, and endpoint bindings;
they do not evaluate the expanded Azure resources. `npm run iac:check` reports
the limitation in its output.

The VM module produces provider deprecation warnings. These are accepted for
the current dependency set and retained for the next AVM/provider upgrade review.

For subsequent releases, rerun validation from fresh checkouts and check dependency
records, links, public-data hygiene, and consumer pins. Repository rules,
environment reviewers, Actions settings, and private reporting also need service-side
configuration; committing their related files is not sufficient.

## Preparing the Azure environment

### Subscription and foundation

Confirm the subscription, tenant, `swedencentral` region, cost owner, and deployment
scopes. Review provider registration, Azure Policy and deny assignments, role
assignments, locks, and Marketplace terms. Check current image/SKU capacity,
runtime and Private Link support, and acceptance of the Container Apps preview APIs.

Use either the [catalog foundation or existing customer bindings](foundation.md).
Keep real bindings out of Git. Each target needs its own resource group, and
private endpoints, VM, Web App integration, and the two Container Apps environments
need the specified separate subnets. Check CIDR capacity, delegations, and
workload-profile/NAT compatibility.

### Private client and runner

Provide an isolated runner registered only to the catalog, without customer-sensitive
network reachability or persistent privileged credentials. Runner provisioning is
outside this repository. Test routes and DNS for Blob, Web App site/SCM, and
Container Apps from both the runner and a private client.

The runner needs egress to GitHub, Entra, Azure management, dependency/image
registries, and public Monitor endpoints. NAT provides connectivity rather than
destination filtering. Restrict outside-contributor jobs, keep consumer and fork
code off the private runner, and use disposable execution or workspace cleanup.
For production, move execution to a private organizational repository and runner
group; the public-repository runner is a demo exception.

### Identity, state, and approval

Separate bootstrap administration from routine workload permissions. Configure
catalog/environment-scoped federation with the expected issuer, subject, and
audience, then verify branch and environment restrictions. The deployment path
uses neither client secrets nor an ambient privileged runner identity.

State access needs OIDC and an Entra Blob data role in addition to infrastructure
permissions. Verify role scope and propagation. Keep saved plans in the private
`plans` container with their source/input bindings and retention policy, and
retain state locking and workflow serialization.

Apply pauses in `demo-apply`, checks the saved result against current hashes, and
rejects unreviewed destructive changes. A single presenter's approval demonstrates
the mechanism but not separation of duties; production requires an independent
reviewer and prevention of self-review.

Set `ENABLE_AZURE_DEPLOYMENT=true` only when this environment preparation is
complete. It remains disabled for the published example.

## Maintainer handoff

Use [`.github/workflows/catalog-dispatch.yml`](../.github/workflows/catalog-dispatch.yml)
on the catalog's protected `main`. Its inputs are `operation` (`plan` or `apply`),
`target`, `consumer_sha` (the full 40-hex commit), and `plan_id` for apply.

Both operations require a consumer commit already merged into `main`. PR
validation has no Azure access, and this release has no premerge Azure preview.
The workflow accepts only the configured repository and target paths.

With authenticated GitHub CLI, after all connected prerequisites are met:

```powershell
$target = 'storage-terraform'
$consumerSha = '<merged-consumer-commit-40-hex>'
gh workflow run catalog-dispatch.yml -R mocelj/azure-platform-catalog -f operation=plan -f "target=$target" -f "consumer_sha=$consumerSha"
```

Plan uses `demo-plan` and stores its result in the private `plans` container.
The sanitized summary prints `plan_id`. After reviewing the plan or what-if,
dispatch apply with the same target and consumer SHA:

```powershell
$planId = '<plan_id-printed-by-successful-plan>'
gh workflow run catalog-dispatch.yml -R mocelj/azure-platform-catalog -f operation=apply -f "target=$target" -f "consumer_sha=$consumerSha" -f "plan_id=$planId"
```

Apply requires `demo-apply` approval and matching configuration, catalog, and
environment hashes. If any binding changes, generate and review a new plan.

The consumer's `validate.yml` and catalog's `reusable-validate.yml` run public
validation only. Reusable workflows do not give the consumer access to the
catalog's runner. Maintainer dispatch avoids needing a cross-repository PAT or App
credential.

The private runner reads consumer JSON, not executable consumer source or install
hooks. Application deployment uses a [separately reviewed artifact](https://github.com/mocelj/azure-platform-app-demo/blob/main/docs/web-app-payload.md).

## Checks for the first Azure deployment

These checks remain outstanding. Record the results privately during deployment
and publish a sanitized summary where useful.

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

The [eight platform guides](../README.md#eight-examples-one-developer-contract)
provide the workload commands. Bicep what-if normally needs deployment-equivalent
permissions; `ProviderNoRbac` is not a general permission bypass. Resolve
authorization or connectivity failures within the design rather than enabling
public access, key authentication, or disabled locking.

## Reporting results

Separate CI results from Azure preflight, preview, deployment, health, and cleanup
results. This makes it clear what has been exercised and what is still outstanding.
Keep tokens, real bindings, state, plans, and sensitive raw logs out of public
artifacts.

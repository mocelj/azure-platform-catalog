# Azure platform catalog

**Official Azure Verified Modules are the building blocks. A platform app is the approved product developers consume.**

This catalog composes AVM into eight opinionated examples: Blob Storage, Linux VM, Azure Web App, and Azure Container App, each in Bicep and Terraform. The companion [application repository](https://github.com/mocelj/azure-platform-app-demo) requests them through five-field JSON files. Developers do not supply IaC, networking, identities, or security switches.

> **Implementation boundary:** offline-first demonstration for an FSI audience, not an FSI-compliant or production-ready deployment. Azure deployment, private connectivity, application health, and cleanup require a separately authorized rehearsal. Connected execution stays disabled by default. A skipped job is not evidence of success.

## Start without Azure

Use sibling checkouts named `azure-platform-catalog` and `azure-platform-app-demo`. For release consumption, check out the catalog's reviewed full commit SHA, not a moving branch. Documentation links to `main` are navigation aids, not execution pins.

From this catalog directory, with Node **24.18.0** and npm **11.16.0**:

```powershell
npm ci --ignore-scripts
npm test
npm run check
node scripts/platform.mjs check-consumer --directory ..\azure-platform-app-demo
node scripts/platform.mjs validate --config ..\azure-platform-app-demo\apps\storage\bicep\platform-app.json --target storage-bicep
node scripts/platform.mjs render --config ..\azure-platform-app-demo\apps\storage\bicep\platform-app.json --target storage-bicep --environment environments\demo.example.json --out out\storage-bicep
```

`validate` checks the approved request. `render` produces data files and configuration hashes; it does **not** contact Azure or perform a plan. The example environment is synthetic and must never be used for deployment.

To check IaC with the pinned local tools:

```powershell
node scripts/tooling.mjs
npm run iac:check
```

Tool/module/provider downloads require network access. “Offline” here means **no Azure deployment or private state access**, not an air-gapped dependency restore. Tooling is kept in `.tools`, not installed globally. See [dependencies](docs/dependencies.md) and [validation gates](docs/rehearsal.md).

Pinned Bicep compilation and all four Terraform roots' backend-disabled initialization/validation now have local evidence. Storage, VM, and Web App have nine passing mocked plan runs in total. Container Apps has **no mocked plan coverage**; its evidence is Node source-contract checks plus real Terraform initialization/validation. The [validation guide](docs/rehearsal.md#recorded-local-evidence-and-limits) explains that limitation and accepted VM provider warnings. Publication and hosted CI remain pending; this is not a release claim.

## Eight examples, one developer contract

Each row is a separate target with its own resource group and deployment identity/state key. Do not point both engines at the same resources. Each platform guide includes inputs, outputs, direct consumption, and connected commands.

| Target | Platform-team guide | Developer request |
| --- | --- | --- |
| `storage-bicep` | [Blob Storage / Bicep](examples/platform/storage/bicep/README.md) | [JSON](https://github.com/mocelj/azure-platform-app-demo/blob/main/apps/storage/bicep/platform-app.json) |
| `storage-terraform` | [Blob Storage / Terraform](examples/platform/storage/terraform/README.md) | [JSON](https://github.com/mocelj/azure-platform-app-demo/blob/main/apps/storage/terraform/platform-app.json) |
| `vm-bicep` | [Linux VM / Bicep](examples/platform/vm/bicep/README.md) | [JSON](https://github.com/mocelj/azure-platform-app-demo/blob/main/apps/vm/bicep/platform-app.json) |
| `vm-terraform` | [Linux VM / Terraform](examples/platform/vm/terraform/README.md) | [JSON](https://github.com/mocelj/azure-platform-app-demo/blob/main/apps/vm/terraform/platform-app.json) |
| `web-app-bicep` | [Web App / Bicep](examples/platform/web-app/bicep/README.md) | [JSON](https://github.com/mocelj/azure-platform-app-demo/blob/main/apps/web-app/bicep/platform-app.json) |
| `web-app-terraform` | [Web App / Terraform](examples/platform/web-app/terraform/README.md) | [JSON](https://github.com/mocelj/azure-platform-app-demo/blob/main/apps/web-app/terraform/platform-app.json) |
| `container-app-bicep` | [Container App / Bicep](examples/platform/container-app/bicep/README.md) | [JSON](https://github.com/mocelj/azure-platform-app-demo/blob/main/apps/container-app/bicep/platform-app.json) |
| `container-app-terraform` | [Container App / Terraform](examples/platform/container-app/terraform/README.md) | [JSON](https://github.com/mocelj/azure-platform-app-demo/blob/main/apps/container-app/terraform/platform-app.json) |

The wrapper entrypoints are `platform-apps/<service>/<engine>/main.bicep` or the Terraform root's `main.tf`. The [JSON schema](schemas/platform-app.schema.json), [target catalog](catalog/platform.json), and [implementation contract](catalog/implementation-contract.json) define the interface; wrapper source defines the approved infrastructure.

## The trust boundary

1. A developer proposes a small configuration PR in the consumer.
2. Hosted, credential-free validation checks it against the pinned catalog.
3. A maintainer dispatches **the catalog's** trusted workflow for an exact 40-hex consumer commit already merged into approved `main`. Both plan and apply enforce this; there is no premerge Azure preview.
4. A catalog-only private runner performs the separately enabled plan/apply with OIDC and target serialization. Plans stay in private Blob storage. Apply selects the reviewed `plan_id`, matches configuration/catalog/environment hashes, and requires explicit `demo-apply` environment approval.

The consumer has neither Azure credentials nor access to the private runner. Reusable validation does not move a job into another repository's runner context. Application ZIP deployment is a **separate trusted artifact release**, not execution of a consumer PR on the infrastructure runner.

## Read next

- [Architecture and data flow](docs/architecture.md)
- [Resource modules, platform apps, and team responsibilities](docs/concepts.md)
- [Foundation and existing-foundation mode](docs/foundation.md)
- [Permitted and denied developer PRs](https://github.com/mocelj/azure-platform-app-demo/blob/main/docs/walkthrough.md)
- [Security controls and demo exceptions](docs/security-controls.md)
- [Dependency pins, runtime caveats, and upgrades](docs/dependencies.md)
- [Connected prerequisites and rehearsal evidence](docs/rehearsal.md)
- [Cost drivers, troubleshooting, and careful cleanup](docs/operations.md)
- [Contributing](CONTRIBUTING.md) · [Security reporting](SECURITY.md) · [MIT license](LICENSE)

Original demonstration code is authored by `mocelj`. AVM modules, providers, tools, Actions, and the illustrative container image retain upstream attribution and license terms. AVM provenance does not certify this composition or confer a blanket support SLA.

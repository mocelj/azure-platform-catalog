# Azure platform catalog

[![Catalog validation](https://github.com/mocelj/azure-platform-catalog/actions/workflows/validate.yml/badge.svg)](https://github.com/mocelj/azure-platform-catalog/actions/workflows/validate.yml)

This catalog shows how a platform team can give application teams a small configuration interface while retaining responsibility for Azure infrastructure. It provides Blob Storage, Linux VM, Web App, and Container App configurations in both Bicep and Terraform. All infrastructure is composed from pinned official Azure Verified Modules (AVM).

Application teams request an instance through a five-field JSON file in the companion [application repository](https://github.com/mocelj/azure-platform-app-demo). The catalog supplies the networking, identity, monitoring, sizing, and deployment implementation.

Both repositories have public `v0.1.0` releases with passing CI. No Azure deployment has been performed; the connected workflows remain disabled until the deployment environment is configured. The [security design](docs/security-controls.md) covers the choices that would need adapting for a production or regulated environment.

## Start without Azure

Keep the two checkouts in sibling directories named `azure-platform-catalog` and `azure-platform-app-demo`. Use the catalog commit recorded by the application repository so local checks match CI. Links to `main` throughout these guides are for browsing the source.

From the catalog directory, using Node `24.18.0` and npm `11.16.0`:

```powershell
npm ci --ignore-scripts
npm test
npm run check
node scripts/platform.mjs check-consumer --directory ..\azure-platform-app-demo
node scripts/platform.mjs validate --config ..\azure-platform-app-demo\apps\storage\bicep\platform-app.json --target storage-bicep
node scripts/platform.mjs render --config ..\azure-platform-app-demo\apps\storage\bicep\platform-app.json --target storage-bicep --environment environments\demo.example.json --out out\storage-bicep
```

`validate` checks the request against the schema and target. `render` produces parameter files and configuration hashes without contacting Azure. The example environment supplies placeholder resource IDs for local validation; replace those with your foundation bindings before deployment.

To check IaC with the pinned local tools:

```powershell
node scripts/tooling.mjs
npm run iac:check
```

These checks restore dependencies from public registries but do not access Azure or private Terraform state. The tooling script installs Bicep and Terraform under `.tools`, leaving global installations unchanged. See [dependencies](docs/dependencies.md) and [validation](docs/rehearsal.md) for the supported versions and test coverage.

Bicep compilation and all four Terraform roots pass local and hosted validation. Storage, VM, and Web App also have nine passing mocked plan runs. Container Apps is covered by source checks and Terraform initialization/validation, without mocked plans. The [validation guide](docs/rehearsal.md#recorded-local-evidence-and-limits) explains this limitation and the VM provider warnings. CI does not test live routing, authorization, or application health.

## Eight examples, one developer contract

Each service-engine pair is a separate deployment target, with its own resource group and, for Terraform, state key. The two engines manage independent resources rather than alternative views of the same deployment. The guides below cover the wrapper interface, platform-team usage, and deployment commands.

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

The entrypoints are `platform-apps/<service>/<engine>/main.bicep` or the Terraform root's `main.tf`. The [JSON schema](schemas/platform-app.schema.json), [target catalog](catalog/platform.json), and [implementation contract](catalog/implementation-contract.json) describe the configuration interface; the wrappers implement it.

## From configuration to deployment

A developer submits a configuration PR in the application repository. GitHub-hosted checks validate it against the pinned catalog, without Azure credentials. After merge, a platform maintainer dispatches the catalog workflow with the target and the consumer's full 40-character commit SHA. Both plan and apply require a commit on `main`; PRs do not trigger Azure previews.

Connected jobs run on a private runner registered only to the catalog, using Entra federation through OIDC. Plans are stored in private Blob storage. Apply uses the reviewed `plan_id`, checks the configuration, catalog, and environment hashes, and waits for approval in `demo-apply`.

This separation keeps consumer code off the infrastructure runner. The application repository has no Azure identity or private-runner access, including through reusable workflows. Web App content follows a separate build and ZIP-release process.

## Read next

- [Architecture and data flow](docs/architecture.md)
- [Resource modules, platform apps, and team responsibilities](docs/concepts.md)
- [Foundation and existing-foundation mode](docs/foundation.md)
- [Configuration changes and PR workflow](https://github.com/mocelj/azure-platform-app-demo/blob/main/docs/walkthrough.md)
- [Security controls and demo exceptions](docs/security-controls.md)
- [Dependency pins, runtime caveats, and upgrades](docs/dependencies.md)
- [Validation and deployment preparation](docs/rehearsal.md)
- [Cost drivers, troubleshooting, and cleanup](docs/operations.md)
- [Contributing](CONTRIBUTING.md) · [Security reporting](SECURITY.md) · [MIT license](LICENSE)

The wrappers and documentation are original work by `mocelj`, licensed under MIT. AVM modules, providers, tools, Actions, and images retain their upstream licenses. Microsoft attribution applies to the underlying services and official modules, not authorship or support of these wrappers.

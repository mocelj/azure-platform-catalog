# Dependencies and upgrades

The catalog fixes module, provider, tool, and image versions so a configuration can be reproduced and changes can be reviewed together. Security assessment and regional availability checks are separate from version selection.

## Toolchain

The toolchain is recorded in [`catalog/toolchain.json`](../catalog/toolchain.json).

| Component | Pin |
| --- | --- |
| Node.js | `24.18.0` |
| npm | `11.16.0` |
| Azure CLI | `2.88.0` |
| Bicep | `0.47.16` |
| Terraform | `1.13.5` |
| Hosted runner label | `ubuntu-24.04` |
| JSON validation | `ajv` `8.17.1` |
| YAML parsing | `yaml` `2.8.1` |

The hosted runner image changes over time, even with a fixed OS label, so tooling is versioned separately. `node scripts/tooling.mjs` installs Bicep and Terraform locally using URLs and checksums from the [artifact manifest](../catalog/tool-artifacts.json). Node, npm, and Azure CLI are prerequisites rather than part of that installer.

Use `npm ci --ignore-scripts` with the committed lock file. This keeps local validation aligned with CI and avoids running dependency install hooks.

## Workload AVM baseline

Bicep references use `br/public:avm/res/<path>:<version>`. Terraform references use `Azure/<module>/azurerm` with an exact `version`.

| Capability | Bicep AVM | Terraform AVM |
| --- | --- | --- |
| Blob Storage | `storage/storage-account:0.33.1` | `avm-res-storage-storageaccount` `0.10.0` |
| Linux VM | `compute/virtual-machine:0.22.3` | `avm-res-compute-virtualmachine` `0.21.0` |
| Web App | `web/site:0.24.0` | `avm-res-web-site` `0.23.0` |
| App Service plan | `web/serverfarm:0.7.0` | `avm-res-web-serverfarm` `2.0.8` |
| Container App | `app/container-app:0.23.0` | `avm-res-app-containerapp` `0.9.0` |
| Container Apps environment | `app/managed-environment:0.16.0` | `avm-res-app-managedenvironment` `0.5.0` |
| Separate Container Apps private endpoint | Integrated environment module interface | `avm-res-network-privateendpoint` `0.2.0` |

The [platform examples](../README.md#eight-examples-one-developer-contract) use these wrappers directly; the shared [foundation](foundation.md) is implemented only in Bicep. The records under [`catalog`](../catalog) include the transitive modules and local submodules that are not visible in this top-level table.

The provider set is AzureRM `4.81.0`, AzAPI `2.12.0`, modtm `0.3.5`, random `3.9.1`, time `0.14.2`, and tls `4.4.1`, where required by each root. Committed `.terraform.lock.hcl` files include supported-platform checksums, and normal initialization uses read-only locks.

Terraform locks providers, not module packages. The catalog therefore records the resolved module graph, release commits, and content hashes where available, and checks for drift separately. A version tag identifies a release but is not, on its own, a content-integrity check.

## Known validation limits

The VM AVM emits provider deprecation warnings with this provider set. Initialization and validation succeed; the warnings remain in the output and should be reviewed when upgrading AVM or AzureRM.

Container Apps has no mocked plan coverage for its environment, app, or private endpoint. Terraform `1.13.5` cannot handle an ephemeral resource schema in the upstream environment module, including when that resource has `count = 0`. Its coverage is limited to Node source-contract checks and real backend-disabled initialization/validation. `npm run iac:check` reports this limitation. Storage, VM, and Web App each have three passing mocked plan runs; the [validation guide](rehearsal.md) explains how to run them.

## APIs, images, and runtimes

- Terraform Container Apps uses environment API `2025-10-02-preview` and app API `2025-02-02-preview`. These previews are accepted for this example and need reassessment for production. The full API inventory also covers transitive modules.
- Bicep API versions come from restored modules; AzAPI declares versions directly. AzureRM chooses APIs through its provider implementation rather than a wrapper input.
- Both VM implementations use `Canonical:ubuntu-24_04-lts:server:24.04.202609040` (x64, Hyper-V V2), recorded in [`platform.json`](../catalog/platform.json). Before deployment, check current Sweden Central availability, capacity, Trusted Launch compatibility, terms, and image lifecycle.
- Container App uses `mcr.microsoft.com/azuredocs/containerapps-helloworld@sha256:e9b3e7c34664c7cffd7144864b0e4eec369bfde80068f9095dc63b37058bec48` on port `80`. It is an older Microsoft sample image, suitable for illustrating connectivity rather than a hardened production application. A production image needs its own provenance, vulnerability, and lifecycle controls. The registry also needs outbound reachability.
- Web App uses `NODE|24-lts`, whose patches are managed by Azure. The local Node `24.18.0` and sample `0.1.0` versions do not fix the Azure runtime patch. This Node source is separate from the Container App image.

## Upgrade process

1. Open a platform PR identifying the dependency, runtime, or image change and affected targets.
2. Review release notes, licenses, security advisories, provenance, APIs, transitive modules, and provider compatibility.
3. Update references, dependency records, Action commit SHAs, and provider locks together, including checksums for supported platforms.
4. Run contract and source checks, Bicep builds, Terraform format/init/validate, and supported mock suites. Keep the Container Apps coverage limitation visible unless it has been resolved and tested.
5. Review replacements, changed defaults, permissions, previews, costs, and runtime behavior before scheduling Azure validation.
6. Use the [connected checks](rehearsal.md) to verify deployment behavior where required. Keep plans and sensitive results private.
7. Release the catalog after review and passing CI. Update the consumer's version metadata and full catalog commit in a separate platform-reviewed PR.

A dependency rollback also needs a state and resource compatibility review. Reverting a version alone may not reverse an infrastructure change, and switching engines is a migration rather than a rollback technique.

## Attribution

The wrappers and documentation are original work by `mocelj` under MIT. They reference official AVM releases without modifying upstream source. Microsoft attribution applies to the Azure services and official modules; each dependency retains its own license and support terms.

- [Official Azure Verified Modules catalog](https://azure.github.io/Azure-Verified-Modules/)
- [Bicep AVM source](https://github.com/Azure/bicep-registry-modules)
- [Terraform AVM resource modules](https://azure.github.io/Azure-Verified-Modules/indexes/terraform/tf-resource-modules/)
- [Terraform dependency lock semantics](https://developer.hashicorp.com/terraform/language/files/dependency-lock)
- [AzureRM backend Entra/OIDC authentication](https://developer.hashicorp.com/terraform/language/backend/azurerm)

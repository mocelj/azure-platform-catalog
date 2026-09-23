# Dependencies and upgrades

Pins define a reviewable compatibility baseline. They do not prove upstream immutability, absence of vulnerabilities, Azure availability, support entitlement, or successful deployment.

## Toolchain

[`catalog/toolchain.json`](../catalog/toolchain.json) is authoritative.

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

The runner label is **not an immutable operating-system image**. Independently verify the installed tool versions. The [tool artifact manifest](../catalog/tool-artifacts.json) supplies download URLs and checksums for local Bicep/Terraform setup through `node scripts/tooling.mjs`. Node/npm/Azure CLI must meet their own declared prerequisites; the installer does not install everything.

Use `npm ci --ignore-scripts` with the committed lock. Do not use an unreviewed floating `npx` tool or install an arbitrary version to make checks pass.

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

The workload wrapper and its [platform example](../README.md#eight-examples-one-developer-contract) are the direct-consumption sources. The shared [foundation](foundation.md) is Bicep-only. Consult the full provenance/compatibility records in [`catalog`](../catalog), not just this top-level table: upstream modules can themselves reference exact AVM utility/resource modules and local submodules.

Provider pins are AzureRM **4.81.0**, AzAPI **2.12.0**, modtm **0.3.5**, random **3.9.1**, time **0.14.2**, and tls **4.4.1**, only where required by the resolved graph. Each runnable Terraform root needs its committed `.terraform.lock.hcl`, with checksums for supported execution platforms. Normal initialization uses read-only locks.

**Terraform's provider lock does not lock module packages.** Audit the full module closure, record upstream release commits/content hashes where available, and detect dependency drift separately. Exact version tags alone are not a content-integrity guarantee. Never introduce `latest`, floating module refs, or unreviewed automatic upgrades.

## Known validation limits

The pinned upstream VM AVM emits provider deprecation warnings with the selected provider graph. Terraform initialization/validation succeeds with these accepted demo warnings; it is not warning-free. Keep the warnings visible in evidence and review them with a deliberate AVM/provider upgrade rather than editing upstream modules or changing pins implicitly.

Terraform `1.13.5` rejects the upstream Container Apps ephemeral resource's mock schema even at `count = 0`; `override_module` did not bypass it. The unsupported Container Apps `.tftest.hcl` file was removed. There is **no mocked environment, app, or private-endpoint coverage** for this root: only explicit Node source-contract invariants and real backend-disabled Terraform initialization/validation. `npm run iac:check` prints the limitation explicitly. The other three services have three passing mocked plan runs each, nine in total. See the [validation guide](rehearsal.md) for the exact coverage boundary and explicit example-variable-file command for those supported suites.

## APIs, images, and runtimes

- The known Terraform Container Apps environment API is `2025-10-02-preview`; Container App uses `2025-02-02-preview`. These accepted **demo exceptions** require review at each release. The complete restored graph can contain additional previews.
- Bicep API versions come from restored module artifacts; AzAPI declares its versions directly. AzureRM-selected APIs are determined by the exact provider version rather than a wrapper-level API selector.
- The approved VM image is `Canonical:ubuntu-24_04-lts:server:24.04.202609040` (x64, Hyper-V V2), recorded in [`platform.json`](../catalog/platform.json). Both engines must use that exact version, not `latest`. Its recorded read-only availability evidence is not deployment evidence. Recheck availability in `swedencentral`, SKU capacity, Trusted Launch compatibility, terms, and lifecycle before a connected run. Do not substitute another image silently.
- Container App uses `mcr.microsoft.com/azuredocs/containerapps-helloworld@sha256:e9b3e7c34664c7cffd7144864b0e4eec369bfde80068f9095dc63b37058bec48`, port **80**, from [`platform.json`](../catalog/platform.json). The image is old and illustrative. Its digest is not a hardening, vulnerability, authenticity, or support claim. Registry access is part of demo egress.
- Web App uses native **`NODE|24-lts`**; Azure manages its patch lifecycle. Exact local Node **24.18.0** and sample **0.1.0** pins do not freeze Azure's runtime patch. The dependency-free sample is not bundled into the Container App image.

## Deliberate upgrade process

1. Open a platform-owned change describing the dependency/runtime/image being changed and affected targets.
2. Review official release notes, license, provenance, hashes, APIs, transitive module refs, provider constraints, and security advisories. Stop if the graph cannot meet the pinning contract.
3. Update exact references, compatibility records, Actions' full SHAs, and supporting pins together. Generate provider locks in the controlled upgrade environment, including supported platform checksums.
4. Run contract tests, negative-control tests, source-policy checks, all affected Bicep builds and Terraform format/init/validate checks, plus supported mock suites. Preserve the explicit Container Apps mock exclusion unless a verified compatible solution restores coverage. Inspect generated/planned controls rather than trusting version labels.
5. Review any replacements, changed defaults, new privileges, previews, costs, or runtime behavior. Do not conflate an offline green result with live compatibility.
6. Complete the separately authorized [connected gates](rehearsal.md) before describing a release as rehearsed. Record limitations and private evidence without publishing state/plans.
7. Publish only after release review. Update the consumer's release metadata and full immutable catalog commit pin in a separate platform-reviewed PR. A tag alone is not the execution trust anchor.

Rollback must consider state/resource compatibility; changing a pin back is not necessarily a safe infrastructure rollback. Never hand-edit state or switch engines as a shortcut.

## Attribution

These are original demo wrappers and documentation, MIT-licensed by `mocelj`, referencing official AVM releases. Microsoft attribution applies to the underlying Azure services and official module sources, not authorship of these wrappers. Upstream AVM code/references are not modified to bypass checks or suppress warnings; upstream artifacts retain their licenses. No Microsoft endorsement or upstream ownership is claimed.

- [Official Azure Verified Modules catalog](https://azure.github.io/Azure-Verified-Modules/)
- [Bicep AVM source](https://github.com/Azure/bicep-registry-modules)
- [Terraform AVM resource modules](https://azure.github.io/Azure-Verified-Modules/indexes/terraform/tf-resource-modules/)
- [Terraform dependency lock semantics](https://developer.hashicorp.com/terraform/language/files/dependency-lock)
- [AzureRM backend Entra/OIDC authentication](https://developer.hashicorp.com/terraform/language/backend/azurerm)

# Storage — platform-team Bicep example

This is an offline example, **not a live-deployment record**. Developers select
the catalog application, name, and size; only the platform team supplies network,
monitoring, resource-group and tag bindings. All resources are created inside
`avm/res/storage/storage-account:0.33.1`, including its integrated blob private
endpoint. Dependency source links and upstream API versions are recorded in
`catalog\bicep-dependencies.json`.

Validation on 2026-09-23: Bicep 0.47.16 restored and compiled this wrapper and its
parameter example without warnings or errors. All 13 workload contract tests
passed. This does not establish Azure deployment or runtime success.

## Fixed contract and prerequisites

- Sweden Central only. `small` uses `Standard_LRS`; `medium` uses `Standard_ZRS`.
  This is a redundancy choice, not a storage-capacity limit.
- Existing isolated workload resource group, private-endpoint subnet, VNet-linked
  `privatelink.blob.core.windows.net` private DNS zone, and Log Analytics workspace.
- Public network access, Shared Key, anonymous blobs, SFTP and local users are
  disabled. TLS 1.2+, HTTPS only, infrastructure encryption, system identity,
  seven-day blob/container soft deletion and blob versioning are enforced.
- Account metrics and blob logs/metrics are sent to the supplied workspace.
  Azure Monitor connectivity is the documented demo public-egress exception.
- A trusted private runner/client must resolve the blob FQDN to the endpoint's
  private IP. Data-plane callers need explicitly assigned Entra data roles;
  the wrapper deliberately does not grant broad data access or export keys.
- Storage names are deterministically derived and globally unique. Mandatory
  `platform`, `environment`, `workload` and `engine` tags override supplied values.

## Platform-team commands

Run from the catalog repository root with the pinned Bicep 0.47.16 and Azure CLI
2.88.0 from `catalog\toolchain.json`. Replace the synthetic resource IDs in a
platform-owned copy of `main.bicepparam`; never deploy the fixture unchanged.
`BICEP_EXE` points to the verified local executable.

```powershell
$bicep = $env:BICEP_EXE
$template = 'platform-apps\storage\bicep\main.bicep'
$parameters = 'examples\platform\storage\bicep\main.bicepparam'
& $bicep restore $template
& $bicep build $template --outfile 'examples\platform\storage\bicep\main.generated.json'
& $bicep build-params $parameters --outfile 'examples\platform\storage\bicep\parameters.generated.json'
az account show --query '{subscription:id,tenant:tenantId}' --output json
# Set only after confirming the dedicated, platform-owned workload RG.
$resourceGroup = 'rg-demo-storage-bicep'
az deployment group what-if --resource-group $resourceGroup --template-file 'examples\platform\storage\bicep\main.generated.json' --parameters '@examples\platform\storage\bicep\parameters.generated.json'
# Separate approved write step; never run automatically from a consumer request.
az deployment group create --resource-group $resourceGroup --template-file 'examples\platform\storage\bicep\main.generated.json' --parameters '@examples\platform\storage\bicep\parameters.generated.json'
```

Review the what-if before the platform-controlled approval/deploy step. Compilation
does not verify region capacity, RBAC, DNS, endpoint approval or runtime connectivity.
Validate Entra-authenticated blob access from the private client and reject access
from a public client without briefly opening the account.

## Cleanup

Export required data and retain evidence first. After explicit platform approval,
delete only the dedicated workload resource group:
`az group delete --name rg-demo-storage-bicep` (interactive confirmation retained).
This deletes stored data and the workload PE, not the shared VNet/DNS/workspace.
Do not delete shared resources while other workloads depend on them. Remove the
two local `*.generated.json` validation artifacts when finished.

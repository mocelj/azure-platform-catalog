# Blob Storage with Bicep

This example calls the local storage wrapper, which uses
`avm/res/storage/storage-account:0.33.1` for the account and integrated Blob
private endpoint. The platform team supplies the resource group, network, DNS,
workspace, and tags; the developer selects the application name and size.
Dependency and API records are in `catalog\bicep-dependencies.json`.

## Configuration and prerequisites

The deployment is scoped to Sweden Central. `small` selects `Standard_LRS` and
`medium` selects `Standard_ZRS`; for Storage, size represents redundancy rather
than a capacity limit.

Provide a dedicated workload resource group, private-endpoint subnet,
VNet-linked `privatelink.blob.core.windows.net` zone, and Log Analytics workspace.
The client and runner must resolve the Blob hostname to its private IP. Entra
data roles are assigned separately from resource-management permissions; the
wrapper does not grant broad data access or return keys.

The account requires HTTPS/TLS 1.2 or later, with public network access, Shared
Key, anonymous blobs, SFTP, and local users disabled. It enables infrastructure
encryption, system identity, versioning, and seven-day Blob/container soft delete.
Account metrics and Blob diagnostics use the supplied workspace over the public
Azure Monitor path described in the [security design](../../../../docs/security-controls.md).

Names are derived for global uniqueness. Catalog tags take precedence over
conflicting `platform`, `environment`, `workload`, and `engine` values.

## Platform-team commands

Run from the catalog root with Bicep `0.47.16` and Azure CLI `2.88.0`.
Set `BICEP_EXE` to the local compiler. The checked-in parameters are for
compilation; before using the Azure commands, replace the resource IDs in a
private copy and confirm the target resource group.

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

Review what-if before deployment. Afterwards, check endpoint approval, private
DNS, Entra-authorized Blob access, and denial from a public client while leaving
public access disabled. Compilation and contract tests pass; Azure deployment
and these connectivity checks have not yet been performed.

## Cleanup

Export any data that must be retained, then review deletion of the workload group:
`az group delete --name rg-demo-storage-bicep` (interactive confirmation retained).
This removes stored data and the workload private endpoint. Keep the shared
VNet, DNS, and workspace for other workloads. The two local generated JSON files
can be removed after validation.

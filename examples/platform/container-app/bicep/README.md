# Private Container App — platform-team Bicep example

This is an **offline example; no live deployment was performed**. Every resource
is inside `avm/res/app/managed-environment:0.16.0` or
`avm/res/app/container-app:0.23.0`, including the environment private endpoint.

Validation on 2026-09-23: Bicep 0.47.16 restored and compiled this wrapper and its
parameter example without warnings or errors. All 13 workload contract tests
passed. This does not establish Azure deployment or runtime success.

## Fixed contract and prerequisites

- Sweden Central only. Workload-profiles environment with a `Consumption`
  profile. `small` = 0.25 vCPU / 0.5 GiB, max 2 replicas; `medium` = 0.5 vCPU /
  1 GiB, max 3. Minimum replicas is zero; expect cold starts.
- Existing dedicated workload RG, a **dedicated** `/27` or larger subnet delegated
  to `Microsoft.App/environments` for this Bicep environment, and a separate
  nondelegated private-endpoint subnet. Never share the infrastructure subnet
  with the Terraform environment. Platform NSG/routes/NAT must allow required
  Container Apps control-plane, registry and Azure Monitor dependencies.
- Link `privatelink.swedencentral.azurecontainerapps.io` to the caller VNet.
  The existing zone ID and Log Analytics workspace ID are platform-owned inputs.
- The environment is VNet-injected with `internal: false`,
  `publicNetworkAccess: 'Disabled'` and an **actual integrated private endpoint**.
  It is not an internal-load-balancer-only environment mislabeled as Private Link.
  Azure can maintain a platform public load-balancer address while public
  application access remains disabled.
- App `ingressExternal: true` permits callers outside the environment through
  the environment PE; it does not bypass disabled public network access.
  Insecure ingress is disabled and HTTP redirects to HTTPS.
- Both app/environment have system identities; peer traffic is encrypted.
  Environment logs use `azure-monitor` plus diagnostic settings to the supplied
  workspace. App metrics use diagnostic settings. No workspace shared keys,
  registry credentials or runtime secrets are passed or output.
- The exact hello-world image digest and port are loaded at compile time from
  `catalog\platform.json`; developers cannot override them. The Microsoft sample
  image is illustrative, not an FSI-hardened production workload. Azure Monitor
  public connectivity and NAT-not-firewall limitations remain demo exceptions.
- Mandatory catalog tags override caller values; AVM telemetry is disabled.

## Platform-team commands

From repository root with pinned tools in `catalog\toolchain.json`, set
`BICEP_EXE` to the verified local executable. Replace synthetic resource IDs in a
platform-owned parameter copy; do not deploy the fixture unchanged.

```powershell
$bicep = $env:BICEP_EXE
& $bicep restore 'platform-apps\container-app\bicep\main.bicep'
& $bicep build 'platform-apps\container-app\bicep\main.bicep' --outfile 'examples\platform\container-app\bicep\main.generated.json'
& $bicep build-params 'examples\platform\container-app\bicep\main.bicepparam' --outfile 'examples\platform\container-app\bicep\parameters.generated.json'
az account show --query '{subscription:id,tenant:tenantId}' --output json
$resourceGroup = 'rg-demo-container-app-bicep'
az deployment group what-if --resource-group $resourceGroup --template-file 'examples\platform\container-app\bicep\main.generated.json' --parameters '@examples\platform\container-app\bicep\parameters.generated.json'
# Execute only after the separate platform approval and what-if review.
az deployment group create --resource-group $resourceGroup --template-file 'examples\platform\container-app\bicep\main.generated.json' --parameters '@examples\platform\container-app\bicep\parameters.generated.json'
```

Check endpoint approval, private DNS resolution, private HTTPS success and public
rejection after an authorized deployment. Offline compilation does not prove
capacity, RBAC, connectivity or logs delivery. Review source/API evidence in
`catalog\bicep-dependencies.json` before accepting upstream preview APIs.

## Cleanup

Retain diagnostics/evidence and obtain explicit approval before
`az group delete --name rg-demo-container-app-bicep` (confirmation retained).
Container Apps also owns a managed infrastructure resource group; confirm Azure
cleans it up after environment deletion, rather than manually deleting its
managed resources. Preserve the shared VNet, subnets, DNS and workspace.
Remove local `main.generated.json` and `parameters.generated.json` after validation.

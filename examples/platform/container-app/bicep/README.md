# Private Container App with Bicep

The wrapper composes `avm/res/app/managed-environment:0.16.0` and
`avm/res/app/container-app:0.23.0`. The environment module includes the private
endpoint, so no separate resource implementation is needed.

## Configuration and prerequisites

The Sweden Central environment uses workload profiles with a `Consumption`
profile. `small` provides 0.25 vCPU / 0.5 GiB and up to two replicas;
`medium` provides 0.5 vCPU / 1 GiB and up to three. Both can scale to zero,
with the associated cold-start behavior.

Provide a dedicated workload group, an infrastructure subnet of at least `/27`
delegated to `Microsoft.App/environments`, and a separate nondelegated endpoint
subnet. The infrastructure subnet is exclusive to this environment, not shared
with the Terraform target. Its NSG/routes/NAT need to support Container Apps
management, registry, and monitoring traffic.

Link `privatelink.swedencentral.azurecontainerapps.io` to the client VNet and
supply that zone's ID and the workspace ID. The environment uses `internal: false`
with `publicNetworkAccess: 'Disabled'` and Private Link. Azure can retain a
platform public load-balancer address while public application access is disabled.
App `ingressExternal: true` allows callers outside the environment to reach it
through the private endpoint. Insecure ingress is off, with HTTP redirected to
HTTPS.

The app and environment have system identities, and peer traffic is encrypted.
Environment logs use `azure-monitor` and diagnostics to the workspace; app metrics
also use diagnostics. No workspace shared keys, registry credentials, or runtime
secrets are passed or returned.

The image digest and port come from `catalog\platform.json`. This is an older
Microsoft hello-world image for demonstrating connectivity, not a hardened
production payload. Public Monitor connectivity and NAT without destination
filtering are described in the [security design](../../../../docs/security-controls.md).
Catalog tags take precedence, and AVM telemetry is disabled.

## Platform-team commands

From the catalog root, use the tools in `catalog\toolchain.json` and set
`BICEP_EXE` to the local compiler. Replace the example resource IDs in a private
parameter copy before the Azure commands.

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

The wrapper and parameter example compile without warnings. Azure deployment
remains to be tested, including endpoint approval, DNS, private HTTPS, denial
from public clients, and log delivery. Review the preview APIs recorded in
`catalog\bicep-dependencies.json` during deployment preparation.

## Cleanup

After reviewing retention and the workload inventory, use
`az group delete --name rg-demo-container-app-bicep` (confirmation retained).
Container Apps owns a managed infrastructure group as well. Check that Azure
removes it when the environment is deleted rather than deleting its managed
resources individually. Retain the shared VNet, subnets, DNS, and workspace.
Local `main.generated.json` and `parameters.generated.json` can be removed after
validation.

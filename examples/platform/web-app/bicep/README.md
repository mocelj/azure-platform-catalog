# Private Linux Web App with Bicep

This wrapper combines `avm/res/web/serverfarm:0.7.0` and
`avm/res/web/site:0.24.0`. The site module manages its private endpoint,
publishing policies, identity, and diagnostics.

## Configuration and prerequisites

The plan runs one Linux worker in Sweden Central: B1 for `small`, B2 for `medium`.
Basic is the lowest tier used here for Private Link and VNet integration;
F1/D1 are not supported by this composition.

Provide a dedicated resource group, Log Analytics workspace, and
VNet-linked `privatelink.azurewebsites.net` zone. Inbound Private Link uses a
nondelegated endpoint subnet; outbound VNet integration uses a separate subnet
delegated to `Microsoft.Web/serverFarms`. The DNS zone group supplies both site
and SCM/Kudu records. Check both names from the release host.

Public access, FTPS, and FTP/SCM basic publishing are disabled. The site requires
HTTPS and TLS 1.2 or later on both site and SCM. All outbound traffic uses VNet
integration and its NSG/routes/NAT. NAT supplies connectivity, not destination
filtering. Site logs/metrics and plan metrics use the workspace over the public
Azure Monitor path.

The runtime is `NODE|24-lts`, with `node server.js` as the startup command.
Azure manages runtime patches; check channel availability with
`az webapp list-runtimes --os linux` during deployment preparation. The wrapper
creates the hosting resources, while the
[application release](https://github.com/mocelj/azure-platform-app-demo/blob/main/docs/web-app-payload.md)
builds the payload separately and uploads a reviewed ZIP over private SCM using
Entra authentication. Consumer builds and install hooks stay off the infrastructure
runner. Catalog tags take precedence, and AVM telemetry is disabled.

## Platform-team commands

From the catalog root, use the versions in `catalog\toolchain.json` and set
`BICEP_EXE` to the local compiler. Replace the example resource IDs in a private
parameter copy before what-if or deployment.

```powershell
$bicep = $env:BICEP_EXE
& $bicep restore 'platform-apps\web-app\bicep\main.bicep'
& $bicep build 'platform-apps\web-app\bicep\main.bicep' --outfile 'examples\platform\web-app\bicep\main.generated.json'
& $bicep build-params 'examples\platform\web-app\bicep\main.bicepparam' --outfile 'examples\platform\web-app\bicep\parameters.generated.json'
az account show --query '{subscription:id,tenant:tenantId}' --output json
$resourceGroup = 'rg-demo-web-app-bicep'
az deployment group what-if --resource-group $resourceGroup --template-file 'examples\platform\web-app\bicep\main.generated.json' --parameters '@examples\platform\web-app\bicep\parameters.generated.json'
# Only after separate platform approval and what-if review:
az deployment group create --resource-group $resourceGroup --template-file 'examples\platform\web-app\bicep\main.generated.json' --parameters '@examples\platform\web-app\bicep\parameters.generated.json'
```

Compilation and contract checks pass; Azure deployment has not been performed.
After releasing the payload, test private HTTPS and denial from a public client
without changing the access settings. Check SCM reachability and diagnostics
separately. `catalog\bicep-dependencies.json` records upstream APIs, including the
diagnostic-settings preview.

## Cleanup

After reviewing retention and the resources in the workload group, use:
`az group delete --name rg-demo-web-app-bicep` (keep interactive confirmation).
Remove the app, its plan, and private endpoint, while retaining shared subnets,
DNS, and workspace. Local `main.generated.json` and `parameters.generated.json`
can be removed after validation.

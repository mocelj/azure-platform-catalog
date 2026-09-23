# Private Linux Web App — platform-team Bicep example

This example is **offline validated, not live deployed**. It composes only
`avm/res/web/serverfarm:0.7.0` and `avm/res/web/site:0.24.0`. The site AVM owns its
private endpoint, publishing policies, identity and diagnostics.

Validation on 2026-09-23: Bicep 0.47.16 restored and compiled this wrapper and its
parameter example without warnings or errors. All 13 workload contract tests
passed. This does not establish Azure deployment or runtime success.

## Fixed contract and prerequisites

- Sweden Central only. A single Linux Basic B1 worker (`small`) or B2 worker
  (`medium`) is the fixed plan mapping. B1 is the smallest tier compatible with
  this private-endpoint/VNet-integration composition; F1/D1 are not supported.
- Separate subnets are mandatory: a nondelegated PE subnet for inbound Private
  Link, plus a dedicated `Microsoft.Web/serverFarms` delegated integration subnet
  for outbound traffic. Integrating a VNet alone does **not** make inbound private.
- Existing dedicated workload RG, VNet-linked `privatelink.azurewebsites.net`
  zone and Log Analytics workspace. Verify private DNS resolves **both** the app
  and its SCM/Kudu hostname; the AVM PE DNS-zone group supplies the records.
- Public network access is disabled, HTTPS required, site and SCM minimum TLS 1.2,
  FTPS disabled, FTP/SCM basic publishing credentials disabled. Entra-authenticated
  deployment must run from an approved private release host.
- All outbound traffic is routed through the integration subnet. The platform
  controls subnet NSG/routes/NAT; NAT is **not** a destination-filtering firewall.
- System identity, app logs/metrics and plan metrics target the supplied workspace.
  Azure Monitor public connectivity is an explicit demo exception.
- `NODE|24-lts` is the Azure-managed Node 24 LTS **patch channel**, not an exact
  Node binary pin. Azure updates runtime patches. Confirm channel availability
  using `az webapp list-runtimes --os linux` before the live platform approval.
  The startup command is `node server.js`.
- The wrapper provisions hosting only. A dependency-free trusted Node payload is
  released separately via Entra-authenticated ZIP deployment. Do not run consumer
  source, build hooks, `npm install`, or untrusted archives on the infrastructure
  runner. Use the platform's trusted-release process; do not re-enable basic auth.
- Required catalog tags cannot be overridden; AVM telemetry is disabled.

## Platform-team commands

From repository root, use pinned Bicep/Azure CLI in `catalog\toolchain.json`.
Set `BICEP_EXE` to the verified local executable. Replace fixture resource IDs in
a platform-owned copy before what-if; the checked-in sample is not a live binding.

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

After the trusted payload release, verify HTTPS privately and rejection publicly;
never toggle public access for testing. Compilation cannot prove DNS, private SCM
reachability, SKU capacity, RBAC or runtime availability. Dependency/API evidence,
including upstream diagnostic-settings preview API, is in
`catalog\bicep-dependencies.json`.

## Cleanup

After evidence retention and explicit approval:
`az group delete --name rg-demo-web-app-bicep` (keep interactive confirmation).
Only the dedicated workload group should be removed, including the app, plan and
PE. Preserve the shared delegated subnet, PE subnet, DNS zone and workspace.
Remove local `main.generated.json` and `parameters.generated.json` when finished.

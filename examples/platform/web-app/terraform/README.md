# Run the private Web App Terraform example

See [the Web App contract](../../../../platform-apps/web-app/terraform/README.md).
The `.example.tfvars.json` is synthetic. Bind it to the approved site PE subnet,
site/SCM private DNS, separate delegated integration subnet with NAT, and
workspace. B1/B2 Linux plans are deliberately small demo tiers.

From the catalog root:

```powershell
$Tf = (Resolve-Path .\.tools\terraform.exe).Path # verified Terraform 1.13.5
$Root = (Resolve-Path .\platform-apps\web-app\terraform).Path
& $Tf "-chdir=$Root" fmt -check
& $Tf "-chdir=$Root" init -backend=false -input=false -lockfile=readonly
& $Tf "-chdir=$Root" validate
& $Tf "-chdir=$Root" test "-var-file=../../../examples/platform/web-app/terraform/.example.tfvars.json"
```

These checks are offline except public dependency downloads, not Azure
deployments. The trusted application release is separate: reviewed
dependency-free `server.js` ZIP, Entra deployment and **private SCM** connectivity.
Basic publishing stays disabled. Never execute consumer build scripts on the
privileged infrastructure runner. `NODE|24-lts` receives Azure-managed patches.

## Future approved Entra/OIDC backend setup

Use the existing isolated runner with private Blob networking/DNS. It needs
state-container-scoped `Storage Blob Data Contributor`, separately from workload
resource permissions. The approved workflow supplies `ARM_CLIENT_ID`,
`ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID` and OIDC request variables (`id-token: write`).

```powershell
$env:ARM_USE_OIDC = "true"
$env:ARM_USE_AZUREAD = "true"
$State = Get-Content .\environments\demo.local.json -Raw | ConvertFrom-Json
& $Tf "-chdir=$Root" init -reconfigure -input=false -lockfile=readonly `
  "-backend-config=resource_group_name=$($State.state.resourceGroupName)" `
  "-backend-config=storage_account_name=$($State.state.storageAccountName)" `
  "-backend-config=container_name=$($State.state.containerName)" `
  "-backend-config=key=demo/web-app-terraform/webtf.tfstate" `
  "-backend-config=use_oidc=true" "-backend-config=use_azuread_auth=true" `
  "-backend-config=client_id=$env:ARM_CLIENT_ID" `
  "-backend-config=tenant_id=$env:ARM_TENANT_ID" `
  "-backend-config=subscription_id=$env:ARM_SUBSCRIPTION_ID"
```

The binding is platform-owned local metadata; use approved rendered tfvars in
the separate connected plan/apply workflow. Do not disable state locking, expose
public endpoints or fall back to keys/SAS. Saved plans/state remain private.
Cleanup requires a reviewed target-only destroy plan that removes both site
and its billable dedicated service plan, preserving foundation and other targets.

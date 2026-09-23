# Private Web App with Terraform

This example uses the [Web App root](../../../../platform-apps/web-app/terraform/README.md)
with a B1 or B2 Linux plan. The example variable file contains placeholders.
For deployment, supply the endpoint subnet, site/SCM DNS zone, separate
delegated integration subnet with NAT, and workspace IDs.

## Local validation

From the catalog root:

```powershell
$Tf = (Resolve-Path .\.tools\terraform.exe).Path # verified Terraform 1.13.5
$Root = (Resolve-Path .\platform-apps\web-app\terraform).Path
& $Tf "-chdir=$Root" fmt -check
& $Tf "-chdir=$Root" init -backend=false -input=false -lockfile=readonly
& $Tf "-chdir=$Root" validate
& $Tf "-chdir=$Root" test "-var-file=../../../examples/platform/web-app/terraform/.example.tfvars.json"
```

The commands restore dependencies and validate configuration without deploying.
Application content is released separately as a reviewed `server.js` ZIP over
private SCM using Entra authentication. Basic publishing remains disabled, and
consumer builds run outside the infrastructure runner. App Service manages
patches within the configured `NODE|24-lts` runtime family.

## Connect to the private backend

Use the existing private runner with Blob networking/DNS. It needs
`Storage Blob Data Contributor` on the state container, in addition to workload
resource permissions. The catalog workflow supplies `ARM_CLIENT_ID`,
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

Keep the environment binding local and use the
[catalog plan/apply workflow](../../../../docs/rehearsal.md#maintainer-handoff)
with rendered variables. The private backend uses Entra authorization and locking;
state and saved plans stay out of public artifacts.

## Cleanup

Review a destroy plan that removes both the site and its dedicated App Service
plan. The plan remains billable even when the sample has no traffic. Preserve
shared infrastructure and the other targets.

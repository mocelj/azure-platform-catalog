# Blob Storage with Terraform

This example runs the catalog's [storage root](../../../../platform-apps/storage/terraform/README.md).
Use `.example.tfvars.json` for local checks. For deployment, supply foundation
resource IDs and a separate Terraform workload group and state key, so this
target does not share ownership with the Bicep account.

## Local validation

From the catalog root:

```powershell
$Tf = (Resolve-Path .\.tools\terraform.exe).Path # verified Terraform 1.13.5
$Root = (Resolve-Path .\platform-apps\storage\terraform).Path
& $Tf "-chdir=$Root" fmt -check
& $Tf "-chdir=$Root" init -backend=false -input=false -lockfile=readonly
& $Tf "-chdir=$Root" validate
& $Tf "-chdir=$Root" test "-var-file=../../../examples/platform/storage/terraform/.example.tfvars.json"
```

Initialization restores dependencies without connecting to state. Validation and
mocked plan tests use the example inputs and do not provision Azure resources.

## Connect to the private backend

Once the foundation is available, initialize state from the private runner.
It needs Blob DNS/routing and `Storage Blob Data Contributor` on the state
container, in addition to workload management permissions. The catalog workflow
provides `ARM_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`, and GitHub's OIDC
environment through `id-token: write`. Tokens are supplied by the job rather
than copied into files or commands.

```powershell
$env:ARM_USE_OIDC = "true"
$env:ARM_USE_AZUREAD = "true"
$State = Get-Content .\environments\demo.local.json -Raw | ConvertFrom-Json
& $Tf "-chdir=$Root" init -reconfigure -input=false -lockfile=readonly `
  "-backend-config=resource_group_name=$($State.state.resourceGroupName)" `
  "-backend-config=storage_account_name=$($State.state.storageAccountName)" `
  "-backend-config=container_name=$($State.state.containerName)" `
  "-backend-config=key=demo/storage-terraform/storetf.tfstate" `
  "-backend-config=use_oidc=true" "-backend-config=use_azuread_auth=true" `
  "-backend-config=client_id=$env:ARM_CLIENT_ID" `
  "-backend-config=tenant_id=$env:ARM_TENANT_ID" `
  "-backend-config=subscription_id=$env:ARM_SUBSCRIPTION_ID"
```

`demo.local.json` contains the platform's environment bindings and stays out of
source control. The [plan/apply workflow](../../../../docs/rehearsal.md#maintainer-handoff)
uses variables rendered from those bindings and the merged consumer request.
The backend remains private and Entra-only, with locking enabled.

## Cleanup

Review a destroy plan for this target's state and decide how to retain or dispose
of Blob data and versions. Keep saved plans private and preserve the foundation
and backend until workload cleanup is complete.

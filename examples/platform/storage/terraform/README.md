# Run the private Storage Terraform example

See [controls, dependencies and cleanup](../../../../platform-apps/storage/terraform/README.md).
`.example.tfvars.json` contains **synthetic** IDs, not a deployable environment.
Replace them only with approved foundation outputs, retaining this exact input
contract. Use a distinct Terraform resource group and state key; never point
Bicep and Terraform at the same account.

From the catalog root, offline validation:

```powershell
$Tf = (Resolve-Path .\.tools\terraform.exe).Path # verified Terraform 1.13.5
$Root = (Resolve-Path .\platform-apps\storage\terraform).Path
& $Tf "-chdir=$Root" fmt -check
& $Tf "-chdir=$Root" init -backend=false -input=false -lockfile=readonly
& $Tf "-chdir=$Root" validate
& $Tf "-chdir=$Root" test "-var-file=../../../examples/platform/storage/terraform/.example.tfvars.json"
```

`init` downloads pinned public dependencies, but `validate` and mocked tests
perform no Azure provisioning. This is not a live deployment claim.

## Future approved connected initialization

Run only on the isolated private runner after the foundation exists. It needs
private Blob DNS/routing, `Storage Blob Data Contributor` scoped to its state
container and appropriate workload resource-management permissions. Public
GitHub runners cannot reach the private backend. The approved workflow provides
the real `ARM_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID` and GitHub's OIDC
request environment (`id-token: write`); do not paste tokens into commands/files.

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

`demo.local.json` is platform-owned local metadata, not consumer configuration.
Supply a separately rendered trusted variable file to the approved plan/apply
workflow. Do not use keys, SAS or public-access fallback; keep state locking
enabled and saved plans private. `terraform destroy` is **not** part of offline
validation: after use, separately review a target-only destroy plan and storage
data-retention consequences. Preserve foundation and state until cleanup is
verified.

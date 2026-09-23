# Private VM with Terraform

This example runs the [VM root](../../../../platform-apps/vm/terraform/README.md)
with D2as_v5 or D4as_v5 sizing and the catalog's Ubuntu image.
`.example.tfvars.json` supplies test resource IDs and a public-key fixture.
For deployment, replace them with foundation bindings and the operator's public
SSH key; retain the private key outside Terraform inputs.

## Local validation

From the catalog root:

```powershell
$Tf = (Resolve-Path .\.tools\terraform.exe).Path # verified Terraform 1.13.5
$Root = (Resolve-Path .\platform-apps\vm\terraform).Path
& $Tf "-chdir=$Root" fmt -check
& $Tf "-chdir=$Root" init -backend=false -input=false -lockfile=readonly
& $Tf "-chdir=$Root" validate
& $Tf "-chdir=$Root" test "-var-file=../../../examples/platform/vm/terraform/.example.tfvars.json"
```

These checks do not provision Azure resources. The upstream VM module emits
provider deprecation warnings with the pinned provider set; validation succeeds
and the warnings remain visible for upgrade review.

Before deployment, check zone-1 quota, image/SKU compatibility, encryption-at-host
support and registration, management NSG rules, and NAT routing.

## Connect to the private backend

Use the private runner after foundation DNS and routing are available. It needs
`Storage Blob Data Contributor` on the state container as well as workload
management permissions. The catalog workflow supplies `ARM_CLIENT_ID`,
`ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`, and OIDC request variables through
`id-token: write`.

```powershell
$env:ARM_USE_OIDC = "true"
$env:ARM_USE_AZUREAD = "true"
$State = Get-Content .\environments\demo.local.json -Raw | ConvertFrom-Json
& $Tf "-chdir=$Root" init -reconfigure -input=false -lockfile=readonly `
  "-backend-config=resource_group_name=$($State.state.resourceGroupName)" `
  "-backend-config=storage_account_name=$($State.state.storageAccountName)" `
  "-backend-config=container_name=$($State.state.containerName)" `
  "-backend-config=key=demo/vm-terraform/vmtf.tfstate" `
  "-backend-config=use_oidc=true" "-backend-config=use_azuread_auth=true" `
  "-backend-config=client_id=$env:ARM_CLIENT_ID" `
  "-backend-config=tenant_id=$env:ARM_TENANT_ID" `
  "-backend-config=subscription_id=$env:ARM_SUBSCRIPTION_ID"
```

The environment binding stays local. The
[catalog workflow](../../../../docs/rehearsal.md#maintainer-handoff) renders
deployment inputs from the merged request, without executing consumer code.
State access remains private and Entra-only, with locks and saved plans retained.

## Cleanup

Review a destroy plan against this target's state, including its VM, NIC, and
disk. Preserve the shared foundation and the separately managed Bicep instance.

# Run the private VM Terraform example

See [the VM contract and cleanup](../../../../platform-apps/vm/terraform/README.md).
The supplied `.example.tfvars.json` has synthetic IDs and a non-deployable
public-key fixture. Replace it with approved foundation bindings and the
platform operator's real **public** SSH key. No private key belongs in tfvars.
Small/medium select only D2as_v5/D4as_v5 with the catalog-pinned Ubuntu image.

From the catalog root:

```powershell
$Tf = (Resolve-Path .\.tools\terraform.exe).Path # verified Terraform 1.13.5
$Root = (Resolve-Path .\platform-apps\vm\terraform).Path
& $Tf "-chdir=$Root" fmt -check
& $Tf "-chdir=$Root" init -backend=false -input=false -lockfile=readonly
& $Tf "-chdir=$Root" validate
& $Tf "-chdir=$Root" test "-var-file=../../../examples/platform/vm/terraform/.example.tfvars.json"
```

No real Azure resources are created by validation/mocked tests. Before future
approved deployment verify zone-1 quota, image/SKU compatibility, host encryption
registration/support, private SSH management NSG rules and NAT routing.

## Future approved Entra/OIDC backend setup

Only use the isolated private runner. Foundation-owned private Blob networking
and DNS must already work. Assign state-container-scoped `Storage Blob Data
Contributor` separately from workload resource-management permissions. The
approved GitHub workflow supplies `ARM_CLIENT_ID`, `ARM_TENANT_ID`,
`ARM_SUBSCRIPTION_ID` and OIDC request variables with `id-token: write`.

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

The local environment binding is platform-owned and excluded from source.
Plan/apply is a separately approved connected workflow using trusted rendered
variables, never untrusted source on the privileged runner. No key/SAS fallback,
no public VM/state endpoints, no saved plans in public artifacts. Keep locking.
For cleanup, review destruction against this exact state and remove only its
VM, NIC and disk; preserve shared foundation and the Bicep target.

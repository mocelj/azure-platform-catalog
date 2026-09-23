# Run the private Container App Terraform example

See [the Container App contract and preview disclosure](../../../../platform-apps/container-app/terraform/README.md).
The `.example.tfvars.json` is synthetic. Use the Terraform environment's dedicated
infrastructure subnet, not the Bicep environment subnet. The endpoint subnet
and region-specific `privatelink.swedencentral.azurecontainerapps.io` zone are
foundation-owned. No workspace shared secret or arbitrary image input is needed.

From the catalog root:

```powershell
$Tf = (Resolve-Path .\.tools\terraform.exe).Path # verified Terraform 1.13.5
$Root = (Resolve-Path .\platform-apps\container-app\terraform).Path
& $Tf "-chdir=$Root" fmt -check
& $Tf "-chdir=$Root" init -backend=false -input=false -lockfile=readonly
& $Tf "-chdir=$Root" validate
node --test tests/terraform-workloads.test.mjs
```

No live provisioning is performed. App/environment APIs
`2025-02-02-preview` / `2025-10-02-preview` are explicit demo exceptions. The
image is an illustrative Microsoft sample, not an FSI production baseline.
External app ingress means access from outside the environment through its PE;
environment public-network access remains disabled and HTTPS is mandatory.

Terraform 1.13.5 cannot mock the selected environment module's ephemeral resource
schema, even though key retrieval has count zero for this configuration. This
root has source-contract tests and real `init`/`validate`, not mocked plan
coverage. No upstream module is patched to hide that limitation.

## Future approved Entra/OIDC backend setup

Run only on the isolated private runner after validating delegation, NAT, DNS,
region/API support and private Blob connectivity. Grant state-container-scoped
`Storage Blob Data Contributor` separately from workload resource permissions.
The trusted workflow supplies `ARM_CLIENT_ID`, `ARM_TENANT_ID`,
`ARM_SUBSCRIPTION_ID` and GitHub OIDC request variables with `id-token: write`.

```powershell
$env:ARM_USE_OIDC = "true"
$env:ARM_USE_AZUREAD = "true"
$State = Get-Content .\environments\demo.local.json -Raw | ConvertFrom-Json
& $Tf "-chdir=$Root" init -reconfigure -input=false -lockfile=readonly `
  "-backend-config=resource_group_name=$($State.state.resourceGroupName)" `
  "-backend-config=storage_account_name=$($State.state.storageAccountName)" `
  "-backend-config=container_name=$($State.state.containerName)" `
  "-backend-config=key=demo/container-app-terraform/containertf.tfstate" `
  "-backend-config=use_oidc=true" "-backend-config=use_azuread_auth=true" `
  "-backend-config=client_id=$env:ARM_CLIENT_ID" `
  "-backend-config=tenant_id=$env:ARM_TENANT_ID" `
  "-backend-config=subscription_id=$env:ARM_SUBSCRIPTION_ID"
```

The environment binding remains local and platform-owned. Connected plan/apply
requires separate approval and trusted rendered variables. Never open public
access or use state keys/SAS as a workaround. Keep state locks and saved plans
private. After use, review a target-only destroy plan: the environment and PE
can cost money even when replicas scale to zero. Preserve shared infrastructure,
private state and the Bicep environment until separately authorized cleanup.

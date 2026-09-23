# Private Container App with Terraform

The [Container App root](../../../../platform-apps/container-app/terraform/README.md)
composes an environment, app, and private endpoint. Replace the placeholders in
`.example.tfvars.json` with foundation IDs for deployment. The Terraform
environment needs its own infrastructure subnet, separate from the Bicep
environment and the shared endpoint subnet. DNS uses
`privatelink.swedencentral.azurecontainerapps.io`.

The catalog supplies the image and monitoring configuration; the interface does
not accept arbitrary images or workspace shared keys.

## Local validation

From the catalog root:

```powershell
$Tf = (Resolve-Path .\.tools\terraform.exe).Path # verified Terraform 1.13.5
$Root = (Resolve-Path .\platform-apps\container-app\terraform).Path
& $Tf "-chdir=$Root" fmt -check
& $Tf "-chdir=$Root" init -backend=false -input=false -lockfile=readonly
& $Tf "-chdir=$Root" validate
node --test tests/terraform-workloads.test.mjs
```

This root has source-contract tests and real `init`/`validate`, but no mocked plan
coverage. Terraform `1.13.5` cannot mock the upstream environment's ephemeral
resource schema, even with count zero. The limitation applies to the environment,
app, and private endpoint; it is reported by the IaC check command.

Before deployment, review the app/environment APIs
`2025-02-02-preview` and `2025-10-02-preview` and the older Microsoft sample
image. These are demonstration choices, not production defaults. External app
ingress reaches the app through the environment's private endpoint; public
network access is disabled and HTTPS is required.

## Connect to the private backend

Use the private runner after checking delegation, NAT, DNS, regional/API support,
and Blob connectivity. It needs `Storage Blob Data Contributor` on the state
container as well as workload management permissions.
The catalog workflow supplies `ARM_CLIENT_ID`, `ARM_TENANT_ID`,
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

The environment binding remains local. Use the
[catalog plan/apply workflow](../../../../docs/rehearsal.md#maintainer-handoff)
with rendered variables, Entra state authorization, and locking. Saved plans and
state remain private.

## Cleanup

Review a destroy plan for this target. The environment and private endpoint can
incur charges even when application replicas scale to zero. Retain the shared
foundation, backend, and Bicep environment until their owners schedule cleanup.

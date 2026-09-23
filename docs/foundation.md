# Shared foundation: one owner, eight workload roots

**Implementation status:** these are deployment instructions, not a record of a live
deployment. Offline compilation and tests cannot prove Azure policy, regional
capacity, authorization, network reachability, or application health. No Azure
resources are provisioned by repository validation.

On 2026-09-23, pinned Bicep **0.47.16** successfully restored and compiled
`main.bicep`, `shared.bicep`, and `demo.bicepparam` with **zero warnings or errors**;
all six foundation contract tests passed. No IaC fixes were required. This
supersedes the earlier provisional 0.35.1 check, not the separate live-deployment
approval and verification requirements. Compiler evidence and the refreshed
recursive API inventory are in `catalog\bootstrap-dependencies.json`.

The platform team owns `bootstrap\bicep\main.bicep`, the only shared-foundation
deployment entrypoint. It composes **official, exact-version AVM modules** at
subscription and resource-group scopes. `shared.bicep` is a local composition, not
a replacement resource implementation. Terraform consumes the resulting IDs; it
does not create, adopt, import, or destroy the foundation.

## Ownership and topology

The default prefix creates `rg-avmdemo-demo-shared` plus **eight different workload
resource groups**, one for each target in `catalog\platform.json`. Bicep and
Terraform never own the same workload resource. The shared group contains:

| Resource | Configuration |
| --- | --- |
| VNet | `vnet-avmdemo-demo`, `10.40.0.0/16` |
| VM subnet | `10.40.1.0/24`; no public NIC IP; `defaultOutboundAccess: false`; NAT egress; NSG |
| Private-endpoint subnet | `10.40.2.0/24`; no delegation; private endpoint network policies disabled deliberately |
| Web App integration | `10.40.3.0/24`; `Microsoft.Web/serverFarms` delegation; NAT |
| Container Apps Bicep | `10.40.4.0/24`; `Microsoft.App/environments` delegation; NAT |
| Container Apps Terraform | `10.40.5.0/24`; **separate** `Microsoft.App/environments` delegation; NAT |
| Egress | Standard NAT Gateway plus static IPv4 Standard/Regional public IP, both logical zone `1` by default |
| DNS | `privatelink.blob.core.windows.net`, `privatelink.azurewebsites.net`, `privatelink.swedencentral.azurecontainerapps.io`; VNet links with auto-registration off |
| Monitoring | Log Analytics, 30-day retention; public ingestion/query explicitly enabled |
| State and plans | Private Blob endpoint, Entra-only clients, `tfstate` and `plans` containers |
| Deployment identities | Separate UAMIs for GitHub environments `demo-plan` and `demo-apply` |

An ACA environment requires an **exclusive** infrastructure subnet. The two
engines must not reuse one subnet: the environment resource is independent for
each target. This is the workload-profiles architecture (supports NAT and Private
Link), not the legacy consumption-only environment. `/24` leaves growth room
above the workload-profiles `/27` minimum. The shared Web App integration `/24`
can host the demo's two plans under App Service multi-plan subnet join; the
private-endpoint subnet remains separate from integration.

NAT is **outbound connectivity, not a firewall**, destination allowlist, or
exfiltration control. It is not an inbound management address. Four supported
workload subnets explicitly reference the NAT resource through the AVM VNet
`subnets[].natGatewayResourceId` interface. Web App must route outbound application
traffic through VNet integration. Container Apps workload profiles must be used.
Image pulls, OS updates, GitHub, Azure control plane, and Azure Monitor still need
approved outbound access. A production landing zone should supply inspected,
filtered egress; it is not secretly implemented in this demo.

The VM NSG allows TCP/22 only from `approvedManagementCidr`, then denies **all**
other inbound traffic before default VNet allow rules. That input has no default
in the root and must be an approved RFC1918 IPv4 CIDR. Validation rejects public
ranges, `0.0.0.0/0`, and over-broad ranges spanning outside RFC1918. The fixture
`10.41.0.0/24` is illustrative, not an approved live network.

## Private runner, management routes, and DNS are prerequisites

This bootstrap does **not** create a runner, jump host, VPN, ExpressRoute,
peering, resolver, public SSH endpoint, or customer firewall changes. Before
connected operations, the separately administered runner/client network needs:

1. Nonoverlapping address space, private routing to `10.40.0.0/16`, return routes,
   and approved peering/VPN/ExpressRoute settings. The management source seen by
   the VM must fall within the caller-approved CIDR.
2. Private DNS resolution. VNet peering does **not** propagate DNS-zone links.
   Link the existing runner VNet to the zones under its owner-approved process,
   or use a DNS resolver/conditional forwarding path into the linked demo VNet.
   On-premises clients cannot use Azure's VNet DNS IP directly without a resolver.
3. TCP/443 to private Blob endpoints and private app/SCM endpoints. Verify
   `<account>.blob.core.windows.net` resolves to the private endpoint address;
   likewise the Web App and ACA canonical FQDNs.
4. Outbound access to GitHub, Entra token exchange, Azure Resource Manager,
   module/provider registries, required image registries, and the explicitly
   permitted public Azure Monitor endpoints. Do not run consumer build scripts
   or fork PR code on the privileged runner.

For Web App, the private DNS zone group adds **both** `<app>` and `<app>.scm` A
records in `privatelink.azurewebsites.net`. The second is essential for private
Kudu/SCM release operations when basic publishing authentication is disabled.
Use the canonical `<app>.azurewebsites.net` and `<app>.scm.azurewebsites.net`
hostnames for TLS; do not browse the private IP or replace certificate validation.
Validate both records, including equivalent records when using customer DNS.

Private Blob storage means a normal public GitHub-hosted runner **cannot**
initialize the Terraform backend or read saved plans. The catalog-owned,
isolated runner executes only maintainer-approved trusted jobs. Public-repository
self-hosted runners remain a disposable-demo exception, not an FSI production
recommendation.

## Identity and least privilege

The initial bootstrap operator is authorized **separately by the user**. It needs
subscription deployment/resource-group creation, resource provisioning in the
nine groups, and the ability to assign the scoped roles below. A separately
approved combination such as Contributor plus RBAC Administrator for bootstrap
is possible, with further organizational scoping/conditions. The routine
workflow identities do **not** receive subscription Owner, subscription
Contributor, or unrestricted subscription role-assignment rights.

The identity federation issuer is `https://token.actions.githubusercontent.com`,
audience `api://AzureADTokenExchange`, and subjects are exactly:

- `repo:mocelj/azure-platform-catalog:environment:demo-plan`
- `repo:mocelj/azure-platform-catalog:environment:demo-apply`

Protect these catalog GitHub environments, limit dispatch/runner use to
maintainers, and use `deploymentIdentities` outputs to configure each environment's
Azure client ID. No consumer-repository subject, branch wildcard, client secret,
or private SSH key is created. Solo-presenter approval is not independent
separation of duties.

| Grant | Scope and reason |
| --- | --- |
| Contributor | Each of the eight workload RGs, both identities. ARM what-if needs deployment/write permissions, not just Reader; therefore the plan identity is **not read-only**. |
| Reader | Shared RG only, for discovery and destination/subnet/workspace metadata. |
| Network Contributor | The five exact shared subnets, not the subscription/VNet/RG. Supports NIC joins, private endpoint joins, and delegated integration. This built-in role also permits subnet modification; trust/isolation of the catalog code is essential. |
| Private DNS Zone Contributor | Each of the three exact zones, for endpoint DNS-zone groups and records. It can modify records in those zones; this is shared demo infrastructure, not tenant-wide DNS. |
| Storage Blob Data Contributor | **Only** `tfstate` and `plans` containers, not all subscription storage. Both phases need Blob read/write and state-lease locking. ARM Reader alone cannot initialize/lock a backend. |

Do not infer that Contributor includes `Microsoft.Authorization/roleAssignments/write`.
Only bootstrap creates the routine identity grants above. Any workload AVM that
actually creates data-role assignments must have an explicitly reviewed,
conditioned role-assignment grant at its dedicated RG; never solve that with
subscription Owner. Review the current workload dependency manifest and actual
compiled role assignments before connected planning.
The current workload contract exposes no role-assignment passthrough and requests
no workload role grants, so no routine RBAC Administrator grant is needed. If a
future catalog version adds one, constrain **both write and delete** to the exact
data-role IDs and intended principals/types at that one workload RG using AVM's
`condition`/`conditionVersion` inputs. Do not give either phase authority to
grant Owner, Contributor, or RBAC Administrator to itself.

Azure Monitor public ingestion/query is an **approved demo exception**. No AMPLS
is deployed and no raw ARM/CLI workaround is used. Workspace local authentication
is disabled; workload diagnostics must use Azure Monitor diagnostic settings,
not embedded workspace shared keys. Microsoft-managed encryption is used;
`forceCmkForQuery: false` does not pretend customer-managed keys were configured.

## State, plans, and recovery

The state account explicitly disables Shared Key, public network access, anonymous
Blob access, local users, and cross-tenant replication. HTTPS and TLS 1.2 are
required, infrastructure encryption is enabled, and the private endpoint exposes
only Blob. Containers use `publicAccess: None`. Blob versioning, Blob soft delete,
and container soft delete have 14-day retention. This is recovery protection,
**not** immutable/WORM storage; immutability would interfere with state updates.
Blob audit diagnostics go to the shared workspace.

State keys are deterministic and separate from workload names:
`demo/<service>-terraform/<instance>.tfstate`; for example
`demo/storage-terraform/hello.tfstate`. Never point two targets or instances at
one key. Bicep has no Terraform state key. Preserve Blob lease locking, set
workflow concurrency per target/instance, and never use `-lock=false` or routine
force-unlock. Shared resources are absent from every workload state.

Saved plans contain sensitive data even with secret outputs suppressed. Store
them only in the private `plans` container with the trusted configuration hash,
consumer SHA, catalog SHA, environment hash, target, and toolchain binding. Do not
publish plans/state as public workflow artifacts. Define short plan validity and
delete expired plans through an approved maintenance operation; Blob versions and
soft-deleted copies persist through the retention period and must be included in
retention/cleanup reviews.

## Read-only preflight, then separately approved bootstrap

From the repository root in PowerShell, first compile **without deploying**:

```powershell
.\.tools\bicep.exe build .\bootstrap\bicep\main.bicep --stdout > $null
.\.tools\bicep.exe build-params .\bootstrap\bicep\demo.bicepparam --stdout > $null
node --test .\tests\foundation.test.mjs
```

The example metadata uses only the zero subscription UUID and a newly generated
public SSH fixture. Its private key was never saved and it is not usable for
live management. `demo.bicepparam` is a compilation example using this binding;
copy it to a protected, untracked file and replace the SSH public key and approved
management CIDR before a real bootstrap. Verify naming, overlap, logical zone,
provider registration, subscription policy, regional SKUs, quotas, and the
precise image from the workload catalog. Do not silently register providers or
modify the subscription as part of preflight.

Read-only examples, after interactive operator authentication:

```powershell
az account show --query '{subscription:id,tenant:tenantId,name:name}' -o json
az provider show --namespace Microsoft.Network --query registrationState -o tsv
az provider show --namespace Microsoft.Storage --query registrationState -o tsv
az provider show --namespace Microsoft.Compute --query registrationState -o tsv
az provider show --namespace Microsoft.Web --query registrationState -o tsv
az provider show --namespace Microsoft.App --query registrationState -o tsv
az provider show --namespace Microsoft.ManagedIdentity --query registrationState -o tsv
az provider show --namespace Microsoft.OperationalInsights --query registrationState -o tsv
az network list-usages --location swedencentral -o table
az vm list-usage --location swedencentral -o table
az vm list-skus --location swedencentral --resource-type virtualMachines --all -o json
az role assignment list --assignee $BootstrapOperatorObjectId --include-inherited --all -o json
```

Catalog preflight and read-only Azure views cannot guarantee deployment
success/capacity. `az deployment sub what-if` does not provision resources, but
needs Azure permissions and may record a deployment operation; run it **only**
after separate authorization, against the reviewed AVM entrypoint. A future
authorized bootstrap uses `az deployment sub create --location swedencentral
--parameters <private-copy.bicepparam>`; do not create the resources individually
with CLI commands. This document does not authorize running it.

After that separately approved operation, read the existing deployment outputs:

```powershell
$Outputs = az deployment sub show --name $BootstrapDeploymentName --query properties.outputs -o json | ConvertFrom-Json
$Outputs.environmentMetadata.value | ConvertTo-Json -Depth 20 | Set-Content $PrivateEnvironmentFile
# Configure protected catalog environment client IDs from:
$Outputs.deploymentIdentities.value
node --input-type=module -e "import {readJson,validateEnvironment} from './scripts/platform.mjs'; validateEnvironment(readJson(process.argv[1]),{live:true});" $PrivateEnvironmentFile
```

Only `environmentMetadata.value` belongs in the environment JSON schema. Identity
configuration and `foundationResourceIds` are separate non-secret operator
outputs. Never append unrecognized properties to that schema or copy raw
deployment output dumps. AVM internals expose some `@secure()` outputs; the
first-party compositions never consume or forward storage/workspace keys.

### Entra-only Terraform backend

Use the catalog renderer to produce `backend.hcl` and target variables from a
validated configuration and private environment file. The backend must contain:

```hcl
resource_group_name  = "rg-avmdemo-demo-shared"
storage_account_name = "<value-from-environment-metadata>"
container_name       = "tfstate"
key                  = "demo/storage-terraform/hello.tfstate"
use_oidc             = true
use_azuread_auth      = true
```

These are data/configuration fields, not Azure resource declarations. In a
protected GitHub Environment job, set `ARM_CLIENT_ID`, `ARM_TENANT_ID`,
`ARM_SUBSCRIPTION_ID`, `ARM_USE_OIDC=true`, and `ARM_USE_AZUREAD=true`; grant only
the trusted job `id-token: write`. The azurerm backend obtains the GitHub OIDC
token from the job environment. Do not print tokens or use `ARM_ACCESS_KEY`,
SAS, publishing profiles, or key-list fallback.

```powershell
# Future connected operation only; requires the private runner and approved identity.
.\.tools\terraform.exe -chdir=platform-apps\storage\terraform init -input=false -lockfile=readonly -backend-config=$PrivateBackendFile
```

Allow for Entra/RBAC propagation; failure is not permission to enable public
storage or Shared Key. An interactive CLI login is not a substitute for the
documented OIDC backend path.

## Existing-foundation mode: validate, do not adopt

Do **not** run `bootstrap\bicep\main.bicep` against a customer foundation. Instead,
the platform owner supplies an environment JSON conforming exactly to
`schemas\environment.schema.json`. `validateEnvironment(..., {live:true})`
checks shape, subscription consistency, eight separate RG names, five distinct
subnet IDs, expected zone names, and rejects the zero-UUID fixture. Validation is
input checking, **not** evidence of Azure configuration or ownership.

Through separately authorized **read-only** preflight, prove those resources
exist and satisfy the network/delegation/NAT-or-approved-filtered-egress,
NSG/management, private DNS, workspace, storage, state-container, and identity
requirements above. Examples include `az network vnet subnet show --ids`,
`az network private-dns link vnet list`, `az network private-endpoint show`,
`az storage account show`, `az storage account blob-service-properties show`,
`az storage container show --auth-mode login`, `az monitor log-analytics
workspace show`, and `az role assignment list`. Perform private DNS resolution
and TCP/TLS tests **from the approved runner**. JSON schema validation alone
cannot verify these properties.

Customer administrators establish any missing routing, DNS, federation, or
scoped RBAC under their normal change process. Never import their foundation
into Terraform, redeploy our VNet over theirs, change their subnet settings,
or delete their shared resources. If the required contract cannot be met,
stop connected deployment; do not silently weaken the contract.

## Cleanup order

Cleanup is a separately authorized destructive operation, never a validation
step. Freeze dispatches and wait for active jobs/leases. Destroy each Terraform
workload from its own root/key while the backend, runner, DNS, identities, and
network still exist; remove only Bicep-owned workload RGs through the reviewed
operator process. Verify all eight workload groups are empty/gone and remove
workload private endpoints before deleting DNS/network dependencies. Keep a
protected final state/evidence backup and satisfy retention obligations.

Then revoke workload grants/federations, retire the demo runner's links/peering
through its owner, and delete the demo shared foundation **last**. Never delete
the state account before Terraform cleanup. Soft-delete/version retention may
require a delayed final purge approved by the owner. Existing customer foundation
resources are **excluded** from cleanup.

## References and compatibility

- Exact source/API inventory: [`catalog\bootstrap-dependencies.json`](../catalog/bootstrap-dependencies.json).
- [AVM Bicep registry](https://github.com/Azure/bicep-registry-modules/tree/main/avm).
- [Container Apps networking and exclusive workload-profile subnets](https://learn.microsoft.com/azure/container-apps/networking).
- [App Service private endpoints and SCM DNS](https://learn.microsoft.com/azure/app-service/overview-private-endpoint).
- [App Service NAT integration](https://learn.microsoft.com/azure/app-service/overview-nat-gateway-integration).
- [Conditional delegation of role assignments](https://learn.microsoft.com/azure/role-based-access-control/delegate-role-assignments-examples).
- [Terraform azurerm backend Entra/OIDC](https://developer.hashicorp.com/terraform/language/backend/azurerm).

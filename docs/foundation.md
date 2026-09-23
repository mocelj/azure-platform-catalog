# Shared foundation

The foundation provides networking, DNS, identities, monitoring, and private
Terraform state before workloads are deployed. The platform team manages it
through `bootstrap\bicep\main.bicep`, using pinned official AVM modules at
subscription and resource-group scopes. `shared.bicep` composes the shared
resources; Terraform workload roots consume their IDs without managing them.

The foundation and parameter example compile with Bicep `0.47.16` without warnings,
and the six foundation contract tests pass. The dependency and API inventory is
in `catalog\bootstrap-dependencies.json`. Azure deployment and connectivity
verification remain outstanding; the preparation steps below cover that work.

## Ownership and topology

The default prefix creates `rg-avmdemo-demo-shared` and eight workload resource
groups, one per target in `catalog\platform.json`. This keeps Bicep and Terraform
ownership separate. The shared group contains:

| Resource | Configuration |
| --- | --- |
| VNet | `vnet-avmdemo-demo`, `10.40.0.0/16` |
| VM subnet | `10.40.1.0/24`; no public NIC IP; `defaultOutboundAccess: false`; NAT egress; NSG |
| Private-endpoint subnet | `10.40.2.0/24`; no delegation; private endpoint network policies disabled deliberately |
| Web App integration | `10.40.3.0/24`; `Microsoft.Web/serverFarms` delegation; NAT |
| Container Apps Bicep | `10.40.4.0/24`; `Microsoft.App/environments` delegation; NAT |
| Container Apps Terraform | `10.40.5.0/24`; separate `Microsoft.App/environments` delegation; NAT |
| Egress | Standard NAT Gateway plus static IPv4 Standard/Regional public IP, both logical zone `1` by default |
| DNS | `privatelink.blob.core.windows.net`, `privatelink.azurewebsites.net`, `privatelink.swedencentral.azurecontainerapps.io`; VNet links with auto-registration off |
| Monitoring | Log Analytics, 30-day retention; public ingestion/query explicitly enabled |
| State and plans | Private Blob endpoint, Entra-only clients, `tfstate` and `plans` containers |
| Deployment identities | Separate UAMIs for GitHub environments `demo-plan` and `demo-apply` |

Each Container Apps environment needs its own infrastructure subnet. The two
targets use workload-profiles environments, which support NAT and Private Link,
rather than the legacy consumption-only architecture. The `/24` allocation leaves
room above the `/27` minimum. Web App's two plans share an integration `/24` using
multi-plan subnet join; inbound private endpoints use a different subnet.

Four workload subnets reference NAT through AVM's
`subnets[].natGatewayResourceId` interface. Web App routes outbound traffic through
VNet integration, while Container Apps uses workload profiles. NAT supplies an
outbound address, not an inbound management endpoint or a filtering firewall.
Image pulls, OS updates, GitHub, Entra, Azure management, and monitoring still
need outbound access. Use the production landing zone's inspection and filtering
services where those are required.

The VM NSG permits TCP/22 from `approvedManagementCidr` and denies other inbound
traffic before the default VNet rules. This required input accepts an RFC1918
IPv4 CIDR; public ranges, `0.0.0.0/0`, and ranges extending outside RFC1918 are
rejected. Replace the example `10.41.0.0/24` with the actual management source.

## Runner connectivity and DNS

Runner hosting, management access, peering/VPN/ExpressRoute, DNS resolvers, and
customer firewall changes sit outside this bootstrap. The existing runner and
client networks need:

1. Nonoverlapping address space, routes to `10.40.0.0/16`, and return routes. The
   source address seen by the VM must fall within the management CIDR.
2. Private DNS resolution. VNet peering does not propagate DNS-zone links.
   Link the runner VNet to the zones through its normal administration process,
   or use a resolver/conditional forwarding path into the linked demo VNet.
   On-premises clients cannot use Azure's VNet DNS IP directly without a resolver.
3. TCP/443 to private Blob and app/SCM endpoints. Verify
   `<account>.blob.core.windows.net` resolves to the private endpoint address;
   likewise the Web App and ACA canonical FQDNs.
4. Outbound access to GitHub, Entra token exchange, Azure Resource Manager,
   module/provider registries, required image registries, and the explicitly
   permitted public Azure Monitor endpoints.

For Web App, the private DNS zone group adds both `<app>` and `<app>.scm` A
records in `privatelink.azurewebsites.net`. The second is essential for private
Kudu/SCM release operations when basic publishing authentication is disabled.
Use the canonical `<app>.azurewebsites.net` and `<app>.scm.azurewebsites.net`
hostnames so TLS certificate validation works.
Validate both records, including equivalent records when using customer DNS.

The private backend and plan store are not reachable from a standard
GitHub-hosted runner. The catalog's isolated runner handles those operations and
does not run consumer build scripts or fork PR code. Its registration in a public
repository is a demo exception; production should use a private execution
repository and restricted runner group.

## Identity and least privilege

Bootstrap requires broader permissions than routine workload deployment: creating
resource groups, provisioning within the nine groups, and assigning the roles
below. An operator may use Contributor plus RBAC Administrator, subject to
organizational scoping and conditions. The routine workflow identities receive
neither subscription Owner/Contributor nor subscription-wide role-assignment
rights.

The identity federation issuer is `https://token.actions.githubusercontent.com`,
audience `api://AzureADTokenExchange`, and subjects are:

- `repo:mocelj/azure-platform-catalog:environment:demo-plan`
- `repo:mocelj/azure-platform-catalog:environment:demo-apply`

Configure the two GitHub environments with branch restrictions and maintainers'
deployment permissions, using `deploymentIdentities` outputs for their client
IDs. Federation is environment-scoped rather than granted to the consumer
repository or a branch wildcard. It needs no client secret or private SSH key.
Independent approval requires a second reviewer; the solo-presenter setup does
not provide separation of duties.

| Grant | Scope and reason |
| --- | --- |
| Contributor | Both identities, on each workload RG. ARM what-if requires deployment/write permissions, so the plan identity is not read-only. |
| Reader | Shared RG only, for discovery and destination/subnet/workspace metadata. |
| Network Contributor | The five shared subnets, for NIC/endpoint joins and delegated integration. The role also permits subnet changes, which makes protected catalog code and runner isolation important. |
| Private DNS Zone Contributor | The three private zones, for endpoint zone groups and records. This is zone-scoped rather than tenant-wide DNS access. |
| Storage Blob Data Contributor | The `tfstate` and `plans` containers. Both phases need read/write and state leases; ARM Reader does not provide data-plane access. |

Contributor does not include `Microsoft.Authorization/roleAssignments/write`.
The current workloads request no role grants, so the routine identities do not
need RBAC Administrator. If a future wrapper adds data-role assignments, review
the compiled assignments and grant conditioned write/delete access at that
workload RG. AVM's `condition` and `conditionVersion` inputs can restrict the role
IDs and principals. Neither workflow phase should be able to elevate itself to
Owner, Contributor, or RBAC Administrator.

Azure Monitor uses public ingestion/query endpoints; no AMPLS is deployed.
Workspace local authentication is disabled, and diagnostics use Azure Monitor
settings rather than embedded workspace keys. Encryption uses Microsoft-managed
keys, with `forceCmkForQuery: false`. Private monitoring or customer-managed keys
would require a separate production design.

## State, plans, and recovery

The state account disables Shared Key, public network access, anonymous
Blob access, local users, and cross-tenant replication. HTTPS and TLS 1.2 are
required, infrastructure encryption is enabled, and the private endpoint exposes
only Blob. Containers use `publicAccess: None`. Blob versioning, Blob soft delete,
and container soft delete have 14-day retention. These controls support recovery;
WORM immutability would prevent normal state updates and is not enabled.
Blob audit diagnostics go to the shared workspace.

State keys are deterministic and separate from workload names:
`demo/<service>-terraform/<instance>.tfstate`; for example
`demo/storage-terraform/hello.tfstate`. Each target and instance needs a separate
key; Bicep does not use Terraform state. Blob leases and target-level workflow
concurrency protect against overlapping operations. Disabled locking and routine
force-unlock would remove that protection. Workload states exclude shared resources.

Saved plans can contain sensitive values even when outputs are suppressed. Keep
them in the private `plans` container with configuration/environment hashes,
source SHAs, target, and toolchain metadata. Plan validity and expiry cleanup
should be part of operations. Blob versions and soft-deleted copies remain
subject to retention, so deleting the active plan is not necessarily final disposal.

## Prepare and deploy the foundation

Compile and run the foundation tests from the repository root:

```powershell
.\.tools\bicep.exe build .\bootstrap\bicep\main.bicep --stdout > $null
.\.tools\bicep.exe build-params .\bootstrap\bicep\demo.bicepparam --stdout > $null
node --test .\tests\foundation.test.mjs
```

`demo.bicepparam` uses a zero subscription UUID and a test SSH public key for
compilation. Copy it to a protected, untracked file and supply the subscription,
public key, and management CIDR for your environment. Check address overlap,
naming, logical zones, provider registration, policy, SKUs, quota, and the catalog
image version before bootstrap. Provider registration and other subscription
changes belong in the customer's administration process, not a read-only check.

The following queries help with that review after operator authentication:

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

Run `az deployment sub what-if` against the foundation entrypoint once the
scope and permissions are agreed. What-if does not provision resources, but it
requires Azure permissions and may record a deployment operation; it also cannot
reserve regional capacity. Bootstrap uses `az deployment sub create --location swedencentral
--parameters <private-copy.bicepparam>` through the AVM composition rather than
individual CLI resource-creation commands.

After deployment, extract the environment bindings:

```powershell
$Outputs = az deployment sub show --name $BootstrapDeploymentName --query properties.outputs -o json | ConvertFrom-Json
$Outputs.environmentMetadata.value | ConvertTo-Json -Depth 20 | Set-Content $PrivateEnvironmentFile
# Configure protected catalog environment client IDs from:
$Outputs.deploymentIdentities.value
node --input-type=module -e "import {readJson,validateEnvironment} from './scripts/platform.mjs'; validateEnvironment(readJson(process.argv[1]),{live:true});" $PrivateEnvironmentFile
```

Use `environmentMetadata.value` as the environment JSON. Identity configuration
and `foundationResourceIds` are separate operator outputs. Keeping these separate
allows schema validation and avoids retaining unnecessary deployment output.
The compositions do not consume or forward the secure storage/workspace keys
available from some AVM internals.

### Entra-only Terraform backend

The renderer produces `backend.hcl` and target variables from the application
configuration and private environment file. The backend has this shape:

```hcl
resource_group_name  = "rg-avmdemo-demo-shared"
storage_account_name = "<value-from-environment-metadata>"
container_name       = "tfstate"
key                  = "demo/storage-terraform/hello.tfstate"
use_oidc             = true
use_azuread_auth      = true
```

The GitHub Environment job supplies `ARM_CLIENT_ID`, `ARM_TENANT_ID`,
`ARM_SUBSCRIPTION_ID`, `ARM_USE_OIDC=true`, and `ARM_USE_AZUREAD=true`.
Its `id-token: write` permission lets the backend obtain a GitHub OIDC token.
This path uses Entra authorization rather than `ARM_ACCESS_KEY`, SAS, or key
listing; tokens stay in the job environment.

```powershell
# Future connected operation only; requires the private runner and approved identity.
.\.tools\terraform.exe -chdir=platform-apps\storage\terraform init -input=false -lockfile=readonly -backend-config=$PrivateBackendFile
```

Allow for Entra/RBAC propagation when diagnosing initial access failures. Check
DNS, scope, and token configuration rather than enabling public storage or Shared
Key. An interactive CLI login exercises a different authentication path from OIDC.

## Using an existing foundation

For an existing customer foundation, skip `bootstrap\bicep\main.bicep`. Supply
environment JSON matching `schemas\environment.schema.json`.
`validateEnvironment(..., {live:true})` checks subscription consistency, eight
resource groups, five distinct subnets, and expected zone names, and rejects the
zero-UUID example. These checks validate inputs, not the resources behind the IDs.

Use read-only preflight to verify that the resources exist and meet the
network/delegation/NAT-or-filtered-egress,
NSG/management, private DNS, workspace, storage, state-container, and identity
requirements above. Examples include `az network vnet subnet show --ids`,
`az network private-dns link vnet list`, `az network private-endpoint show`,
`az storage account show`, `az storage account blob-service-properties show`,
`az storage container show --auth-mode login`, `az monitor log-analytics
workspace show`, and `az role assignment list`. Run private DNS and TCP/TLS
checks from the deployment runner, where the connectivity is needed.

Customer administrators handle any required routing, DNS, federation, or RBAC
changes. The catalog does not import their foundation into Terraform, redeploy
its network, alter its subnets, or delete its resources. Deployment waits until
the environment meets the workload requirements.

## Cleanup order

Freeze dispatches and wait for active jobs and leases before cleanup. Destroy each
Terraform workload using its own root and state key while the backend, runner,
DNS, and identities remain available. Remove the Bicep workload groups through
the platform operator process.

Check that the workload groups and private endpoints are gone before removing
shared dependencies. Retain the required state and audit records, then revoke
demo access, retire runner connectivity, and remove the demo foundation last.
Account for soft-delete/version retention in final disposal. Customer-owned
foundation resources are outside this cleanup scope.

## References and compatibility

- Exact source/API inventory: [`catalog\bootstrap-dependencies.json`](../catalog/bootstrap-dependencies.json).
- [AVM Bicep registry](https://github.com/Azure/bicep-registry-modules/tree/main/avm).
- [Container Apps networking and exclusive workload-profile subnets](https://learn.microsoft.com/azure/container-apps/networking).
- [App Service private endpoints and SCM DNS](https://learn.microsoft.com/azure/app-service/overview-private-endpoint).
- [App Service NAT integration](https://learn.microsoft.com/azure/app-service/overview-nat-gateway-integration).
- [Conditional delegation of role assignments](https://learn.microsoft.com/azure/role-based-access-control/delegate-role-assignments-examples).
- [Terraform azurerm backend Entra/OIDC](https://developer.hashicorp.com/terraform/language/backend/azurerm).

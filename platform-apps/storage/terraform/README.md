# Private Blob Storage — Terraform root

Run this fixed root, not a downloaded wrapper module. It composes official
`Azure/avm-res-storage-storageaccount/azurerm` **0.10.0** and its exact utility closure.
See [the runnable example](../../../examples/platform/storage/terraform/README.md).

## Enforced baseline

- `small`: Standard LRS; `medium`: Standard ZRS. StorageV2, Hot, Microsoft-managed
  encryption plus infrastructure encryption. Globally unique name derived from
  the instance, subscription and resource group.
- Public network access, Shared Key, anonymous Blob access, local users and
  cross-tenant replication disabled. HTTPS required; minimum TLS 1.2.
- Only Blob private ingress, using the supplied PE subnet and the existing
  `privatelink.blob.core.windows.net` zone. Public service bypass disabled.
- Private `data` container, versioning and seven-day Blob/container soft deletion.
- System identity; account metrics and Blob logs/metrics go to the supplied
  workspace. Module telemetry disabled. Azure Monitor connectivity is public,
  a disclosed demo exception, not private monitoring.
- `platform`, `environment`, `workload`, `engine`, and `catalogVersion` tags
  override conflicting platform metadata. No raw AVM/security passthrough.

## Contract

Common inputs: `name`, `location` (only `swedencentral`), `size`,
`resource_group_name`, `log_analytics_workspace_resource_id`, `tags`.
Service inputs: `private_endpoint_subnet_resource_id`, `private_dns_zone_resource_id`.
The resource group, networking, DNS, workspace, identity/RBAC, and state already
exist and remain foundation-owned. Workload and state Blob data roles are
separate from resource management roles. Use Entra authentication from a private
client; the system identity alone does not grant a human Blob access.

Terraform **1.13.5** and providers are exact. The provider lock is not a module
lock: [dependency provenance](../../../catalog/terraform-dependencies.json)
records the module closure and explicit API versions.

## Verification and cleanup

`terraform init -backend=false`, `terraform validate`, and mocked-provider tests
do not prove Azure deployability, SKU availability, DNS, RBAC or connectivity.
No live deployment is claimed. Connected plan/apply is a separately approved
operation on an isolated runner with private state and service DNS reachability.
Never expose state, saved plans or account keys in public artifacts.

After a demo, review a destroy plan for **this target's state only**. Blob
versions/soft-deleted data have retention and billing implications; make an
explicit data-disposition decision before deleting storage. Never delete shared
foundation/state to clean up a workload. Delete retained private plan artifacts
according to policy only after recording the result.

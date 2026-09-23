# Blob Storage Terraform root

This root composes `Azure/avm-res-storage-storageaccount/azurerm` `0.10.0`
and its pinned dependencies. Run it from the catalog checkout using the
[example](../../../examples/platform/storage/terraform/README.md).

## Configuration

The account is StorageV2 with the Hot tier. `small` selects Standard LRS;
`medium` selects Standard ZRS. Its globally unique name is derived from the
instance, subscription, and resource group. Encryption uses Microsoft-managed
keys plus infrastructure encryption.

Blob access uses the supplied private-endpoint subnet and
`privatelink.blob.core.windows.net` zone. Public access, service bypass,
Shared Key, anonymous access, local users, and cross-tenant replication are
disabled. HTTPS and TLS 1.2 or later are required.

The private `data` container has versioning and seven-day Blob/container soft
delete. System identity is enabled, with account metrics and Blob diagnostics
sent to the workspace over public Azure Monitor endpoints. AVM telemetry is
disabled.

Catalog values take precedence for `platform`, `environment`, `workload`,
`engine`, and `catalogVersion` tags. The wrapper does not expose a raw AVM
parameter object, which keeps the same controls in place for direct use.

## Contract

Common inputs: `name`, `location` (only `swedencentral`), `size`,
`resource_group_name`, `log_analytics_workspace_resource_id`, `tags`.
Service inputs: `private_endpoint_subnet_resource_id`, `private_dns_zone_resource_id`.
The resource group, networking, DNS, workspace, deployment identity/RBAC, and
state are supplied by the foundation. Blob data roles are separate from
resource-management permissions: a private client needs an Entra data role,
and the account's system identity does not grant users access.

Terraform `1.13.5` and the provider lock define the tooling baseline.
[Dependency records](../../../catalog/terraform-dependencies.json) cover modules
and API versions, which Terraform's provider lock does not track.

## Verification and cleanup

Initialization, validation, and three mocked plan runs pass without Azure access.
Live checks still need to cover private DNS, endpoint access, and Entra
authorization. Connected plan/apply uses the catalog runner and private backend.

For removal, review a destroy plan against this target's state and decide how to
handle versions and soft-deleted data. Preserve shared infrastructure until all
dependents are removed. Plans, state, and retained deployment records remain
private and follow the retention policy.

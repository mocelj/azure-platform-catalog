# Private Ubuntu VM Terraform root

`Azure/avm-res-compute-virtualmachine/azurerm` `0.21.0` manages the VM, NIC,
and disk. The [example](../../../examples/platform/vm/terraform/README.md) shows
how to validate this root and configure its backend.

## Configuration

The VM uses zone 1 in Sweden Central. `small` selects `Standard_D2as_v5`;
`medium` selects `Standard_D4as_v5`. Both use the x64/Gen2 image
`Canonical:ubuntu-24_04-lts:server:24.04.202609040`, whose discovery record is in
`catalog/platform.json`. Current allocation capacity still needs checking before
deployment.

Trusted Launch, Secure Boot, vTPM, and encryption at host are enabled. The OS
disk is 64-GiB Premium LRS with Microsoft-managed keys. Platform patch
assessment/patching and managed boot diagnostics are configured.

The NIC has no public IP or forwarding. The foundation subnet supplies NAT-backed
egress with default outbound access disabled, and its NSG restricts SSH to the
management source. Login uses `platformadmin` with the supplied public key.
Replace the example key before deployment; the wrapper neither accepts passwords
nor generates credentials or runs provisioning scripts.

System identity and Azure resource metrics to the workspace are enabled.
Guest logs, Azure Monitor Agent, and data-collection rules are not configured.
The service exposes SSH, not an HTTP application. Public Monitor connectivity
and NAT without destination filtering follow the shared
[security design](../../../docs/security-controls.md).

## Contract

Common: `name`, `location` (only `swedencentral`), `size`, `resource_group_name`,
`log_analytics_workspace_resource_id`, `tags`.
Service inputs: `subnet_resource_id`, `ssh_public_key`. Image, security, and
SKU mappings remain in the wrapper. Shared resources stay foundation-owned.
Preflight checks should cover quota, zone/image/size compatibility, Trusted
Launch, and encryption-at-host support and registration. Catalog tags take
precedence over supplied metadata; AVM telemetry is disabled.

Use Terraform `1.13.5` and the committed provider lock. The
[dependency inventory](../../../catalog/terraform-dependencies.json) records
modules separately. AzureRM controls VM/NIC API versions through the provider,
rather than through wrapper inputs.

## Verification and cleanup

Initialization, validation, and three mocked plan runs pass. The upstream module
emits provider deprecation warnings, retained for dependency-upgrade review.
Live deployment, management access, and diagnostics still need verification.
Connected jobs use OIDC and the private runner/backend.

Review removal against this target's state, including the OS disk and NIC.
Check for remaining billable resources while preserving shared networking,
workspace, state storage, and the Bicep instance. Saved plans and state remain private.

# Private Ubuntu VM — Terraform root

Run this fixed root. Official AVM
`Azure/avm-res-compute-virtualmachine/azurerm` **0.21.0** owns VM, NIC and disk
resources. See [the runnable example](../../../examples/platform/vm/terraform/README.md).

## Enforced baseline

- `small`: `Standard_D2as_v5`; `medium`: `Standard_D4as_v5`, zone 1.
- Exact image `Canonical:ubuntu-24_04-lts:server:24.04.202609040`, x64/Gen2,
  verified by read-only Sweden Central image discovery in `catalog/platform.json`.
  That verifies publication, not allocation capacity or successful deployment.
- Trusted Launch (secure boot and vTPM); encryption at host; 64-GiB Premium LRS
  OS disk; system-managed boot diagnostics; platform patch assessment/patching.
- Private NIC only, explicit no public IP, no forwarding. Existing subnet NSG
  must allow SSH only from the approved private management source and have
  default outbound disabled with approved NAT-backed egress.
- SSH-key-only `platformadmin`; credential/key generation disabled. The
  synthetic public key in the example **must be replaced**. No private key
  or password input, generated secret, provisioning script, or run command.
- System identity, Azure resource metrics to the provided workspace, AVM
  telemetry disabled and platform-enforced tags.

TLS/HTTPS public ingress settings are not VM properties: this sample exposes
only private SSH, not an HTTP server. VM guest logs/AMA/DCR are **not** configured;
resource metrics and boot diagnostics are not full guest security monitoring.
Microsoft-managed disk keys are not a customer-managed-key compliance claim.
NAT is not a destination-filtering firewall. Public Azure Monitor is a demo exception.

## Contract

Common: `name`, `location` (only `swedencentral`), `size`, `resource_group_name`,
`log_analytics_workspace_resource_id`, `tags`.
Service: `subnet_resource_id`, `ssh_public_key`. No image/security/size-SKU
passthrough. All shared infrastructure is externally owned. Before a connected
run, verify regional quota, zone/size/image compatibility, Trusted Launch and
encryption-at-host support/feature registration using platform preflight.

Terraform **1.13.5** and provider pins are exact; review
[module closure/provenance](../../../catalog/terraform-dependencies.json).
The provider lock does not lock modules. AzureRM's exact provider controls the
VM/NIC API versions; wrapper-level API switches are not invented.

## Verification and cleanup

Validation and mocked-provider tests are offline checks, not live provisioning.
Connected plan/apply requires separate approval, OIDC and private runner/state
connectivity. Keep saved plans/state private.
After the demo, review destruction against only this workload's state; include
the attached OS disk/NIC and verify no orphaned chargeable resources remain.
Preserve shared networking, workspace and state. Do not destroy the foundation
or another engine's resources as a shortcut.

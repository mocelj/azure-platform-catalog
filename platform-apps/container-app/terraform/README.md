# Private Container App Terraform root

The root composes official AVM Container App `0.9.0`, managed environment `0.5.0`,
and private endpoint `0.2.0`. The [example](../../../examples/platform/container-app/terraform/README.md)
shows validation and state configuration.

## Configuration

A dedicated VNet-injected workload-profiles environment uses a Consumption
profile. Its infrastructure subnet is separate from both private endpoints and
the Bicep environment. Environment `publicNetworkAccess` is disabled, while
`internal = false` supports the Private Link design. The endpoint connects to
`managedEnvironments` using `privatelink.swedencentral.azurecontainerapps.io`.

App `external_enabled = true` allows clients outside the environment to reach it
through that private endpoint. Insecure ingress is disabled. Frontend TLS uses
the Container Apps platform baseline of 1.2 or later; this AVM version does not
offer a minimum-TLS override. The container listens on HTTP port 80 behind
platform TLS termination.

`small` provides 0.25 vCPU/0.5Gi with 0-2 replicas; `medium` provides
0.5 vCPU/1Gi with 0-3 replicas. The image digest and port match
`catalog/platform.json` and are not developer inputs.

The app and environment use system identities. Environment console/system logs
and metrics go to the workspace through the `azure-monitor` destination and
diagnostic settings, without reading a workspace shared key. Azure Monitor uses
public endpoints. Catalog tags take precedence over supplied metadata, and AVM
telemetry is disabled.

Common inputs: `name`, `location` (only `swedencentral`), `size`,
`resource_group_name`, `log_analytics_workspace_resource_id`, `tags`.
Service: `private_endpoint_subnet_resource_id`, `private_dns_zone_resource_id`,
`infrastructure_subnet_resource_id`. The foundation owns delegated subnets,
NSGs, NAT, DNS, and workspace. NAT supplies outbound connectivity without
destination filtering.

## API and image considerations

The app API is `2025-02-02-preview`; the environment API is
`2025-10-02-preview`. Diagnostic utilities also use a preview API listed in the
[dependency inventory](../../../catalog/terraform-dependencies.json). Review
these previews against production support requirements.

The MCR hello-world image is an older Microsoft sample for demonstrating the
platform, not a hardened application. Digest pinning makes it repeatable but
does not replace image assessment. Terraform `1.13.5` and providers use a
committed lock, with module versions and provenance tracked separately.

## Verification and cleanup

Source checks and real backend-disabled initialization/validation pass.
Terraform `1.13.5` cannot mock an upstream ephemeral resource schema, even at
count zero, so this root has no environment, app, or endpoint mocked plans.
The upstream modules remain unchanged.

Before the first Azure deployment, check subnet capacity/delegation, regional
and API availability, and runner connectivity. Deployment tests still need to
cover Private Link/DNS, image startup, NAT routing, and application health.

Cleanup uses a destroy plan for this target's state. The environment and Private
Link have costs independent of application scale-to-zero. Preserve shared
resources and the Bicep environment, and retain private plans/state under the
deployment retention policy.

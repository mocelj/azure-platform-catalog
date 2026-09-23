# Private Container App — Terraform root

Official AVM Container App **0.9.0**, managed environment **0.5.0** and separate
private endpoint **0.2.0**. See
[the runnable example](../../../examples/platform/container-app/terraform/README.md).

## Enforced baseline

- Dedicated VNet-injected **workload-profiles** environment, Consumption profile,
  infrastructure subnet separate from endpoints and from the Bicep environment.
- Environment `publicNetworkAccess = Disabled`. External-load-balancer mode
  (`internal = false`) deliberately supports Private Link: there is **no public
  workload ingress**. Separate PE group **managedEnvironments**, using
  `privatelink.swedencentral.azurecontainerapps.io`.
- App `external_enabled = true` accepts clients outside the environment **via
  that PE**, not through a public endpoint. Insecure ingress is disabled; HTTPS
  frontend uses Container Apps' platform TLS baseline (1.2 or later). The pinned
  AVM ingress contract does not expose a minimum-TLS-version override.
- `small`: 0.25 vCPU/0.5Gi, 0–2 replicas; `medium`: 0.5 vCPU/1Gi, 0–3 replicas.
- Exact Microsoft hello-world digest/port from `catalog/platform.json`, hardcoded
  and parity-tested; no arbitrary image input. Port 80 is HTTP inside the
  platform TLS termination boundary, not public insecure frontend ingress.
- App/environment system identities. Azure Monitor log destination
  **azure-monitor**, with environment console/system logs and metrics routed to
  the provided workspace through diagnostics. No workspace shared key is read.
  Public Azure Monitor is a disclosed demo exception.
- Platform tags override conflicting metadata; telemetry off in all AVMs.

Common inputs: `name`, `location` (only `swedencentral`), `size`,
`resource_group_name`, `log_analytics_workspace_resource_id`, `tags`.
Service: `private_endpoint_subnet_resource_id`, `private_dns_zone_resource_id`,
`infrastructure_subnet_resource_id`. The foundation owns delegated subnets,
NSGs, NAT, DNS and workspace. NAT is not destination-filtering security.

## Preview and supply-chain disclosure

App API **2025-02-02-preview**; environment API **2025-10-02-preview**.
Utility diagnostics also use the Azure Monitor preview API recorded in the
[full dependency/API inventory](../../../catalog/terraform-dependencies.json).
These upstream previews are explicit accepted demo exceptions, not GA claims.
The public Microsoft sample image is illustrative, not FSI-hardened or a
production workload. Digest pinning is not a vulnerability assessment.
Terraform **1.13.5** and exact providers have a committed lock file; exact
transitive module pins/provenance are separate.

## Verification and cleanup

This root has source-contract checks and real backend-free init/validate.
Terraform 1.13.5 cannot mock the upstream environment's ephemeral resource schema
(even at count zero), so no mocked app, private-endpoint or environment plan
coverage is claimed. Upstream source remains unchanged.

Offline checks do not verify actual Azure allocation, Private
Link/DNS, image execution, NAT routes or application readiness. No live
deployment is claimed. Before approved deployment, verify subnet capacity,
delegation, regional support, API availability and runner private connectivity.

After use, review a destroy plan for this Terraform target only. The environment
and Private Link incur charges independently of scale-to-zero application
replicas. Preserve shared foundation, the other engine's environment and state.
Do not publish saved plans/state/tokens. Keep private plan artifacts only for
the approved retention period.

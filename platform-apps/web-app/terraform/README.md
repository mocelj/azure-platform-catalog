# Private Linux Web App — Terraform root

Official AVM site **0.23.0** and serverfarm **2.0.8** only.
See [the runnable example](../../../examples/platform/web-app/terraform/README.md).

## Enforced baseline

- One Linux worker: `small` B1, `medium` B2; no zone redundancy.
- `NODE|24-lts`, `node server.js`, always-on and HTTP/2.
  Azure manages the Node runtime patch lifecycle; this is not an immutable
  runtime patch pin. Application package release is separate from infrastructure.
- HTTPS only; site and SCM minimum TLS **1.2**. FTP, FTP basic publishing,
  SCM basic publishing and remote debugging disabled.
- Public network access disabled. Site private endpoint plus both site/SCM
  records in `privatelink.azurewebsites.net`. Deny default public access rules.
- A **separate** `Microsoft.Web/serverFarms`-delegated integration subnet;
  route-all sends outbound traffic through its pre-existing NAT association.
  Private ingress does not replace outbound VNet integration.
- System identity; plan metrics and site logs/metrics to the supplied workspace;
  enforced platform tags and AVM telemetry off.

Common inputs: `name`, `location` (only `swedencentral`), `size`,
`resource_group_name`, `log_analytics_workspace_resource_id`, `tags`.
Service: `private_endpoint_subnet_resource_id`, `private_dns_zone_resource_id`,
`integration_subnet_resource_id`. No configurable runtime/security passthrough.

## Application release boundary

The infrastructure runner must not build or execute untrusted consumer source.
A separate trusted release prepares the dependency-free `server.js` payload
and deploys its reviewed ZIP via Entra-authenticated App Service zip deployment
from a client with **private SCM** reachability. Never enable basic publishing
or temporarily open public access to make release tooling work. The infrastructure
root does not upload a payload; before trusted release the default platform page,
not the hello-world application, may be returned.

## Dependencies, verification and cleanup

Terraform **1.13.5**, exact providers and committed provider lock.
[Provenance/closure](../../../catalog/terraform-dependencies.json) additionally
locks module releases and identifies API versions; provider locks alone do not.
Offline validate/tests are not a claim of Azure deployment, quota or routing.
Connected plan/apply requires separate approval and private state access.
Azure Monitor is public and NAT does not filter destinations: demo exceptions.

Review a workload-only destroy plan after use. Both the Web App and its dedicated
App Service plan are billable until removed; do not delete shared foundation or
state. Do not publish saved plans, state, OIDC tokens or application credentials.

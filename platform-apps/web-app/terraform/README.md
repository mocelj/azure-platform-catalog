# Private Linux Web App Terraform root

This root combines official AVM site `0.23.0` and serverfarm `2.0.8`.
The [example](../../../examples/platform/web-app/terraform/README.md) covers
validation and backend setup.

## Configuration

The plan has one Linux worker, B1 for `small` or B2 for `medium`, without zone
redundancy. The site uses `NODE|24-lts`, startup command `node server.js`,
always-on, and HTTP/2. Azure manages runtime patches within the Node family.

Inbound traffic uses a site private endpoint with site and SCM records in
`privatelink.azurewebsites.net`. Public access is disabled, with default public
rules set to deny. Site and SCM require HTTPS/TLS 1.2 or later. FTP, basic
publishing, and remote debugging are disabled.

Outbound traffic uses a separate subnet delegated to
`Microsoft.Web/serverFarms`. Route-all uses that subnet's NAT association;
inbound Private Link does not replace this outbound integration. System identity,
plan metrics, and site diagnostics are enabled. Catalog tags take precedence
over caller metadata, and AVM telemetry is disabled.

Common inputs: `name`, `location` (only `swedencentral`), `size`,
`resource_group_name`, `log_analytics_workspace_resource_id`, `tags`.
Service: `private_endpoint_subnet_resource_id`, `private_dns_zone_resource_id`,
`integration_subnet_resource_id`. Runtime and security settings remain in the
wrapper rather than being exposed as arbitrary inputs.

## Application release

The infrastructure root creates hosting resources, not application content.
Build and review the dependency-free `server.js` payload outside the
infrastructure runner, then deploy its ZIP using Entra authentication from a
client with private SCM access. This works with basic publishing and public
access disabled. Until content is released, the site may serve the default
platform page rather than the sample application.

## Dependencies, verification and cleanup

Terraform `1.13.5`, pinned providers, and a committed lock provide the tooling
baseline. The [dependency inventory](../../../catalog/terraform-dependencies.json)
also records modules and APIs. Initialization, validation, and three mocked plan
runs pass; Azure deployment and private application access remain to be tested.
The public Monitor path and NAT's lack of destination filtering are covered in
the [security design](../../../docs/security-controls.md).

For cleanup, review a plan for this target only, including the site and its
dedicated App Service plan. Retain shared infrastructure and backend storage.
State, saved plans, tokens, and application credentials remain private.

import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { root, catalog } from '../scripts/platform.mjs';
import { inspectSource } from '../scripts/check.mjs';

const source = (service) => readFileSync(join(root, 'platform-apps', service, 'terraform', 'main.tf'), 'utf8');
for (const service of catalog.services) {
  test(`${service}: Terraform root is AVM-only with no first-party resources`, () => {
    assert.deepEqual(inspectSource(join(root, 'platform-apps', service, 'terraform', 'main.tf'), source(service)), []);
    assert.match(source(service), /enable_telemetry\s*=\s*false/);
  });
}
test('Container Apps source contract compensates for the upstream ephemeral mock limitation', () => {
  const code = source('container-app');
  assert.match(code, /public_network_access\s*=\s*"Disabled"/);
  assert.match(code, /infrastructure_subnet_id\s*=\s*var.infrastructure_subnet_resource_id/);
  assert.match(code, /workload_profile_type\s*=\s*"Consumption"/);
  assert.match(code, /destination\s*=\s*"azure-monitor"/);
  assert.match(code, /subresource_names\s*=\s*\["managedEnvironments"\]/);
  assert.match(code, /private_connection_resource_id\s*=\s*module.environment.resource_id/);
  assert.match(code, /private_dns_zone_resource_ids\s*=\s*\[var.private_dns_zone_resource_id\]/);
  assert.match(code, /external_enabled\s*=\s*true/);
  assert.match(code, /allow_insecure_connections\s*=\s*false/);
  assert.ok(code.includes(catalog.containerImage));
  assert.match(code, /target_port\s*=\s*80/);
  assert.doesNotMatch(code, /shared_key\s*=/);
});
test('Web App startup matches the sample and forces outbound VNet routing', () => {
  assert.match(source('web-app'), /app_command_line\s*=\s*"node server.js"/);
  assert.match(source('web-app'), /vnet_route_all_traffic\s*=\s*true/);
  assert.match(source('web-app'), /ftp_publish_basic_authentication_enabled\s*=\s*false/);
  assert.match(source('web-app'), /scm_publish_basic_authentication_enabled\s*=\s*false/);
});

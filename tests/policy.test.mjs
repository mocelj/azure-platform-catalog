import test from 'node:test';
import assert from 'node:assert/strict';
import { join } from 'node:path';
import { inspectSource, inspectWorkflow, withoutComments } from '../scripts/check.mjs';
import { root } from '../scripts/platform.mjs';

test('first-party Azure resource escape hatches are rejected', () => {
  assert.ok(inspectSource(join(root, 'main.bicep'), "resource x 'Microsoft.Storage/storageAccounts@2025-06-01' = {}").length);
  assert.ok(inspectSource(join(root, 'main.tf'), 'resource "azapi_resource" "x" {}').length);
  assert.ok(inspectSource(join(root, 'main.tf'), 'data "external" "x" {}').length);
  assert.ok(inspectSource(join(root, 'main.bicep'), "module x 'br/public:avm/res/web/site:latest' = {}").length);
  assert.ok(inspectSource(join(root, 'main.tf'), 'module "x" {\nsource = "attacker/web/azurerm"\nversion = "1.0.0"\n}').length);
  assert.ok(inspectSource(join(root, 'main.tf'), 'module "x" {\nsource = "Azure/avm-res-web-site/azurerm"\n}\nterraform { required_version = "1.13.5" }').length);
});
test('comments do not falsely introduce resources and URLs stay intact', () => {
  const source = "// resource example\nmodule x 'br/public:avm/res/web/site:0.24.0' = {}";
  assert.deepEqual(inspectSource(join(root, 'main.bicep'), source), []);
  assert.equal(withoutComments('"https://example.com" // comment'), '"https://example.com"  ');
});
test('unpinned actions and privileged PR triggers fail', () => {
  assert.ok(inspectWorkflow('on:\n  pull_request_target:\njobs: {}').length);
  assert.ok(inspectWorkflow('on:\n  pull_request:\njobs:\n  test:\n    steps:\n      - uses: actions/checkout@v4').length);
  assert.ok(inspectWorkflow('on:\n  pull_request:\njobs:\n  test:\n    runs-on: [self-hosted]\n    steps: []').length);
});

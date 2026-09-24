import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { root } from '../scripts/platform.mjs';
import { inspectSource } from '../scripts/check.mjs';

const folder = join(root, 'template-specs', 'web-app');
const preview = readFileSync(join(folder, 'preview.bicep'), 'utf8');
const scope = readFileSync(join(folder, 'catalog-scope.bicep'), 'utf8');
const form = JSON.parse(readFileSync(join(folder, 'uiFormDefinition.json')));
const publisher = readFileSync(join(root, 'scripts', 'Publish-WebAppTemplateSpec.ps1'), 'utf8');

test('portal package reuses the existing AVM composition with a non-overridable guard', () => {
  assert.match(preview, /module webApp '\.\.\/\.\.\/platform-apps\/web-app\/bicep\/main\.bicep'/);
  assert.match(preview, /var previewOnly = true/);
  assert.match(preview, /previewOnly\s+\? fail\('PORTAL_PREVIEW_ONLY:/);
  assert.match(preview, /name: checkedName/);
  assert.deepEqual([...preview.matchAll(/^param (\w+) /gm)].map((entry) => entry[1]), ['name', 'size']);
  assert.deepEqual(inspectSource(join(folder, 'preview.bicep'), preview), []);
  assert.deepEqual(inspectSource(join(folder, 'catalog-scope.bicep'), scope), []);
  assert.match(scope, /avm\/res\/resources\/resource-group:0\.4\.4/);
  assert.doesNotMatch(scope, /roleAssignments/);
});
test('native form exposes only application name and the two existing profiles', () => {
  assert.equal(form.$schema, 'https://schema.management.azure.com/schemas/2021-09-09/uiFormDefinition.schema.json#');
  assert.equal(form.view.kind, 'Form');
  const elements = form.view.properties.steps.flatMap((step) => step.elements);
  assert.ok(elements.every((element) => ['Microsoft.Common.InfoBox', 'Microsoft.Common.TextBox', 'Microsoft.Common.DropDown'].includes(element.type)));
  const editable = elements.filter((element) => element.type !== 'Microsoft.Common.InfoBox');
  assert.deepEqual(editable.map((element) => element.name), ['name', 'size']);
  const name = editable[0];
  const pattern = new RegExp(name.constraints.validations[0].regex);
  assert.ok(pattern.test('ledger'));
  for (const invalid of ['a', 'Uppercase', '../resource', 'x'.repeat(21)]) assert.equal(pattern.test(invalid), false);
  assert.deepEqual(editable[1].constraints.allowedValues.map((item) => item.value), ['small', 'medium']);
  assert.equal(editable[1].defaultValue, 'Small (B1)');
  assert.ok(elements.some((element) => element.options?.text.includes('blocks workload deployment')));
});
test('form context is injected at publication and no foundation settings are editable', () => {
  assert.deepEqual(form.view.outputs, {
    kind: 'ResourceGroup',
    resourceGroupId: '__CATALOG_RESOURCE_GROUP_ID__',
    location: 'swedencentral',
    parameters: { name: "[steps('application').name]", size: "[steps('application').size]" }
  });
  assert.doesNotMatch(JSON.stringify(form), /[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/i);
});
test('publisher is scoped to catalog metadata and verifies the preview before upload', () => {
  assert.match(publisher, /'deployment', 'sub', 'create'/);
  assert.match(publisher, /'deployment', 'group', 'validate'/);
  assert.match(publisher, /'ts', 'create'/);
  assert.doesNotMatch(publisher, /'deployment', 'group', 'create'|'webapp', 'create'|role assignment create/);
  assert.ok(publisher.indexOf('\nTest-PreviewGuard\n') < publisher.indexOf("$null = Invoke-Azure @('ts', 'create'"));
  assert.match(publisher, /This version will not be overwritten/);
  assert.match(publisher, /Test-Json/);
});

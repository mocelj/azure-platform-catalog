# Web App Template Spec: portal preview

This package puts the existing AVM Web App composition behind a native Azure
Portal form. It is intended to evaluate the UI before choosing a broader
self-service portal.

The form asks for an application name and a service profile: Small/B1 or
Medium/B2. Region, private access, TLS, identity and network integration remain
platform decisions. A second tab explains those settings without exposing
foundation resource IDs.

## Preview, not workload deployment

`preview.bicep` calls the existing Web App wrapper, which still uses
`avm/res/web/serverfarm:0.7.0` and `avm/res/web/site:0.24.0`.
Its fixed `previewOnly` constant invokes Bicep's `fail` function while evaluating
the nested deployment's parameters. No caller parameter can turn that guard off.

The form is usable, but this version cannot provision a Web App. The empty
foundation inputs are never reached: they are not being used as the safety
mechanism. A deployable version needs a separately reviewed foundation binding,
permissions and deployment scope.

Publication creates only a dedicated resource group and Template Spec metadata.
The group is created through AVM; Microsoft's `az ts` tooling publishes the
compiled artifact. No new base workload IaC is maintained here.

## Build and publish

Use PowerShell 7.4 or later, Azure CLI 2.88.0 and the catalog's local Bicep
0.47.16 compiler. Supply your confirmed subscription explicitly:

```powershell
$settings = @{
    SubscriptionId    = '<subscription-id>'
    ResourceGroupName = 'rg-platform-catalog-ui-demo'
    Location          = 'swedencentral'
    SpecName          = 'ts-private-web-app'
    Version           = '0.1.0-preview'
}

.\scripts\Publish-WebAppTemplateSpec.ps1 -Mode Build @settings
.\scripts\Publish-WebAppTemplateSpec.ps1 -Mode Preflight @settings
```

`Build` writes generated files under ignored `out\template-specs\web-app`.
It checks the compiled guard, validates the form against Microsoft's
`2021-09-09` schema, and records source/version/hash information.
`Preflight` validates the metadata resource-group scope and saves its what-if
result. Neither mode creates Azure resources.

After reviewing that result and approving metadata publication:

```powershell
.\scripts\Publish-WebAppTemplateSpec.ps1 -Mode Publish @settings
.\scripts\Publish-WebAppTemplateSpec.ps1 -Mode Verify @settings
```

Publish requires a clean, committed checkout. It verifies the guard through
ARM validation, refuses unrelated existing resources and does not replace an
existing version with different content. Verify from the same source commit
used to build the published package. A source change requires a new explicit
preview version rather than replacing the old artifact.

Template Spec API `2022-02-01` is used for readback. The publication receipt
contains the version-specific portal link and resource inventory. Keep it
local because it contains subscription information.

## Inspect the Azure Portal form

Open the `portalFormUrl` from `publication.json`, or find the Template Spec in
the Azure Portal, select its preview version and open its deployment form.

1. Confirm the **UI preview** title and notice.
2. Try an invalid application name, then a valid name such as `ledger`.
3. Switch between Small/B1 and Medium/B2.
4. Inspect the platform settings tab.
5. Stop before final Create/Deploy submission.

This is the Azure Portal's `uiFormDefinition` format, not a custom web frontend
or a Managed Applications `createUiDefinition` package. Form view uses
`InfoBox.options.style`; its schema differs from some shared-control examples.

The portal uses the signed-in user's Azure permissions. It does not inherit the
GitHub approval workflow or deploy on behalf of a developer through the catalog
runner. Template Spec visibility and deployment permissions are separate
considerations for any production design.

## Validation and cleanup

Repository checks cover the form interface, fixed preview guard, publication
scope and unchanged AVM references. The publisher also checks the schema,
compiled package size, expected ARM guard failure and uploaded content hashes.
Portal appearance and field behavior need to be inspected in the actual portal.

There are no App Service, networking, storage or monitoring resources to clean
up from this prototype. If the preview is no longer needed, review the dedicated
group's inventory before an explicitly approved deletion. The helper never
deletes resources automatically.

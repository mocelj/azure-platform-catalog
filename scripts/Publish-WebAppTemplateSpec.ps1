#requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Build', 'Preflight', 'Publish', 'Verify')][string]$Mode,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F-]{36}$')][string]$SubscriptionId,
    [Parameter(Mandatory)][ValidatePattern('^rg-[a-z0-9-]{3,70}$')][string]$ResourceGroupName,
    [Parameter(Mandatory)][ValidateSet('swedencentral')][string]$Location,
    [Parameter(Mandatory)][ValidatePattern('^[a-z][a-z0-9-]{2,60}$')][string]$SpecName,
    [Parameter(Mandatory)][ValidatePattern('^\d+\.\d+\.\d+-preview$')][string]$Version
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$root = Split-Path $PSScriptRoot -Parent
$definition = Join-Path $root 'template-specs/web-app'
$output = Join-Path $root "out/template-specs/web-app/$Version"
$bicep = Join-Path $root ('.tools/' + $(if ($IsWindows) { 'bicep.exe' } else { 'bicep' }))
$groupId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName"
$specId = "$groupId/providers/Microsoft.Resources/templateSpecs/$SpecName"
$versionId = "$specId/versions/$Version"
$apiVersion = '2022-02-01'
$purpose = 'platform-catalog-ui-preview'
$guard = 'PORTAL_PREVIEW_ONLY:'
New-Item -ItemType Directory -Path $output -Force | Out-Null

function Invoke-Azure {
    param([string[]]$Arguments)
    $result = & az @Arguments --subscription $SubscriptionId --output json --only-show-errors 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Azure CLI failed ($($Arguments[0..1] -join ' ')):`n$($result -join "`n")" }
    $text = $result -join "`n"
    if ($text.Trim()) {
        try { return ($text | ConvertFrom-Json -AsHashtable -Depth 100) }
        catch {
            [IO.File]::WriteAllText((Join-Path $output 'unexpected-azure-output.txt'), $text, [Text.UTF8Encoding]::new($false))
            throw "Azure CLI returned non-JSON output for $($Arguments[0..1] -join ' '). See $output/unexpected-azure-output.txt."
        }
    }
}

function ConvertTo-CanonicalValue {
    param([AllowNull()]$Value)
    if ($Value -is [System.Collections.IDictionary]) {
        $sorted = [System.Collections.Generic.SortedDictionary[string,object]]::new([StringComparer]::Ordinal)
        foreach ($key in $Value.Keys) { $sorted[$key] = ConvertTo-CanonicalValue -Value $Value[$key] }
        return $sorted
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $items = [System.Collections.Generic.List[object]]::new()
        foreach ($item in $Value) { $items.Add((ConvertTo-CanonicalValue -Value $item)) }
        return ,($items.ToArray())
    }
    return $Value
}

function Get-ContentHash {
    param($Value)
    $json = ConvertTo-Json -InputObject (ConvertTo-CanonicalValue -Value $Value) -Depth 100 -Compress
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($json))).ToLowerInvariant()
}

function Write-Json {
    param([string]$Path, $Value)
    [IO.File]::WriteAllText($Path, (ConvertTo-Json -InputObject $Value -Depth 100) + "`n", [Text.UTF8Encoding]::new($false))
}

function Assert-Inventory {
    $resources = @(Invoke-Azure @('resource', 'list', '--resource-group', $ResourceGroupName))
    $unexpected = @($resources | Where-Object { $_.type -notin @('Microsoft.Resources/templateSpecs', 'Microsoft.Resources/templateSpecs/versions') })
    if ($unexpected.Count) { throw 'The catalog group contains resources outside the publication-only scope. No further changes were made.' }
    return $resources
}

function Test-PreviewGuard {
    $arguments = @('deployment', 'group', 'validate', '--resource-group', $ResourceGroupName,
        '--template-file', (Join-Path $output 'mainTemplate.json'), '--parameters', 'name=portal-preview', 'size=small',
        '--validation-level', 'Template', '--subscription', $SubscriptionId, '--output', 'json', '--only-show-errors')
    $result = & az @arguments 2>&1
    $code = $LASTEXITCODE
    $message = $result -join "`n"
    [IO.File]::WriteAllText((Join-Path $output 'guard-validation.txt'), $message, [Text.UTF8Encoding]::new($false))
    if ($code -eq 0) { throw 'Preview validation unexpectedly succeeded. Refusing to publish.' }
    if (-not $message.Contains($guard) -or $message -match 'not recognized|not a valid template function|could not be found|unknown function') {
        throw "ARM validation did not return the expected preview guard failure. Inspect $output/guard-validation.txt."
    }
    Write-Host 'ARM validation stopped at the preview guard. No workload deployment was submitted.'
}

function Assert-Readback {
    $remote = Invoke-Azure @('rest', '--method', 'get', '--url', "https://management.azure.com${versionId}?api-version=$apiVersion")
    if ((Get-ContentHash $remote.properties.mainTemplate) -ne $manifest.templateHash -or
        (Get-ContentHash $remote.properties.uiFormDefinition) -ne $manifest.formHash) {
        throw 'Published template or form differs from the local package. This version will not be overwritten.'
    }
    if ($remote.properties.description -ne $versionDescription) { throw 'Published version provenance differs from this package.' }
    $inventory = @(Assert-Inventory)
    $receipt = @{
        templateSpecVersionId = $versionId
        version = $Version
        previewOnly = $true
        sourceCommit = $manifest.sourceCommit
        templateHash = $manifest.templateHash
        formHash = $manifest.formHash
        portalResourceUrl = "https://portal.azure.com/#resource$specId/overview"
        portalFormUrl = 'https://portal.azure.com/#create/Microsoft.Template/templateSpecVersionId/' + [Uri]::EscapeDataString($versionId)
        resources = @($inventory | ForEach-Object { @{ name = $_.name; type = $_.type } })
    }
    Write-Json (Join-Path $output 'publication.json') $receipt
    Write-Host "Template Spec version: $versionId"
    Write-Host "Portal form: $($receipt.portalFormUrl)"
    Write-Host "Publication receipt: $output/publication.json"
}

if (-not (Test-Path -LiteralPath $bicep)) { throw 'Install the pinned compiler with scripts/tooling.mjs first.' }
$compilerVersion = & $bicep --version
if ($LASTEXITCODE -ne 0 -or $compilerVersion -notmatch 'version 0\.47\.16 ') { throw 'Bicep 0.47.16 is required.' }
$cli = & az version --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $cli.'azure-cli' -ne '2.88.0') { throw 'Azure CLI 2.88.0 is required.' }
$commit = & git -C $root rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Could not identify the catalog commit.' }
if ($Mode -in @('Publish', 'Verify') -and (& git -C $root status --porcelain).Count) {
    throw 'Commit and review the catalog changes before publication or verification.'
}

& $bicep build (Join-Path $definition 'preview.bicep') --outfile (Join-Path $output 'mainTemplate.json')
if ($LASTEXITCODE -ne 0) { throw 'Preview template compilation failed.' }
& $bicep build (Join-Path $definition 'catalog-scope.bicep') --outfile (Join-Path $output 'catalog-scope.json')
if ($LASTEXITCODE -ne 0) { throw 'Publication scope compilation failed.' }
$template = Get-Content (Join-Path $output 'mainTemplate.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
if ($template.variables.previewOnly -ne $true -or $template.parameters.Keys.Count -ne 2 -or
    $template.variables.checkedName -notlike "*fail('$guard*" -or
    $template.resources.Count -ne 1 -or $template.resources[0].properties.parameters.name.value -ne "[variables('checkedName')]") {
    throw 'The compiled preview guard or parameter interface has changed.'
}
$form = Get-Content (Join-Path $definition 'uiFormDefinition.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
if ($form.view.outputs.resourceGroupId -ne '__CATALOG_RESOURCE_GROUP_ID__') { throw 'The form source must not contain a real resource-group binding.' }
$form.view.outputs.resourceGroupId = $groupId
Write-Json (Join-Path $output 'uiFormDefinition.json') $form
$schemaFile = Join-Path $output 'uiFormDefinition.schema.json'
Invoke-WebRequest 'https://schema.management.azure.com/schemas/2021-09-09/uiFormDefinition.schema.json' -OutFile $schemaFile
$schemaErrors = @()
if (-not (Test-Json -Json (Get-Content (Join-Path $output 'uiFormDefinition.json') -Raw) -SchemaFile $schemaFile -ErrorAction SilentlyContinue -ErrorVariable schemaErrors)) {
    $schemaErrors | ForEach-Object { $_.Exception.Message } | Set-Content (Join-Path $output 'schema-errors.txt')
    throw "The portal form does not match Microsoft's schema. See $output/schema-errors.txt."
}
$bytes = (Get-Item (Join-Path $output 'mainTemplate.json')).Length + (Get-Item (Join-Path $output 'uiFormDefinition.json')).Length
if ($bytes -ge 2000000) { throw 'The package is too large for this Template Spec publication policy.' }
$manifest = @{
    specName = $SpecName; version = $Version; previewOnly = $true; sourceCommit = $commit.Trim()
    bicepVersion = '0.47.16'; azureCliVersion = '2.88.0'; templateSpecApiVersion = $apiVersion
    formSchemaVersion = '2021-09-09'; packageBytes = $bytes
    avm = @{ serverfarm = '0.7.0'; site = '0.24.0'; resourceGroup = '0.4.4' }
    templateHash = Get-ContentHash $template
    formHash = Get-ContentHash $form
}
Write-Json (Join-Path $output 'package-manifest.json') $manifest
$versionDescription = "UI preview only; workload deployment blocked. Source $($manifest.sourceCommit). Bicep 0.47.16. Template $($manifest.templateHash). Form $($manifest.formHash)."
if ($Mode -eq 'Build') {
    Write-Host "Built preview package ($bytes bytes): $output"
    return
}

$account = Invoke-Azure @('account', 'show')
if ($account.id -ne $SubscriptionId -or $account.state -ne 'Enabled') { throw 'The requested subscription is unavailable or does not match.' }
$exists = Invoke-Azure @('group', 'exists', '--name', $ResourceGroupName)
if ($exists) {
    $group = Invoke-Azure @('group', 'show', '--name', $ResourceGroupName)
    if ($group.location -ne $Location -or $group.tags.purpose -ne $purpose) { throw 'The existing group is not owned by this UI prototype.' }
    $null = Assert-Inventory
}
$scopeArguments = @('--location', $Location, '--template-file', (Join-Path $output 'catalog-scope.json'),
    '--parameters', "resourceGroupName=$ResourceGroupName", "location=$Location")
if ($Mode -eq 'Preflight') {
    $null = Invoke-Azure (@('deployment', 'sub', 'validate') + $scopeArguments)
    $changes = Invoke-Azure (@('deployment', 'sub', 'what-if', '--no-pretty-print') + $scopeArguments)
    Write-Json (Join-Path $output 'publication-whatif.json') $changes
    if (@($changes.changes | Where-Object { $_.changeType -eq 'Delete' -or ($_.resourceId -ne $groupId -and $_.changeType -ne 'NoChange') }).Count) {
        throw 'Publication what-if contains an unexpected change.'
    }
    Write-Json (Join-Path $output 'preflight.json') @{
        subscriptionId = $SubscriptionId; resourceGroupName = $ResourceGroupName; location = $Location
        scopeHash = (Get-FileHash (Join-Path $output 'catalog-scope.json') -Algorithm SHA256).Hash
        checkedAt = [DateTimeOffset]::UtcNow.ToString('o')
    }
    Write-Host "Publication scope validated. Review $output/publication-whatif.json before Publish."
    return
}
if ($Mode -eq 'Verify') { Assert-Readback; return }
$preflightPath = Join-Path $output 'preflight.json'
if (-not (Test-Path -LiteralPath $preflightPath)) { throw 'Run Preflight and review its result before Publish.' }
$preflight = Get-Content $preflightPath -Raw | ConvertFrom-Json -AsHashtable
$age = [DateTimeOffset]::UtcNow - [DateTimeOffset]$preflight.checkedAt
if ($preflight.subscriptionId -ne $SubscriptionId -or $preflight.resourceGroupName -ne $ResourceGroupName -or
    $preflight.location -ne $Location -or $age.TotalHours -gt 24 -or $age.TotalSeconds -lt 0 -or
    $preflight.scopeHash -ne (Get-FileHash (Join-Path $output 'catalog-scope.json') -Algorithm SHA256).Hash) {
    throw 'The publication preflight is stale or its scope changed. Run Preflight again.'
}
if (-not $exists) {
    $null = Invoke-Azure (@('deployment', 'sub', 'create', '--name', 'platform-catalog-ui-scope') + $scopeArguments)
}
$null = Assert-Inventory
Test-PreviewGuard
$specs = @(Invoke-Azure @('ts', 'list', '--resource-group', $ResourceGroupName))
$existing = @($specs | Where-Object { $_.name -eq $SpecName })
if ($existing.Count) {
    $detail = Invoke-Azure @('rest', '--method', 'get', '--url', "https://management.azure.com${specId}?api-version=$apiVersion")
    if ($detail.tags.purpose -ne $purpose) { throw 'The existing Template Spec is not owned by this prototype.' }
    $versions = Invoke-Azure @('rest', '--method', 'get', '--url', "https://management.azure.com${specId}/versions?api-version=$apiVersion")
    if (@($versions.value | Where-Object { $_.name -eq $Version }).Count) { Assert-Readback; return }
}
$null = Invoke-Azure @('ts', 'create', '--name', $SpecName, '--version', $Version, '--resource-group', $ResourceGroupName,
    '--location', $Location, '--display-name', 'Private Web App (UI preview)',
    '--description', 'AVM-based Web App portal form. Preview version: workload deployment is blocked.',
    '--version-description', $versionDescription, '--tags', "purpose=$purpose",
    '--template-file', (Join-Path $output 'mainTemplate.json'),
    '--ui-form-definition', (Join-Path $output 'uiFormDefinition.json'), '--yes')
Assert-Readback

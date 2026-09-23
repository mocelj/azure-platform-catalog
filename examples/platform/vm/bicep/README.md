# Private Linux VM with Bicep

The VM wrapper composes `avm/res/compute/virtual-machine:0.22.3`, including the
NIC and disk. It does not add custom resource implementations or provisioning
extensions. The [dependency record](../../../../catalog/bicep-dependencies.json)
includes image metadata and API versions.

## Configuration and prerequisites

In Sweden Central, `small` selects `Standard_D2as_v5` and `medium` selects
`Standard_D4as_v5`. Both use
`Canonical:ubuntu-24_04-lts:server:24.04.202609040`, an x64 Gen2 image with
Trusted Launch support. Secure Boot and vTPM are enabled. Check current image
availability, SKU capacity, and quota before deployment.

Provide a dedicated resource group, a private VM subnet with the platform NSG
and NAT/egress configuration, and a Log Analytics workspace. SSH uses
`platformadmin` from the management network; the VM has no public IP.
Replace the sample public key with the operator's public key and keep the private
key outside parameters. The 64-GiB Standard SSD OS disk and NIC are deleted with
the VM; no data disks are created.

System identity and managed boot diagnostics are enabled. The AVM exposes NIC
diagnostic settings, so NIC `AllMetrics` goes to the workspace. Guest logs and
performance collection are not configured; they would require an Azure Monitor
Agent and data-collection-rule design.

The image pin fixes the provisioning image, not subsequent OS packages.
`ImageDefault` orchestration and platform patch assessment are configured;
ongoing patch and image lifecycle management remain platform responsibilities.
Catalog tags take precedence over supplied values, and AVM telemetry is disabled.

The module's data-disk export inputs are set to deny/disabled. Since this wrapper
creates no data disks, those settings do not restrict export of the implicit OS disk.

## Platform-team commands

From the catalog root, use the versions in `catalog\toolchain.json` and set
`BICEP_EXE` to the local compiler. Replace the example IDs and public key in a
private parameter copy before using the Azure commands.

```powershell
$bicep = $env:BICEP_EXE
& $bicep restore 'platform-apps\vm\bicep\main.bicep'
& $bicep build 'platform-apps\vm\bicep\main.bicep' --outfile 'examples\platform\vm\bicep\main.generated.json'
& $bicep build-params 'examples\platform\vm\bicep\main.bicepparam' --outfile 'examples\platform\vm\bicep\parameters.generated.json'
az account show --query '{subscription:id,tenant:tenantId}' --output json
$resourceGroup = 'rg-demo-vm-bicep'
az deployment group what-if --resource-group $resourceGroup --template-file 'examples\platform\vm\bicep\main.generated.json' --parameters '@examples\platform\vm\bicep\parameters.generated.json'
# Run only after the platform approval and what-if review.
az deployment group create --resource-group $resourceGroup --template-file 'examples\platform\vm\bicep\main.generated.json' --parameters '@examples\platform\vm\bicep\parameters.generated.json'
```

After deployment, check the NIC, management-source restrictions, key-only SSH,
and diagnostics. The wrapper and parameter example compile without warnings;
live deployment and management access remain to be tested.

## Cleanup

Retain any required VM data, then review removal of the dedicated group with
`az group delete --name rg-demo-vm-bicep`, keeping the confirmation prompt.
Leave the shared subnet, NSG, VNet, and workspace in place. Local
`main.generated.json` and `parameters.generated.json` are validation artifacts
and can be removed afterwards.

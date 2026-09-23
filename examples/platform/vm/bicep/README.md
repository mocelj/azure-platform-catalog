# Private Linux VM — platform-team Bicep example

This example has **not been live deployed**. It imports the local catalog wrapper,
which creates every resource through `avm/res/compute/virtual-machine:0.22.3`.
No inline ARM resources, scripts or custom provisioning extensions are used.

Validation on 2026-09-23: Bicep 0.47.16 restored and compiled this wrapper and its
parameter example without warnings or errors. All 13 workload contract tests
passed. This does not establish Azure deployment or runtime success.

## Fixed contract and prerequisites

- Sweden Central only; `small` = `Standard_D2as_v5`, `medium` = `Standard_D4as_v5`.
  Check regional SKU availability/quota before approval; no availability guarantee
  follows from offline compilation.
- Ubuntu 24.04 LTS image `Canonical:ubuntu-24_04-lts:server:24.04.202609040`
  is hardcoded in the wrapper; see
  `catalog\bicep-dependencies.json` for verified image and upstream API records.
  Read-only metadata confirmed x64, Gen2 and `TrustedLaunchSupported`.
  Trusted Launch, Secure Boot and vTPM are mandatory.
- A dedicated workload resource group, existing private VM subnet protected by
  the platform NSG, platform egress/NAT, and Log Analytics workspace must exist.
  The VM creates no public IP. Connect as `platformadmin` over SSH only from the
  authorized private runner/management network.
- Replace the **public** SSH-key test fixture with a platform-approved public key.
  Never put a private key or password in parameters. The 64-GiB Standard SSD
  OS disk and NIC are deleted with the VM; no data disks are created.
- System-assigned identity and managed boot diagnostics are enabled.
  **Monitoring scope:** this pinned VM AVM exposes diagnostic settings on the
  NIC, not at VM resource level. NIC `AllMetrics` goes to the supplied workspace.
  Boot diagnostics are not guest logs in Log Analytics. Guest logs/performance
  require a separately approved AVM-based Azure Monitor Agent/DCR composition;
  this wrapper does not claim that collection is configured.
- Image pinning fixes the provisioning image, not future OS package state.
  `ImageDefault` patch orchestration and platform patch assessment remain explicit;
  the platform must maintain its patch policy and image lifecycle.
- Required catalog tags override supplied values. Module telemetry is disabled.
  The AVM data-disk network-export inputs are fixed to deny/disabled, but the
  wrapper creates no data disks. These inputs do not govern the implicit OS disk;
  do not interpret them as an OS-disk export restriction.

## Platform-team commands

From the repository root, use the exact tools in `catalog\toolchain.json` and set
`BICEP_EXE` to the verified local executable. Substitute the synthetic IDs/key in
a platform-owned parameter copy; do not deploy the fixture unchanged.

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

Confirm there is no NIC public-IP association, verify private-only SSH access,
and check diagnostics after provisioning. No consumer code is executed on the
privileged runner. Restore/build are local validation, not Azure deployment tests.

## Cleanup

Save required VM data/evidence and obtain explicit approval. Delete only the
dedicated workload group with `az group delete --name rg-demo-vm-bicep`, retaining
the confirmation prompt. Shared subnet, NSG, VNet and workspace remain intact.
Remove local `main.generated.json` and `parameters.generated.json` after validation.

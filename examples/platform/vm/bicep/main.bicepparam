using '../../../../platform-apps/vm/bicep/main.bicep'

param name = 'demo-vm'
param location = 'swedencentral'
param size = 'small'
param logAnalyticsWorkspaceResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-demo-monitor/providers/Microsoft.OperationalInsights/workspaces/law-demo'
param subnetResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-demo-network/providers/Microsoft.Network/virtualNetworks/vnet-demo/subnets/vm'
// Public key for compilation tests. Replace it with your own public key before deployment.
param sshPublicKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINdamAGCsQq31Uv+08lkBzoO4XLz2qYjJa8CGmj3B1Ea public-fixture-only'
param tags = {
  owner: 'platform-team'
  costCenter: 'demo'
}

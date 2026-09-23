using '../../../../platform-apps/container-app/bicep/main.bicep'

param name = 'demo-container'
param location = 'swedencentral'
param size = 'small'
param logAnalyticsWorkspaceResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-demo-monitor/providers/Microsoft.OperationalInsights/workspaces/law-demo'
param privateEndpointSubnetResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-demo-network/providers/Microsoft.Network/virtualNetworks/vnet-demo/subnets/private-endpoints'
param privateDnsZoneResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-demo-network/providers/Microsoft.Network/privateDnsZones/privatelink.swedencentral.azurecontainerapps.io'
param infrastructureSubnetResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-demo-network/providers/Microsoft.Network/virtualNetworks/vnet-demo/subnets/container-app-bicep'
param tags = {
  owner: 'platform-team'
  costCenter: 'demo'
}

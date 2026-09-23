targetScope = 'resourceGroup'

@minLength(3)
@maxLength(20)
param name string

@allowed(['swedencentral'])
param location string = 'swedencentral'

@allowed(['small', 'medium'])
param size string = 'small'

param logAnalyticsWorkspaceResourceId string

@description('Additional resource tags. The wrapper retains the required catalog tags.')
param tags object = {}

param privateEndpointSubnetResourceId string
param privateDnsZoneResourceId string

@description('Subnet for outbound VNet integration, delegated to Microsoft.Web/serverFarms. Use a different subnet for the private endpoint.')
param integrationSubnetResourceId string

var platformTags = union(tags, {
  platform: 'avm-platform-catalog'
  environment: 'demo'
  workload: 'web-app'
  engine: 'bicep'
})
var skuBySize = {
  small: 'B1'
  medium: 'B2'
}
var siteName = 'app-${name}-${uniqueString(resourceGroup().id, name)}'

module plan 'br/public:avm/res/web/serverfarm:0.7.0' = {
  name: 'app-service-plan-${name}'
  params: {
    name: 'asp-${name}'
    location: location
    tags: platformTags
    enableTelemetry: false
    kind: 'linux'
    reserved: true
    skuName: skuBySize[size]
    skuCapacity: 1
    zoneRedundant: false
    diagnosticSettings: [{
      name: 'platform-plan-metrics'
      workspaceResourceId: logAnalyticsWorkspaceResourceId
      metricCategories: [{ category: 'AllMetrics' }]
    }]
  }
}

module site 'br/public:avm/res/web/site:0.24.0' = {
  name: 'web-app-${name}'
  params: {
    name: siteName
    location: location
    tags: platformTags
    enableTelemetry: false
    kind: 'app,linux'
    reserved: true
    serverFarmResourceId: plan.outputs.resourceId
    managedIdentities: {
      systemAssigned: true
    }
    httpsOnly: true
    publicNetworkAccess: 'Disabled'
    virtualNetworkSubnetResourceId: integrationSubnetResourceId
    outboundVnetRouting: {
      allTraffic: true
    }
    siteConfig: {
      linuxFxVersion: 'NODE|24-lts'
      alwaysOn: true
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      ftpsState: 'Disabled'
      http20Enabled: true
      remoteDebuggingEnabled: false
      vnetRouteAllEnabled: true
      appCommandLine: 'node server.js'
    }
    basicPublishingCredentialsPolicies: [
      { name: 'ftp', allow: false }
      { name: 'scm', allow: false }
    ]
    diagnosticSettings: [{
      name: 'platform-site-diagnostics'
      workspaceResourceId: logAnalyticsWorkspaceResourceId
      logCategoriesAndGroups: [{ categoryGroup: 'allLogs' }]
      metricCategories: [{ category: 'AllMetrics' }]
    }]
    privateEndpoints: [{
      name: 'pe-${name}-site'
      service: 'sites'
      location: location
      subnetResourceId: privateEndpointSubnetResourceId
      privateDnsZoneGroup: {
        privateDnsZoneGroupConfigs: [{
          privateDnsZoneResourceId: privateDnsZoneResourceId
        }]
      }
    }]
  }
}

output resourceId string = site.outputs.resourceId
output resourceName string = site.outputs.name

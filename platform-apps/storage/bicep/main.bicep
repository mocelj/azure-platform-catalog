targetScope = 'resourceGroup'

@description('Application name used to derive the storage account name.')
@minLength(3)
@maxLength(20)
param name string

@allowed(['swedencentral'])
param location string = 'swedencentral'

@allowed(['small', 'medium'])
param size string = 'small'

@description('Resource ID of the shared Log Analytics workspace.')
param logAnalyticsWorkspaceResourceId string

@description('Additional resource tags. The wrapper retains the required catalog tags.')
param tags object = {}

param privateEndpointSubnetResourceId string
param privateDnsZoneResourceId string

var platformTags = union(tags, {
  platform: 'avm-platform-catalog'
  environment: 'demo'
  workload: 'storage'
  engine: 'bicep'
})
var skuBySize = {
  small: 'Standard_LRS'
  medium: 'Standard_ZRS'
}
var storageName = 'st${take(replace(name, '-', ''), 9)}${uniqueString(resourceGroup().id, name)}'

module storage 'br/public:avm/res/storage/storage-account:0.33.1' = {
  name: 'storage-${name}'
  params: {
    name: storageName
    location: location
    tags: platformTags
    enableTelemetry: false
    kind: 'StorageV2'
    skuName: skuBySize[size]
    accessTier: 'Hot'
    publicNetworkAccess: 'Disabled'
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    requireInfrastructureEncryption: true
    allowCrossTenantReplication: false
    isLocalUserEnabled: false
    enableSftp: false
    enableNfsV3: false
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
    }
    managedIdentities: {
      systemAssigned: true
    }
    diagnosticSettings: [{
      name: 'platform-metrics'
      workspaceResourceId: logAnalyticsWorkspaceResourceId
      metricCategories: [{ category: 'AllMetrics' }]
    }]
    blobServices: {
      deleteRetentionPolicyEnabled: true
      deleteRetentionPolicyDays: 7
      containerDeleteRetentionPolicyEnabled: true
      containerDeleteRetentionPolicyDays: 7
      isVersioningEnabled: true
      diagnosticSettings: [{
        name: 'platform-blob-diagnostics'
        workspaceResourceId: logAnalyticsWorkspaceResourceId
        logCategoriesAndGroups: [{ categoryGroup: 'allLogs' }]
        metricCategories: [{ category: 'AllMetrics' }]
      }]
    }
    privateEndpoints: [{
      name: 'pe-${storageName}-blob'
      service: 'blob'
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

output resourceId string = storage.outputs.resourceId
output resourceName string = storage.outputs.name

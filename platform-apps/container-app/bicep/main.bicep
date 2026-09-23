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

@description('Infrastructure subnet for the workload-profiles environment, delegated to Microsoft.App/environments.')
param infrastructureSubnetResourceId string

var platformTags = union(tags, {
  platform: 'avm-platform-catalog'
  environment: 'demo'
  workload: 'container-app'
  engine: 'bicep'
})
var profiles = {
  small: {
    cpu: json('0.25')
    memory: '0.5Gi'
    maxReplicas: 2
  }
  medium: {
    cpu: json('0.5')
    memory: '1Gi'
    maxReplicas: 3
  }
}
var selectedProfile = profiles[size]
var platform = loadJsonContent('../../../catalog/platform.json')

module environment 'br/public:avm/res/app/managed-environment:0.16.0' = {
  name: 'container-environment-${name}'
  params: {
    name: 'cae-${name}'
    location: location
    tags: platformTags
    enableTelemetry: false
    infrastructureSubnetResourceId: infrastructureSubnetResourceId
    // This environment uses Private Link for inbound access, with public access disabled.
    internal: false
    publicNetworkAccess: 'Disabled'
    zoneRedundant: false
    peerTrafficEncryption: true
    managedIdentities: {
      systemAssigned: true
    }
    workloadProfiles: [{
      name: 'Consumption'
      workloadProfileType: 'Consumption'
    }]
    appLogsConfiguration: {
      destination: 'azure-monitor'
    }
    diagnosticSettings: [{
      name: 'platform-environment-diagnostics'
      workspaceResourceId: logAnalyticsWorkspaceResourceId
      logCategoriesAndGroups: [{ categoryGroup: 'allLogs' }]
      metricCategories: [{ category: 'AllMetrics' }]
    }]
    privateEndpoints: [{
      name: 'pe-${name}-environment'
      service: 'managedEnvironments'
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

module app 'br/public:avm/res/app/container-app:0.23.0' = {
  name: 'container-app-${name}'
  params: {
    name: 'ca-${name}'
    location: location
    tags: platformTags
    enableTelemetry: false
    environmentResourceId: environment.outputs.resourceId
    managedIdentities: {
      systemAssigned: true
    }
    workloadProfileName: 'Consumption'
    activeRevisionsMode: 'Single'
    disableIngress: false
    // Allows callers outside this environment, but only through its private endpoint.
    ingressExternal: true
    ingressAllowInsecure: false
    ingressTargetPort: platform.containerPort
    ingressTransport: 'auto'
    containers: [{
      name: 'hello'
      image: platform.containerImage
      resources: {
        cpu: selectedProfile.cpu
        memory: selectedProfile.memory
      }
    }]
    scaleSettings: {
      minReplicas: 0
      maxReplicas: selectedProfile.maxReplicas
    }
    diagnosticSettings: [{
      name: 'platform-app-metrics'
      workspaceResourceId: logAnalyticsWorkspaceResourceId
      metricCategories: [{ category: 'AllMetrics' }]
    }]
  }
}

output resourceId string = app.outputs.resourceId
output resourceName string = app.outputs.name
output environmentResourceId string = environment.outputs.resourceId

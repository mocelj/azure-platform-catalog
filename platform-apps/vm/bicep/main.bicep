targetScope = 'resourceGroup'

@minLength(3)
@maxLength(20)
param name string

@allowed(['swedencentral'])
param location string = 'swedencentral'

@allowed(['small', 'medium'])
param size string = 'small'

@description('Platform-owned Log Analytics workspace resource ID for NIC metrics.')
param logAnalyticsWorkspaceResourceId string

@description('Platform-owned metadata; mandatory catalog tags cannot be overridden.')
param tags object = {}

param subnetResourceId string

@description('SSH PUBLIC key only. No password or private key is accepted.')
param sshPublicKey string

var platformTags = union(tags, {
  platform: 'avm-platform-catalog'
  environment: 'demo'
  workload: 'vm'
  engine: 'bicep'
})
var vmSizeBySize = {
  small: 'Standard_D2as_v5'
  medium: 'Standard_D4as_v5'
}

module virtualMachine 'br/public:avm/res/compute/virtual-machine:0.22.3' = {
  name: 'virtual-machine-${name}'
  params: {
    name: 'vm-${name}'
    location: location
    tags: platformTags
    enableTelemetry: false
    vmSize: vmSizeBySize[size]
    osType: 'Linux'
    availabilityZone: -1
    adminUsername: 'platformadmin'
    disablePasswordAuthentication: true
    publicKeys: [{
      path: '/home/platformadmin/.ssh/authorized_keys'
      keyData: sshPublicKey
    }]
    imageReference: {
      publisher: 'Canonical'
      offer: 'ubuntu-24_04-lts'
      sku: 'server'
      version: '24.04.202609040'
    }
    securityType: 'TrustedLaunch'
    secureBootEnabled: true
    vTpmEnabled: true
    publicNetworkAccess: 'Disabled'
    networkAccessPolicy: 'DenyAll'
    osDisk: {
      createOption: 'FromImage'
      deleteOption: 'Delete'
      diskSizeGB: 64
      caching: 'ReadWrite'
      managedDisk: {
        storageAccountType: 'StandardSSD_LRS'
      }
    }
    managedIdentities: {
      systemAssigned: true
    }
    provisionVMAgent: true
    patchMode: 'ImageDefault'
    patchAssessmentMode: 'AutomaticByPlatform'
    bootDiagnostics: true
    nicConfigurations: [{
      name: 'nic-${name}'
      deleteOption: 'Delete'
      enableIPForwarding: false
      enableAcceleratedNetworking: false
      enableTelemetry: false
      tags: platformTags
      diagnosticSettings: [{
        name: 'platform-nic-metrics'
        workspaceResourceId: logAnalyticsWorkspaceResourceId
        metricCategories: [{ category: 'AllMetrics' }]
      }]
      ipConfigurations: [{
        name: 'primary'
        subnetResourceId: subnetResourceId
        privateIPAllocationMethod: 'Dynamic'
        privateIPAddressVersion: 'IPv4'
      }]
    }]
  }
}

output resourceId string = virtualMachine.outputs.resourceId
output resourceName string = virtualMachine.outputs.name

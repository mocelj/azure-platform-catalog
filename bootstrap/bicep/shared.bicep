targetScope = 'resourceGroup'

param namePrefix string
param location string
param approvedManagementCidr string
param catalogRepository string
param availabilityZone int
param tags object

var managementNetwork = parseCidr(approvedManagementCidr)
var managementOctets = split(managementNetwork.network, '.')
var privateManagement = (managementOctets[0] == '10' && managementNetwork.cidr >= 8) || (managementOctets[0] == '172' && int(managementOctets[1]) >= 16 && int(managementOctets[1]) <= 31 && managementNetwork.cidr >= 12) || (managementOctets[0] == '192' && managementOctets[1] == '168' && managementNetwork.cidr >= 16)
var checkedManagementCidr = privateManagement
  ? approvedManagementCidr
  : fail('approvedManagementCidr must be an explicitly approved RFC1918 IPv4 subnet, never an internet range.')
var phases = ['plan', 'apply']
var vnetName = 'vnet-${namePrefix}-demo'
var subnetNames = {
  vm: 'snet-vm'
  privateEndpoints: 'snet-private-endpoints'
  webApp: 'snet-web-app'
  containerAppBicep: 'snet-container-app-bicep'
  containerAppTerraform: 'snet-container-app-terraform'
}
var dnsZoneNames = [
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.azurewebsites.net'
  'privatelink.swedencentral.azurecontainerapps.io'
]
var storageName = 'st${uniqueString(subscription().id, resourceGroup().id, namePrefix)}'

module identities 'br/public:avm/res/managed-identity/user-assigned-identity:0.6.0' = [for phase in phases: {
  name: '${namePrefix}-${phase}-identity'
  params: {
    name: 'id-${namePrefix}-demo-${phase}'
    location: location
    tags: tags
    enableTelemetry: false
    federatedIdentityCredentials: [{
      name: 'github-demo-${phase}'
      issuer: 'https://token.actions.githubusercontent.com'
      audiences: ['api://AzureADTokenExchange']
      subject: 'repo:${catalogRepository}:environment:demo-${phase}'
    }]
  }
}]

var principalIds = [identities[0].outputs.principalId, identities[1].outputs.principalId]
var subnetRoles = [
  {
    principalId: identities[0].outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionIdOrName: 'Network Contributor'
  }
  {
    principalId: identities[1].outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionIdOrName: 'Network Contributor'
  }
]
var blobRoles = [
  {
    principalId: identities[0].outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionIdOrName: 'Storage Blob Data Contributor'
  }
  {
    principalId: identities[1].outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionIdOrName: 'Storage Blob Data Contributor'
  }
]

module sharedReaders 'br/public:avm/res/authorization/role-assignment/rg-scope:0.1.1' = [for (phase, i) in phases: {
  name: '${namePrefix}-${phase}-shared-reader'
  params: {
    principalId: identities[i].outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionIdOrName: 'Reader'
    description: 'Read foundation IDs and properties; no shared-resource control-plane writes.'
    enableTelemetry: false
  }
}]

module vmNsg 'br/public:avm/res/network/network-security-group:0.5.3' = {
  name: '${namePrefix}-vm-nsg'
  params: {
    name: 'nsg-${namePrefix}-demo-vm'
    location: location
    tags: tags
    enableTelemetry: false
    securityRules: [
      {
        name: 'AllowApprovedPrivateManagementSsh'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: checkedManagementCidr
          sourcePortRange: '*'
          destinationAddressPrefix: '10.40.1.0/24'
          destinationPortRange: '22'
        }
      }
      {
        name: 'DenyAllOtherInbound'
        properties: {
          priority: 110
          access: 'Deny'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

module egressPublicIp 'br/public:avm/res/network/public-ip-address:0.13.0' = {
  name: '${namePrefix}-egress-pip'
  params: {
    name: 'pip-${namePrefix}-demo-egress'
    location: location
    skuName: 'Standard'
    skuTier: 'Regional'
    availabilityZones: [availabilityZone]
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    tags: tags
    enableTelemetry: false
  }
}

module nat 'br/public:avm/res/network/nat-gateway:2.1.1' = {
  name: '${namePrefix}-nat'
  params: {
    name: 'nat-${namePrefix}-demo'
    location: location
    natGatewaySku: 'Standard'
    availabilityZone: availabilityZone
    idleTimeoutInMinutes: 10
    publicIpResourceIds: [egressPublicIp.outputs.resourceId]
    tags: tags
    enableTelemetry: false
  }
}

module vnet 'br/public:avm/res/network/virtual-network:0.10.2' = {
  name: '${namePrefix}-vnet'
  params: {
    name: vnetName
    location: location
    addressPrefixes: ['10.40.0.0/16']
    tags: tags
    enableTelemetry: false
    subnets: [
      {
        name: subnetNames.vm
        addressPrefix: '10.40.1.0/24'
        networkSecurityGroupResourceId: vmNsg.outputs.resourceId
        defaultOutboundAccess: false
        natGatewayResourceId: nat.outputs.resourceId
        roleAssignments: subnetRoles
      }
      {
        name: subnetNames.privateEndpoints
        addressPrefix: '10.40.2.0/24'
        privateEndpointNetworkPolicies: 'Disabled'
        roleAssignments: subnetRoles
      }
      {
        name: subnetNames.webApp
        addressPrefix: '10.40.3.0/24'
        delegation: 'Microsoft.Web/serverFarms'
        natGatewayResourceId: nat.outputs.resourceId
        roleAssignments: subnetRoles
      }
      {
        name: subnetNames.containerAppBicep
        addressPrefix: '10.40.4.0/24'
        delegation: 'Microsoft.App/environments'
        natGatewayResourceId: nat.outputs.resourceId
        roleAssignments: subnetRoles
      }
      {
        name: subnetNames.containerAppTerraform
        addressPrefix: '10.40.5.0/24'
        delegation: 'Microsoft.App/environments'
        natGatewayResourceId: nat.outputs.resourceId
        roleAssignments: subnetRoles
      }
    ]
  }
}

module privateDns 'br/public:avm/res/network/private-dns-zone:0.8.1' = [for (zoneName, i) in dnsZoneNames: {
  name: '${namePrefix}-private-dns-${i}'
  params: {
    name: zoneName
    location: 'global'
    tags: tags
    enableTelemetry: false
    virtualNetworkLinks: [{
      name: '${vnetName}-link'
      virtualNetworkResourceId: vnet.outputs.resourceId
      registrationEnabled: false
    }]
    roleAssignments: [for i in range(0, length(phases)): {
      principalId: identities[i].outputs.principalId
      principalType: 'ServicePrincipal'
      roleDefinitionIdOrName: 'Private DNS Zone Contributor'
    }]
  }
}]

module workspace 'br/public:avm/res/operational-insights/workspace:0.16.1' = {
  name: '${namePrefix}-workspace'
  params: {
    name: 'log-${namePrefix}-demo'
    location: location
    skuName: 'PerGB2018'
    dataRetention: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    forceCmkForQuery: false
    features: {
      disableLocalAuth: true
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    tags: tags
    enableTelemetry: false
  }
}

module stateStorage 'br/public:avm/res/storage/storage-account:0.33.1' = {
  name: '${namePrefix}-state'
  params: {
    name: storageName
    location: location
    kind: 'StorageV2'
    skuName: 'Standard_LRS'
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    publicNetworkAccess: 'Disabled'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    requireInfrastructureEncryption: true
    isLocalUserEnabled: false
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
    }
    blobServices: {
      isVersioningEnabled: true
      deleteRetentionPolicyEnabled: true
      deleteRetentionPolicyDays: 14
      containerDeleteRetentionPolicyEnabled: true
      containerDeleteRetentionPolicyDays: 14
      deleteRetentionPolicyAllowPermanentDelete: false
      containerDeleteRetentionPolicyAllowPermanentDelete: false
      containers: [
        {
          name: 'tfstate'
          publicAccess: 'None'
          roleAssignments: blobRoles
        }
        {
          name: 'plans'
          publicAccess: 'None'
          roleAssignments: blobRoles
        }
      ]
      diagnosticSettings: [{
        name: 'blob-audit'
        workspaceResourceId: workspace.outputs.resourceId
        logCategoriesAndGroups: [{ categoryGroup: 'allLogs' }]
        metricCategories: [{ category: 'AllMetrics' }]
      }]
    }
    fileServices: {}
    queueServices: {}
    tableServices: {}
    privateEndpoints: [{
      name: 'pe-${namePrefix}-state-blob'
      location: location
      service: 'blob'
      subnetResourceId: vnet.outputs.subnetResourceIds[1]
      privateDnsZoneGroup: {
        name: 'default'
        privateDnsZoneGroupConfigs: [{
          privateDnsZoneResourceId: privateDns[0].outputs.resourceId
        }]
      }
    }]
    tags: tags
    enableTelemetry: false
  }
}

output deploymentPrincipalIds array = principalIds
output deploymentIdentities object = {
  'demo-plan': {
    clientId: identities[0].outputs.clientId
    principalId: identities[0].outputs.principalId
    resourceId: identities[0].outputs.resourceId
    subject: 'repo:${catalogRepository}:environment:demo-plan'
  }
  'demo-apply': {
    clientId: identities[1].outputs.clientId
    principalId: identities[1].outputs.principalId
    resourceId: identities[1].outputs.resourceId
    subject: 'repo:${catalogRepository}:environment:demo-apply'
  }
}
output network object = {
  vmSubnetResourceId: vnet.outputs.subnetResourceIds[0]
  privateEndpointSubnetResourceId: vnet.outputs.subnetResourceIds[1]
  webAppSubnetResourceId: vnet.outputs.subnetResourceIds[2]
  containerAppBicepSubnetResourceId: vnet.outputs.subnetResourceIds[3]
  containerAppTerraformSubnetResourceId: vnet.outputs.subnetResourceIds[4]
}
output privateDnsZones object = {
  storage: privateDns[0].outputs.resourceId
  'web-app': privateDns[1].outputs.resourceId
  'container-app': privateDns[2].outputs.resourceId
}
output logAnalyticsWorkspaceResourceId string = workspace.outputs.resourceId
output state object = {
  resourceGroupName: resourceGroup().name
  storageAccountName: stateStorage.outputs.name
  containerName: 'tfstate'
  planContainerName: 'plans'
}
output foundationResourceIds object = {
  sharedResourceGroup: resourceGroup().id
  vnet: vnet.outputs.resourceId
  vmNetworkSecurityGroup: vmNsg.outputs.resourceId
  natGateway: nat.outputs.resourceId
  outboundPublicIp: egressPublicIp.outputs.resourceId
  stateStorage: stateStorage.outputs.resourceId
}

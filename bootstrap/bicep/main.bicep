targetScope = 'subscription'

@description('Prefix for shared platform resources, set by the platform team. Use lower-case letters and digits.')
@minLength(3)
@maxLength(12)
param namePrefix string = 'avmdemo'

@allowed(['swedencentral'])
param location string = 'swedencentral'

@description('RFC1918 IPv4 CIDR for the management network. SSH is limited to this range over existing private connectivity.')
param approvedManagementCidr string

@description('SSH public key used to access the VM examples. Keep the corresponding private key on the management host.')
@minLength(32)
param sshPublicKey string

@description('GitHub repository that runs the platform deployment workflows.')
param catalogRepository string = 'mocelj/azure-platform-catalog'

@description('Logical availability zone for the Standard NAT Gateway and its public IP. Confirm zone availability in the target region.')
@allowed([1, 2, 3])
param availabilityZone int = 1

var targets = [
  'storage-bicep'
  'storage-terraform'
  'vm-bicep'
  'vm-terraform'
  'web-app-bicep'
  'web-app-terraform'
  'container-app-bicep'
  'container-app-terraform'
]
var sharedResourceGroupName = 'rg-${namePrefix}-demo-shared'
var tags = {
  environment: 'demo'
  platform: 'avm-golden-path'
  owner: 'platform-team'
  foundationOwner: 'bicep-bootstrap'
}

module sharedResourceGroup 'br/public:avm/res/resources/resource-group:0.4.4' = {
  name: '${namePrefix}-shared-rg'
  params: {
    name: sharedResourceGroupName
    location: location
    tags: tags
    enableTelemetry: false
  }
}

module shared './shared.bicep' = {
  name: '${namePrefix}-shared-foundation'
  scope: resourceGroup(sharedResourceGroupName)
  params: {
    namePrefix: namePrefix
    location: location
    approvedManagementCidr: approvedManagementCidr
    catalogRepository: catalogRepository
    availabilityZone: availabilityZone
    tags: tags
  }
  dependsOn: [sharedResourceGroup]
}

module workloadResourceGroups 'br/public:avm/res/resources/resource-group:0.4.4' = [for target in targets: {
  name: '${namePrefix}-${target}-rg'
  params: {
    name: 'rg-${namePrefix}-demo-${target}'
    location: location
    tags: union(tags, { target: target })
    enableTelemetry: false
    roleAssignments: [for i in range(0, 2): {
      principalId: shared.outputs.deploymentPrincipalIds[i]
      principalType: 'ServicePrincipal'
      roleDefinitionIdOrName: 'Contributor'
    }]
  }
}]

@description('Environment configuration matching environment.schema.json. Save this output for use by the platform deployment workflows.')
output environmentMetadata object = {
  schemaVersion: '1.0'
  location: location
  subscriptionId: subscription().subscriptionId
  resourceGroups: toObject(targets, target => target, target => 'rg-${namePrefix}-demo-${target}')
  network: shared.outputs.network
  privateDnsZones: shared.outputs.privateDnsZones
  logAnalyticsWorkspaceResourceId: shared.outputs.logAnalyticsWorkspaceResourceId
  state: shared.outputs.state
  sshPublicKey: sshPublicKey
}

@description('Identity details for the GitHub deployment environments. These are separate from the workload environment configuration and contain no credentials.')
output deploymentIdentities object = shared.outputs.deploymentIdentities

@description('Shared resource IDs for preflight checks and cleanup. These resources remain managed by the Bicep bootstrap.')
output foundationResourceIds object = shared.outputs.foundationResourceIds

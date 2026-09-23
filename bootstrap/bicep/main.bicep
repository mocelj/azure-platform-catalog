targetScope = 'subscription'

@description('Platform-owned prefix. Use lower-case letters and digits; this is not a developer input.')
@minLength(3)
@maxLength(12)
param namePrefix string = 'avmdemo'

@allowed(['swedencentral'])
param location string = 'swedencentral'

@description('Caller-approved RFC1918 IPv4 management CIDR, reachable through existing private connectivity. No internet SSH.')
param approvedManagementCidr string

@description('Caller-owned SSH PUBLIC key only. Never provide or output private key material.')
@minLength(32)
param sshPublicKey string

@description('Trusted catalog repository, not the consumer repository.')
param catalogRepository string = 'mocelj/azure-platform-catalog'

@description('A deliberately selected logical zone for both Standard NAT and its Standard public IP. Verify regional availability before deployment.')
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

@description('Exactly the environment.schema.json binding. Save only this value as platform-owned environment metadata after a separately approved bootstrap.')
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

@description('Non-secret GitHub Environment identity configuration, deliberately separate from the metadata schema.')
output deploymentIdentities object = shared.outputs.deploymentIdentities

@description('Non-secret shared resource IDs for operator preflight and cleanup; not Terraform-managed resources.')
output foundationResourceIds object = shared.outputs.foundationResourceIds

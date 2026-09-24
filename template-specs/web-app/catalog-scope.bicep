targetScope = 'subscription'

@description('Dedicated resource group for Template Spec metadata.')
param resourceGroupName string

@allowed(['swedencentral'])
param location string

module catalogGroup 'br/public:avm/res/resources/resource-group:0.4.4' = {
  name: 'platform-catalog-ui-resource-group'
  params: {
    name: resourceGroupName
    location: location
    tags: {
      purpose: 'platform-catalog-ui-preview'
    }
    enableTelemetry: false
  }
}

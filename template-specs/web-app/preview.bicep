targetScope = 'resourceGroup'

@description('Application name shown in the portal preview.')
@minLength(3)
@maxLength(20)
param name string

@description('Service profile: small uses B1; medium uses B2.')
@allowed(['small', 'medium'])
param size string = 'small'

// This is a source constant, not a caller-controlled deployment parameter.
var previewOnly = true
var checkedName = previewOnly
  ? fail('PORTAL_PREVIEW_ONLY: This version demonstrates the portal form. Workload deployment is disabled.')
  : name

module webApp '../../platform-apps/web-app/bicep/main.bicep' = {
  name: 'web-app-portal-preview'
  params: {
    name: checkedName
    size: size
    location: 'swedencentral'
    logAnalyticsWorkspaceResourceId: ''
    privateEndpointSubnetResourceId: ''
    privateDnsZoneResourceId: ''
    integrationSubnetResourceId: ''
    tags: {
      purpose: 'platform-catalog-ui-preview'
    }
  }
}

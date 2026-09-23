using './main.bicep'

// Compilation fixture, NOT authorization to deploy this example management range.
// For a real deployment copy this file privately and replace both caller inputs.
param namePrefix = 'avmdemo'
param location = 'swedencentral'
param approvedManagementCidr = '10.41.0.0/24'
param availabilityZone = 1
param catalogRepository = 'mocelj/azure-platform-catalog'
param sshPublicKey = loadJsonContent('../../environments/demo.example.json').sshPublicKey

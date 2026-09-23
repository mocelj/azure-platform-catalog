using './main.bicep'

// Example values for compilation. Before deployment, use a local copy with
// your management CIDR and SSH public key.
param namePrefix = 'avmdemo'
param location = 'swedencentral'
param approvedManagementCidr = '10.41.0.0/24'
param availabilityZone = 1
param catalogRepository = 'mocelj/azure-platform-catalog'
param sshPublicKey = loadJsonContent('../../environments/demo.example.json').sshPublicKey

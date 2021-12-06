//Session Host parameters
param sessionHostNamePrefix string
param virtualMachineSize string = 'Standard_D4_v4'
param availabilitySetName string
@allowed([
  'Nvidia'
  'AMD'
  'None'
])
param gpuType string
param numberOfInstances int

//Networking parameters
param existingVnetName string
param existingSubnetName string
param existingVnetResourceGroupName string

//Keyvault parameters
param existingKeyVaultName string
param existingKeyVaultResourceGroupName string
param existingKeyVaultLocalAdminSecretName string
param existingKeyVaultDomainJoinSecretName string

//Shared Image Gallery parameters
param existingSharedImageGalleryResourceGroup string
param existingSharedImageGalleryName string
param existingSharedImageGalleryDefinitionName string
param existingSharedImageGalleryVersionName string

//ADDS parameters
param adDomainName string = ''
param domainJoinUPN string = ''
param ouLocationAVDSessionHost string = ''

//Hostpool parameters
param registrationKey string

resource kv 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name : existingKeyVaultName
  scope: resourceGroup(existingKeyVaultResourceGroupName)
}

resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: existingVnetName
  scope: resourceGroup(existingVnetResourceGroupName)
}

module avdhost 'avdSessionHost.bicep' = {
  name: 'tvm'
  params: {
    adDomainName: adDomainName
    availabilitySetName: availabilitySetName
    domainJoinPassword: kv.getSecret(existingKeyVaultDomainJoinSecretName)
    domainJoinUPN: domainJoinUPN
    existingSubnetName: existingSubnetName
    existingVnetName: existingVnetName
    existingVnetResourceGroupName: existingVnetResourceGroupName
    gpuType: gpuType
    sessionHostNamePrefix: sessionHostNamePrefix
    localAdminPassword:kv.getSecret(existingKeyVaultLocalAdminSecretName)
    numberOfInstances: numberOfInstances
    ouLocationAVDSessionHost: ouLocationAVDSessionHost
    registrationKey: registrationKey
    virtualMachineSize: virtualMachineSize
    existingSharedImageGalleryDefinitionName: existingSharedImageGalleryDefinitionName
    existingSharedImageGalleryName: existingSharedImageGalleryName
    existingSharedImageGalleryResourceGroup: existingSharedImageGalleryResourceGroup
    existingSharedImageGalleryVersionName: existingSharedImageGalleryVersionName
  }
}

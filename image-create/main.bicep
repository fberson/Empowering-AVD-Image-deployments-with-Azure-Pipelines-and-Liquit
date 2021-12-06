//Mandatory parameters
param templateVMHostname string
param virtualMachineSizeWVD string = 'Standard_D4as_v4'
param existingVnetName string
param existingSubnetName string
param existingVnetResourceGroupName string
param localadminUserName string
param ImageSKU string
param assetLocation string
param existingKeyVaultName string
param existingKeyVaultResourceGroupName string
param existingKeyVaultLocalAdminSecretName string
param existingKeyVaultDomainJoinSecretName string
param existingKeyVaultStorageAccountSecretName string
param existingStorageAccountName string

//optional ADDS parameters
param joinToADDS bool = false
param adDomainName string = ''
param domainJoinUPN string = ''
param ouLocationWVDSessionHost string = ''

resource kv 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name : existingKeyVaultName
  scope: resourceGroup(existingKeyVaultResourceGroupName)
}

resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: existingVnetName
  scope: resourceGroup(existingVnetResourceGroupName)
}

module tvm 'TemplateImageVM.bicep' = {
  name: 'tvm'
  params: {
    templateVMHostname: templateVMHostname
    virtualMachineSizeWVD: virtualMachineSizeWVD
    existingVnetId: vnet.id
    existingSubnetName : existingSubnetName
    localadminUSerName : localadminUserName
    localAdminPassword : kv.getSecret(existingKeyVaultLocalAdminSecretName)
    ImageSKU : ImageSKU
    assetLocation: assetLocation
    joinToADDS : joinToADDS
    adDomainName : adDomainName
    domainJoinUPN : domainJoinUPN
    domainJoinPassword: kv.getSecret(existingKeyVaultDomainJoinSecretName)
    ouLocationWVDSessionHost : ouLocationWVDSessionHost
    existingKeyVaultStorageAccountKey: kv.getSecret(existingKeyVaultStorageAccountSecretName)
    existingStorageAccountName: existingStorageAccountName
  }
}

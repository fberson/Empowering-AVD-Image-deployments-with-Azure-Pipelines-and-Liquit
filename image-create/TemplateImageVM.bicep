//Mandatory parameters
param templateVMHostname string
param virtualMachineSizeWVD string
param existingVnetId string
param existingSubnetName string
param localadminUSerName string
@secure()
param localAdminPassword string
param ImageSKU string
param assetLocation string
@secure()
param existingKeyVaultStorageAccountKey string
param existingStorageAccountName string

//optional ADDS parameters
param joinToADDS bool = false
param adDomainName string = ''
param domainJoinUPN string = ''
@secure()
param domainJoinPassword string
param ouLocationWVDSessionHost string = ''

var domainJoinOptions = 3
var storage = {
  type: 'StandardSSD_LRS'
}
var virtualmachineosdisk = {
  cacheOption: 'ReadWrite'
  createOption: 'FromImage'
  diskName: 'OS'
}
var imageReference = {
  publisher: 'MicrosoftWindowsDesktop'
  offer: 'Windows-10'
  sku: ImageSKU
  version: 'latest'
}
var vmTimeZone = 'W. Europe Standard Time'
var networkAdapterIPConfigName = 'ipconfig'
var networkAdapterNamePostFix = '-nic'
var networkAdapterIPAllocationMethod = 'Dynamic'
var configurationScript = 'avd-ninja-aib-deploy.ps1'
var liquitMSI = 'avd-liquit-aib-demo.msi'
var liquitAgentXML = 'Agent.xml'

resource nic 'Microsoft.Network/networkInterfaces@2020-06-01' = {
  name: '${templateVMHostname}${networkAdapterNamePostFix}'
  tags: {
    displayName: 'WVD Session Host Network interfaces'
  }
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: networkAdapterIPConfigName
        properties: {
          privateIPAllocationMethod: networkAdapterIPAllocationMethod
          subnet: {
            id: '${existingVnetId}/subnets/${existingSubnetName}'
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: templateVMHostname
  tags: {
    displayName: 'Template VM to create image'
  }
  location: resourceGroup().location
  properties: {
    licenseType: 'Windows_Client'
    hardwareProfile: {
      vmSize: virtualMachineSizeWVD
    }
    osProfile: {
      computerName: templateVMHostname
      adminUsername: localadminUSerName
      adminPassword: localAdminPassword
      windowsConfiguration: {
        timeZone: vmTimeZone
      }
    }
    storageProfile: {
      osDisk: {
        name: '${templateVMHostname}-${virtualmachineosdisk.diskName}'
        managedDisk: {
          storageAccountType: storage.type
        }
        osType: 'Windows'
        caching: virtualmachineosdisk.cacheOption
        createOption: virtualmachineosdisk.createOption
      }
      imageReference: {
        publisher: imageReference.publisher
        offer: imageReference.offer
        sku: imageReference.sku
        version: imageReference.version
      }
      dataDisks: []
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

resource customizer 'Microsoft.Compute/virtualMachines/extensions@2020-06-01' = {
  name: '${vm.name}/customizer'
  tags: {
    displayName: 'PowerShell Extension'
  }
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.8'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        '${assetLocation}${configurationScript}'
        '${assetLocation}${liquitMSI}'
        '${assetLocation}${liquitAgentXML}'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File ${configurationScript} >> ${configurationScript}.log 2>&1'
      storageAccountName: existingStorageAccountName
      storageAccountKey: existingKeyVaultStorageAccountKey
    }
  }
}

resource domainjoin 'Microsoft.Compute/virtualMachines/extensions@2020-06-01' = if (joinToADDS) {
  name: '${vm.name}/domainjoin'
  tags: {
    displayName: 'DomainJoin Extension'
  }
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      Name: adDomainName
      OUPath: ouLocationWVDSessionHost
      User: domainJoinUPN
      Restart: true
      Options: domainJoinOptions
    }
    protectedSettings: {
      Password: domainJoinPassword
    }
  }
}

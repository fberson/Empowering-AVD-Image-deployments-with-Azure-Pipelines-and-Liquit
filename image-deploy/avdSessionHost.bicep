param adDomainName string
param availabilitySetName string
param domainJoinUPN string
param existingSubnetName string
param existingVnetName string
param existingVnetResourceGroupName string
param sessionHostNamePrefix string
param numberOfInstances int
param ouLocationAVDSessionHost string
param virtualMachineSize string
@allowed([
  'Nvidia'
  'AMD'
  'None'
])
param gpuType string
param existingSharedImageGalleryResourceGroup string
param existingSharedImageGalleryName string
param existingSharedImageGalleryDefinitionName string
param existingSharedImageGalleryVersionName string

@secure()
param localAdminPassword string

@secure()
param domainJoinPassword string

@secure()
param registrationKey string

var networkSubnetId = '${networkVnetId}/subnets/${existingSubnetName}'
var networkVnetId = resourceId(existingVnetResourceGroupName, 'Microsoft.Network/virtualNetworks', existingVnetName)
var storage = {
  type: 'StandardSSD_LRS'
}
var virtualmachineosdisk = {
  cacheOption: 'ReadWrite'
  createOption: 'FromImage'
  diskName: 'OS'
}
var vmTimeZone = 'W. Europe Standard Time'
var networkAdapterIPConfigName = 'ipconfig'
var networkAdapterNamePostFix = '-nic'
var networkAdapterIPAllocationMethod = 'Dynamic'
var assetLocation = 'https://raw.githubusercontent.com/fberson/wvd/master/'
var configurationScriptWVD = 'Add-WVDHostToHostpoolSpringV5.ps1'
var sequenceStartNumberWVDHost = 1
var imageResourceId = resourceId(existingSharedImageGalleryResourceGroup, 'Microsoft.Compute/galleries/images/versions', existingSharedImageGalleryName, existingSharedImageGalleryDefinitionName, existingSharedImageGalleryVersionName)

resource avset 'Microsoft.Compute/availabilitySets@2020-06-01' = {
  name: availabilitySetName
  location: resourceGroup().location
  tags: {
    displayName: 'WVD AvailabilitySet'
  }
  properties: {
    platformUpdateDomainCount: 2
    platformFaultDomainCount: 2
  }
  sku: {
    name: 'Aligned'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2020-06-01' = [for i in range(0, numberOfInstances): {
  name: '${sessionHostNamePrefix}-${(i + sequenceStartNumberWVDHost)}${networkAdapterNamePostFix}'
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
            id: networkSubnetId
          }
        }
      }
    ]
  }
}]

resource vm 'Microsoft.Compute/virtualMachines@2020-06-01' = [for i in range(0, numberOfInstances): {
  name: '${sessionHostNamePrefix}-${(i + sequenceStartNumberWVDHost)}'
  tags: {
    displayName: 'WVD Session Host Virtual Machines'
  }
  location: resourceGroup().location
  properties: {
    licenseType: 'Windows_Client'
    hardwareProfile: {
      vmSize: virtualMachineSize
    }
    availabilitySet: {
      id: avset.id
    }
    osProfile: {
      computerName: '${sessionHostNamePrefix}-${(i + sequenceStartNumberWVDHost)}'
      adminUsername: '${sessionHostNamePrefix}-${(i + sequenceStartNumberWVDHost)}-adm'
      adminPassword: localAdminPassword
      windowsConfiguration: {
        timeZone: vmTimeZone
      }
    }
    storageProfile: {
      osDisk: {
        name: '${sessionHostNamePrefix}-${(i + sequenceStartNumberWVDHost)}-${virtualmachineosdisk.diskName}'
        managedDisk: {
          storageAccountType: storage.type
        }
        osType: 'Windows'
        caching: virtualmachineosdisk.cacheOption
        createOption: virtualmachineosdisk.createOption
      }
      imageReference: {
        id: imageResourceId
      }
      dataDisks: []
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic[i].id
        }
      ]
    }
  }
}]

resource wvd 'Microsoft.Compute/virtualMachines/extensions@2020-06-01' = [for i in range(0, numberOfInstances): {
  name: '${vm[i].name}/avdconfig'
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
        '${assetLocation}${configurationScriptWVD}'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File ${configurationScriptWVD} ${registrationKey} ${adDomainName} ${domainJoinUPN} ${domainJoinPassword} ${ouLocationAVDSessionHost} >> ${configurationScriptWVD}.log 2>&1'
    }
  }
}]

/*resource domainjoin 'Microsoft.Compute/virtualMachines/extensions@2020-06-01' = [for i in range(0, numberOfInstances): {
  name: '${vm[i].name}/domainjoin'
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
      OUPath: ouLocationAVDSessionHost
      User: domainJoinUPN
      Restart: true
      Options: domainJoinOptions
    }
    protectedSettings: {
      Password: domainJoinPassword
    }
  }
  dependsOn: [
    wvd[i]
  ]
}]*/

resource nvidiagpudriver 'Microsoft.Compute/virtualMachines/extensions@2020-06-01' = [for i in range(0, numberOfInstances): if (gpuType == 'Nvidia') {
  name: '${vm[i].name}/nvidiagpudriver'
  tags: {
    displayName: 'nvidia GPU Extension'
  }
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.HpcCompute'
    type: 'NvidiaGpuDriverWindows'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    protectedSettings: {}
  }
}]

resource amdgpudriver 'Microsoft.Compute/virtualMachines/extensions@2020-06-01' = [for i in range(0, numberOfInstances): if (gpuType == 'AMD') {
  name: '${vm[i].name}/amdgpudriver'
  tags: {
    displayName: 'AMD GPU Extension'
  }
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.HpcCompute'
    type: 'AmdGpuDriverWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    protectedSettings: {}
  }
}]



targetScope = 'resourceGroup'

@description('Primary Azure region for the stack.')
param location string

@description('Name of the Linux VM.')
param vmName string

@description('Guest computer name.')
param computerName string

@description('Administrator username for the Linux VM.')
param adminUsername string

@description('SSH public key that will be added to the administrator account.')
param adminSshPublicKey string

@description('Azure VM size.')
param vmSize string

@description('Address prefix for the virtual network.')
param virtualNetworkAddressPrefix string

@description('Address prefix for the workload subnet.')
param subnetAddressPrefix string

@description('Enable a public IP for direct SSH. Leave false for the recommended tunnel-only design.')
param enablePublicIp bool

@description('CIDR ranges allowed to SSH to the VM if a public IP is enabled.')
param adminSshSourceCidrs array

@description('Linux image publisher.')
param imagePublisher string

@description('Linux image offer.')
param imageOffer string

@description('Linux image SKU.')
param imageSku string

@description('Linux image version.')
param imageVersion string

@description('OS disk size in GiB.')
param osDiskSizeGiB int

@description('OS disk managed disk SKU.')
param osDiskStorageAccountType string

@description('Enable VM auto-shutdown.')
param enableAutoShutdown bool

@description('Daily auto-shutdown time in HHmm.')
param autoShutdownTime string

@description('Time zone for VM auto-shutdown.')
param autoShutdownTimeZone string

@description('Email recipient for shutdown notifications.')
param autoShutdownNotificationEmail string

@description('Tags applied to resources in this stack.')
param tags object = {}

var vnetName = 'vnet-${vmName}'
var subnetName = 'snet-dev'
var nsgName = 'nsg-${vmName}'
var allowRestrictedSshRule = enablePublicIp && !empty(adminSshSourceCidrs)
var subnetResourceId = '${virtualNetwork.id}/subnets/${subnetName}'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
        }
      }
    ]
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      if (allowRestrictedSshRule) {
        name: 'AllowSshFromApprovedCidrs'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 100
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefixes: adminSshSourceCidrs
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

module vm 'br/public:avm/res/compute/virtual-machine:0.21.0' = {
  name: 'remoteDevVm'
  params: {
    name: vmName
    computerName: computerName
    location: location
    osType: 'Linux'
    imageReference: {
      publisher: imagePublisher
      offer: imageOffer
      sku: imageSku
      version: imageVersion
    }
    adminUsername: adminUsername
    disablePasswordAuthentication: true
    publicKeys: [
      {
        keyData: adminSshPublicKey
        path: '/home/${adminUsername}/.ssh/authorized_keys'
      }
    ]
    vmSize: vmSize
    availabilityZone: -1
    osDisk: {
      caching: 'ReadWrite'
      createOption: 'FromImage'
      deleteOption: 'Delete'
      diskSizeGB: osDiskSizeGiB
      managedDisk: {
        storageAccountType: osDiskStorageAccountType
      }
    }
    nicConfigurations: [
      {
        nicSuffix: '-nic-01'
        deleteOption: 'Delete'
        networkSecurityGroupResourceId: networkSecurityGroup.id
        ipConfigurations: [
          {
            name: 'ipconfig01'
            privateIPAllocationMethod: 'Dynamic'
            subnetResourceId: subnetResourceId
            pipConfiguration: enablePublicIp ? {
              publicIpNameSuffix: '-pip-01'
              publicIPAllocationMethod: 'Static'
              publicIPAddressVersion: 'IPv4'
              skuName: 'Standard'
            } : null
          }
        ]
      }
    ]
    managedIdentities: {
      systemAssigned: true
    }
    securityType: 'TrustedLaunch'
    secureBootEnabled: true
    vTpmEnabled: true
    bootDiagnostics: false
    provisionVMAgent: true
    patchMode: 'ImageDefault'
    networkAccessPolicy: 'DenyAll'
    publicNetworkAccess: 'Disabled'
    autoShutdownConfig: enableAutoShutdown ? {
      status: 'Enabled'
      timeZone: autoShutdownTimeZone
      dailyRecurrenceTime: autoShutdownTime
      notificationSettings: empty(autoShutdownNotificationEmail) ? {
        status: 'Disabled'
      } : {
        status: 'Enabled'
        emailRecipient: autoShutdownNotificationEmail
        notificationLocale: 'en'
        timeInMinutes: 30
      }
    } : {
      status: 'Disabled'
    }
    tags: tags
    enableTelemetry: false
  }
  dependsOn: [
    virtualNetwork
    networkSecurityGroup
  ]
}

output vmResourceId string = vm.outputs.resourceId
output virtualNetworkResourceId string = virtualNetwork.id
output subnetResourceId string = subnetResourceId
output networkSecurityGroupResourceId string = networkSecurityGroup.id
output vmNicSummary array = vm.outputs.nicConfigurations

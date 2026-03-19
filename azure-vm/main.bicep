targetScope = 'subscription'

@description('Primary Azure region for the VM stack. Cost estimates in the accompanying README assume West Europe.')
param location string = 'westeurope'

@description('Resource group name for the remote development VM stack.')
param resourceGroupName string = 'rg-android-workstation-vm-weu'

@description('Name of the Linux VM that will host the development environment and VS Code tunnel.')
param vmName string = 'vm-android-workstation-weu-01'

@description('Computer name inside the guest OS.')
param computerName string = 'aw-devvm-01'

@description('Administrator username for the Linux VM.')
param adminUsername string = 'martin'

@description('SSH public key that will be placed in the Linux administrator account.')
param adminSshPublicKey string

@description('VM size. Standard_B2ms is the default value pick for this workload.')
param vmSize string = 'Standard_B2ms'

@description('Address prefix for the single virtual network.')
param virtualNetworkAddressPrefix string = '10.44.0.0/24'

@description('Address prefix for the workload subnet.')
param subnetAddressPrefix string = '10.44.0.0/26'

@description('Outbound connectivity strategy for the VM subnet. vmPublicIp is the low-cost explicit method, natGateway is the most private, and defaultOutbound is a temporary compatibility path that keeps Azure implicit outbound behavior.')
@allowed([
  'vmPublicIp'
  'natGateway'
  'defaultOutbound'
])
param outboundConnectivityMode string = 'vmPublicIp'

@description('CIDR ranges allowed to SSH to the VM when outboundConnectivityMode is vmPublicIp. Leave empty to keep all inbound SSH blocked.')
param adminSshSourceCidrs array = []

@description('Linux image publisher.')
param imagePublisher string = 'Canonical'

@description('Linux image offer.')
param imageOffer string = '0001-com-ubuntu-server-jammy'

@description('Linux image SKU.')
param imageSku string = '22_04-lts-gen2'

@description('Linux image version.')
param imageVersion string = 'latest'

@description('OS disk size in GiB.')
@minValue(64)
param osDiskSizeGiB int = 64

@description('Managed disk SKU for the OS disk. StandardSSD_LRS is the budget-conscious default.')
@allowed([
  'StandardSSD_LRS'
  'Premium_LRS'
])
param osDiskStorageAccountType string = 'StandardSSD_LRS'

@description('Enable VM auto-shutdown to avoid accidental overrun.')
param enableAutoShutdown bool = true

@description('Daily auto-shutdown time in HHmm, using the time zone below.')
param autoShutdownTime string = '2300'

@description('Time zone for VM auto-shutdown.')
param autoShutdownTimeZone string = 'W. Europe Standard Time'

@description('Optional email recipient for shutdown notifications. Leave empty to disable notifications.')
param autoShutdownNotificationEmail string = ''

@description('Run unattended first-boot provisioning through VM custom data. Recommended for this workflow.')
param enableBootstrapOnFirstBoot bool = true

@description('Install Azure CLI during first-boot provisioning.')
param bootstrapInstallAzureCli bool = true

@description('Install Bicep CLI during first-boot provisioning when Azure CLI is installed.')
param bootstrapInstallBicep bool = true

@description('Install Terraform during first-boot provisioning.')
param bootstrapInstallTerraform bool = true

@description('Install GitHub CLI during first-boot provisioning.')
param bootstrapInstallGithubCli bool = false

@description('Install Docker during first-boot provisioning.')
param bootstrapInstallDocker bool = false

@description('Stable display name for the VS Code tunnel host after you register it.')
param vscodeTunnelName string = vmName

@description('Create a subscription budget and email alerts. Recommended if you use Visual Studio monthly credit.')
param enableBudget bool = true

@description('Budget name. Used only when enableBudget is true and at least one contact email is supplied.')
param budgetName string = 'android-workstation-vm-budget'

@description('Monthly budget amount in USD. A value around 75-100 leaves buffer inside a 150 USD Visual Studio Enterprise credit.')
@minValue(1)
param budgetAmountUsd int = 100

@description('Email recipients for budget alerts.')
param budgetContactEmails array = []

@description('Start date for the subscription budget in ISO 8601 format.')
param budgetStartDate string = '${utcNow('yyyy-MM-01')}T00:00:00Z'

@description('Additional tags to merge into the default tag set.')
param tags object = {}

var defaultTags = {
  workload: 'android-workstation'
  scenario: 'remote-dev-vm'
  purpose: 'dev-test'
  accessPattern: 'vscode-tunnel'
  managedBy: 'bicep'
}

var mergedTags = union(defaultTags, tags)
var deployBudget = enableBudget && !empty(budgetContactEmails)

module resourceGroupModule 'br/public:avm/res/resources/resource-group:0.4.0' = {
  name: 'androidWorkstationResourceGroup'
  params: {
    name: resourceGroupName
    location: location
    tags: mergedTags
    enableTelemetry: false
  }
}

module vmStack './modules/dev-vm-stack.bicep' = {
  name: 'androidWorkstationVmStack'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    vmName: vmName
    computerName: computerName
    adminUsername: adminUsername
    adminSshPublicKey: adminSshPublicKey
    vmSize: vmSize
    virtualNetworkAddressPrefix: virtualNetworkAddressPrefix
    subnetAddressPrefix: subnetAddressPrefix
    outboundConnectivityMode: outboundConnectivityMode
    adminSshSourceCidrs: adminSshSourceCidrs
    imagePublisher: imagePublisher
    imageOffer: imageOffer
    imageSku: imageSku
    imageVersion: imageVersion
    osDiskSizeGiB: osDiskSizeGiB
    osDiskStorageAccountType: osDiskStorageAccountType
    enableAutoShutdown: enableAutoShutdown
    autoShutdownTime: autoShutdownTime
    autoShutdownTimeZone: autoShutdownTimeZone
    autoShutdownNotificationEmail: autoShutdownNotificationEmail
    enableBootstrapOnFirstBoot: enableBootstrapOnFirstBoot
    bootstrapInstallAzureCli: bootstrapInstallAzureCli
    bootstrapInstallBicep: bootstrapInstallBicep
    bootstrapInstallTerraform: bootstrapInstallTerraform
    bootstrapInstallGithubCli: bootstrapInstallGithubCli
    bootstrapInstallDocker: bootstrapInstallDocker
    vscodeTunnelName: vscodeTunnelName
    tags: mergedTags
  }
  dependsOn: [
    resourceGroupModule
  ]
}

resource budget 'Microsoft.Consumption/budgets@2024-08-01' = if (deployBudget) {
  name: budgetName
  properties: {
    category: 'Cost'
    amount: budgetAmountUsd
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: budgetStartDate
    }
    notifications: {
      actual80: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 80
        contactEmails: budgetContactEmails
      }
      actual100: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 100
        contactEmails: budgetContactEmails
      }
      forecast100: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 100
        thresholdType: 'Forecasted'
        contactEmails: budgetContactEmails
      }
    }
  }
}

output resourceGroupName string = resourceGroupModule.outputs.name
output resourceGroupResourceId string = resourceGroupModule.outputs.resourceId
output vmResourceId string = vmStack.outputs.vmResourceId
output virtualNetworkResourceId string = vmStack.outputs.virtualNetworkResourceId
output subnetResourceId string = vmStack.outputs.subnetResourceId
output networkSecurityGroupResourceId string = vmStack.outputs.networkSecurityGroupResourceId
output vmNicSummary array = vmStack.outputs.vmNicSummary
output outboundConnectivityMode string = outboundConnectivityMode
output publicIpEnabled bool = outboundConnectivityMode == 'vmPublicIp'
output budgetCreated bool = deployBudget
output bootstrapOnFirstBootEnabled bool = enableBootstrapOnFirstBoot
output vscodeTunnelName string = vscodeTunnelName

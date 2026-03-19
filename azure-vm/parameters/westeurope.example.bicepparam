using '../main.bicep'

param location = 'westeurope'
param resourceGroupName = 'rg-android-workstation-vm-weu'
param vmName = 'vm-android-workstation-weu-01'
param computerName = 'aw-devvm-01'
param adminUsername = 'martin'
param adminSshPublicKey = 'ssh-ed25519 AAAAREPLACE_WITH_YOUR_PUBLIC_KEY martinjensen225@phone'
param vmSize = 'Standard_B2ms'
param osDiskSizeGiB = 64
param osDiskStorageAccountType = 'StandardSSD_LRS'
param outboundConnectivityMode = 'vmPublicIp'
param adminSshSourceCidrs = []
param autoShutdownTime = '2300'
param autoShutdownTimeZone = 'W. Europe Standard Time'
param autoShutdownNotificationEmail = ''
param enableBudget = true
param budgetAmountUsd = 100
param budgetContactEmails = [
  'replace-with-your-email@example.com'
]
param tags = {
  owner: 'martinjensen225'
  environment: 'personal-devtest'
}

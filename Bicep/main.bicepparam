using './main.bicep'

param location = 'westeurope'
param resourceGroupName = 'rg-android-workstation-vm-weu'
param vmName = 'vm-android-workstation-weu-01'
param computerName = 'aw-devvm-01'
param adminUsername = 'martin'
// Replace this value before the first GitHub Actions deployment.
param adminSshPublicKey = 'ssh-ed25519 AAAAREPLACE_WITH_YOUR_PUBLIC_KEY martinjensen225@phone'
param vmSize = 'Standard_B2ms'
param osDiskSizeGiB = 64
param osDiskStorageAccountType = 'StandardSSD_LRS'
param outboundConnectivityMode = 'vmPublicIp'
param adminSshSourceCidrs = []
param autoShutdownTime = '2300'
param autoShutdownTimeZone = 'W. Europe Standard Time'
param autoShutdownNotificationEmail = ''
param enableBootstrapOnFirstBoot = true
param bootstrapInstallAzureCli = true
param bootstrapInstallBicep = true
param bootstrapInstallTerraform = true
param bootstrapInstallGithubCli = false
param bootstrapInstallDocker = false
param vscodeTunnelName = 'android-workstation-weu'
param enableBudget = false
param budgetAmountUsd = 100
param budgetContactEmails = []
param tags = {
  owner: 'martinjensen225'
  environment: 'personal-devtest'
}

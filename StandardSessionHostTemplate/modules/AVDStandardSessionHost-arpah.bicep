// This is a sample bicep file //

param VMName string
param VMSize string
param DiskType string
param Location string = resourceGroup().location
param AvailabilityZones array = []
param SubnetID string
param AdminUsername string

@secure()
param AdminPassword string = newGuid()

param AcceleratedNetworking bool

param Tags object = {}

param ImageReference object
param SecurityProfile object

//HostPool join
param HostPoolName string
@secure()
param HostPoolToken string
param WVDArtifactsURL string

//Domain Join
param DomainJoinObject object = {}

@secure()
param DomainJoinPassword string = ''

//---- Variables ----//
var varRequireNvidiaGPU = startsWith(VMSize, 'Standard_NC') || contains(VMSize, '_A10_v5')

var varVMNumber = int(
  substring(
    VMName,
    (lastIndexOf(VMName, '-') + 1),
    (length(VMName) - lastIndexOf(VMName, '-') - 1)
  )
)

var varAvailabilityZone = AvailabilityZones == [] ? [] : [ '${AvailabilityZones[varVMNumber % length(AvailabilityZones)]}' ]


var varBaseScriptUri = 'https://raw.githubusercontent.com/ARPA-H/avdaccelerator-nih/main/workload/'
var varSessionHostConfigurationScriptUri = '${varBaseScriptUri}scripts/Set-SessionHostConfiguration.ps1'
var varSessionHostConfigurationScript = './Set-SessionHostConfiguration.ps1'

@sys.description('Required, The service providing domain services for Azure Virtual Desktop. (Default: ADDS)')
param avdIdentityServiceProvider string = 'ADDS'

@sys.description('Required, the storage account name for the FSLogix profile container')
param varFslogixStorageName string = 'stfslavdxtbiz'

@sys.description('Required, the file share name for the FSLogix profile container')
param varFslogixFileShareName string = 'fslogix-pc-app1-test-use2-001'

@sys.description('Required, the path to the FSLogix profile container')
var varFslogixSharePath = '\\\\${varFslogixStorageName}.file.${environment().suffixes.storage}\\${varFslogixFileShareName}' 

@sys.description('Required, the FQDN of the storage account for the FSLogix profile container')
var varFslogixStorageFqdn = '${varFslogixStorageName}.file.${environment().suffixes.storage}' 

resource vNIC 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: '${VMName}-vNIC'
  location: Location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: SubnetID
          }
        }
      }
    ]
    enableAcceleratedNetworking: AcceleratedNetworking
  }
  tags: Tags
}

resource VM 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: VMName
  location: Location
  zones: varAvailabilityZone
  identity: (DomainJoinObject.DomainType == 'EntraID') ? { type: 'SystemAssigned' } : any(null)
  properties: {
    osProfile: {
      computerName: VMName
      adminUsername: AdminUsername
      adminPassword: AdminPassword
    }
    hardwareProfile: {
      vmSize: VMSize
    }
    storageProfile: {
      osDisk: {
        name: '${VMName}-OSDisk'
        createOption: 'FromImage'
        deleteOption: 'Delete'
        managedDisk: {
          storageAccountType: DiskType
        }
      }
      imageReference: ImageReference
    }
    securityProfile: SecurityProfile
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vNIC.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    licenseType: 'Windows_Client'

  }
  // Guest Attestation (Integrity Monitoring) //
  resource deployIntegrityMonitoring 'extensions@2023-09-01' = {
    name: 'deployIntegrityMonitoring'
    location: Location
    properties: {
      publisher: 'Microsoft.Azure.Security.WindowsAttestation'
      type: 'GuestAttestation'
      typeHandlerVersion: '1.0'
      autoUpgradeMinorVersion: true
      settings: {
        AttestationConfig: {
          MaaSettings: {
            maaEndpoint: ''
            maaTenantName: 'Guest Attestation'
          }
          AscSettings: {
            ascReportingEndpoint: ''
            ascReportingFrequency: ''
          }
          useCustomToken: 'false'
          disableAlerts: 'false'
        }
      }
    }
  }

    // Azure Monitor Agent Extension //
  resource deployAzureMonitoring 'extensions@2023-09-01' = {
    name: 'deployAzureMonitoring'
    location: Location
    properties: {
      publisher: 'Microsoft.Azure.Monitor'
      type: 'AzureMonitorWindowsAgent'
      typeHandlerVersion: '1.22'
      autoUpgradeMinorVersion: true
      settings: {
        // AttestationConfig: {
        //   MaaSettings: {
        //     maaEndpoint: ''
        //     maaTenantName: 'Guest Attestation'
        //   }
        //   AscSettings: {
        //     ascReportingEndpoint: ''
        //     ascReportingFrequency: ''
        //   }
        //   useCustomToken: 'false'
        //   disableAlerts: 'false'
        // }
        // workspaceId: !empty(monitoringWorkspaceId)
        // ? reference(vmss_logAnalyticsWorkspace.id, vmss_logAnalyticsWorkspace.apiVersion).customerId
        // : ''
      }
    }
    //dependsOn: [ AddWVDHost ]
  }

  // module vmss_azureMonitorAgentExtension 'extension/main.bicep' =
  // if (extensionMonitoringAgentConfig.enabled) {
  //   name: '${uniqueString(deployment().name, location)}-VMSS-AzureMonitorAgent'
  //   params: {
  //     virtualMachineScaleSetName: vmss.name
  //     name: 'AzureMonitorAgent'
  //     publisher: 'Microsoft.Azure.Monitor'
  //     type: osType == 'Windows' ? 'AzureMonitorWindowsAgent' : 'AzureMonitorLinuxAgent'
  //     typeHandlerVersion: contains(extensionMonitoringAgentConfig, 'typeHandlerVersion')
  //       ? extensionMonitoringAgentConfig.typeHandlerVersion
  //       : (osType == 'Windows' ? '1.22' : '1.29')
  //     autoUpgradeMinorVersion: contains(extensionMonitoringAgentConfig, 'autoUpgradeMinorVersion')
  //       ? extensionMonitoringAgentConfig.autoUpgradeMinorVersion
  //       : true
  //     enableAutomaticUpgrade: contains(extensionMonitoringAgentConfig, 'enableAutomaticUpgrade')
  //       ? extensionMonitoringAgentConfig.enableAutomaticUpgrade
  //       : false
  //     settings: {
  //       workspaceId: !empty(monitoringWorkspaceId)
  //         ? reference(vmss_logAnalyticsWorkspace.id, vmss_logAnalyticsWorkspace.apiVersion).customerId
  //         : ''
  //       GCS_AUTO_CONFIG: osType == 'Linux' ? true : null
  //     }
  //     protectedSettings: {
  //       workspaceKey: !empty(monitoringWorkspaceId) ? vmss_logAnalyticsWorkspace.listKeys().primarySharedKey : ''
  //     }
  //   }
  //   dependsOn: [
  //     vmss_microsoftAntiMalwareExtension
  //   ]
  // }

  // GPU Drivers //
  resource deployGPUDriversNvidia 'extensions@2023-09-01' = if (varRequireNvidiaGPU) {
    name: 'deployGPUDriversNvidia'
    location: Location
    properties: {
      publisher: 'Microsoft.HpcCompute'
      type: 'NvidiaGpuDriverWindows'
      typeHandlerVersion: '1.6'
      autoUpgradeMinorVersion: true
    }
    dependsOn: [ deployIntegrityMonitoring ]
  }

  // HostPool join //
  resource AddWVDHost 'extensions@2023-09-01' = if (HostPoolName != '') {
    // Documentation is available here: https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/dsc-template
    // TODO: Update to the new format for DSC extension, see documentation above.
    name: 'JoinHostPool'
    location: Location
    properties: {
      publisher: 'Microsoft.PowerShell'
      type: 'DSC'
      typeHandlerVersion: '2.77'
      autoUpgradeMinorVersion: true
      settings: {
        modulesUrl: WVDArtifactsURL
        configurationFunction: 'Configuration.ps1\\AddSessionHost'
        properties: {
          hostPoolName: HostPoolName
          registrationInfoToken: HostPoolToken
          aadJoin: DomainJoinObject.DomainType == 'EntraID' ? true : false
          useAgentDownloadEndpoint: true
          mdmId: contains(DomainJoinObject, 'IntuneJoin') ? (DomainJoinObject.IntuneJoin ? '0000000a-0000-0000-c000-000000000000' : '') : ''
        }
      }
    }
    dependsOn: [ deployGPUDriversNvidia ]
  }
  // Domain Join //
  resource AADJoin 'extensions@2023-09-01' = if (DomainJoinObject.DomainType == 'EntraID') {
    name: 'AADLoginForWindows'
    location: Location
    properties: {
      publisher: 'Microsoft.Azure.ActiveDirectory'
      type: 'AADLoginForWindows'
      typeHandlerVersion: '2.0'
      autoUpgradeMinorVersion: true
      settings: contains(DomainJoinObject, 'IntuneJoin') ? (DomainJoinObject.IntuneJoin ? { mdmId: '0000000a-0000-0000-c000-000000000000' } : null) : null
    }
    dependsOn: [ AddWVDHost ]
  }

  resource DomainJoin 'extensions@2023-09-01' = if (DomainJoinObject.DomainType == 'ActiveDirectory') {
    // Documentation is available here: https://docs.microsoft.com/en-us/azure/active-directory-domain-services/join-windows-vm-template#azure-resource-manager-template-overview
    name: 'DomainJoin'
    location: Location
    properties: {
      publisher: 'Microsoft.Compute'
      type: 'JSonADDomainExtension'
      typeHandlerVersion: '1.3'
      autoUpgradeMinorVersion: true
      settings: {
        Name: DomainJoinObject.DomainName
        OUPath: DomainJoinObject.ADOUPath
        User: '${DomainJoinObject.DomainName}\\${DomainJoinObject.DomainJoinUserName}'
        Restart: 'true'

        //will join the domain and create the account on the domain. For more information see https://msdn.microsoft.com/en-us/library/aa392154(v=vs.85).aspx'
        Options: 3
      }
      protectedSettings: {
        Password: DomainJoinPassword //TODO: Test domain join from keyvault option
      }
    }
    dependsOn: [ AddWVDHost ]
  }
  tags: Tags
}

// Apply AVD session host configurations
module sessionHostConfiguration '.bicep/configureSessionHost.bicep' = {
  //scope: resourceGroup('${subscriptionId}', '${computeObjectsRgName}')
  name: 'SH-Config'
  params: {
      location: Location
      name: 'sessionHostConfiguration'
      //hostPoolToken: keyVault.getSecret('hostPoolRegistrationToken')
      hostPoolToken: ''
      baseScriptUri: varSessionHostConfigurationScriptUri
      scriptName: varSessionHostConfigurationScript
      fslogix: true
      identityDomainName: 'nih.gov'
      vmSize: VMSize
      fslogixFileShare: varFslogixSharePath
      fslogixStorageFqdn: varFslogixStorageFqdn
      identityServiceProvider: avdIdentityServiceProvider
  }
  dependsOn: [ VM ]
}

// module sessionHostConfigurationTest '.bicep/configureSessionHost.bicep' = [for i in range(1, count): {
//   scope: resourceGroup('${subscriptionId}', '${computeObjectsRgName}')
//   name: 'SH-Config-${batchId}-${i}-${time}'
//   params: {
//       location: location
//       name: '${namePrefix}${padLeft((i + countIndex), 4, '0')}'
//       hostPoolToken: keyVault.getSecret('hostPoolRegistrationToken')
//       baseScriptUri: sessionHostConfigurationScriptUri
//       scriptName: sessionHostConfigurationScript
//       fslogix: createAvdFslogixDeployment
//       identityDomainName: identityDomainName
//       vmSize: vmSize
//       fslogixFileShare: fslogixSharePath
//       fslogixStorageFqdn: fslogixStorageFqdn
//       identityServiceProvider: identityServiceProvider
//   }
//   dependsOn: [
//       sessionHosts
//       monitoring
//   ]
// }]
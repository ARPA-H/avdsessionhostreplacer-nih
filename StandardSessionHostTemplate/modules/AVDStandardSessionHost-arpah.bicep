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

// params for ARPA-H
@sys.description('Required, The service providing domain services for Azure Virtual Desktop. (Default: ADDS)')
param AVDIdentityServiceProvider string = 'ADDS'

@sys.description('Required, the storage account name for the FSLogix profile container')
param FslogixStorageName string

@sys.description('Required, the file share name for the FSLogix profile container')
param FslogixFileShareName string

@sys.description('Required, the file for configuring the session host')
param BaseScriptUri string

// @sys.description('Required, the name of the virtual machine scale set')
// param VmssName string

@sys.description('Required, the name of the data collection rule')
param DataCollectionRuleName string

// @sys.description('Required, Host Pool Resource Group')
// param HostPoolResourceGroup string

// @sys.description('Required, Function App Name')
// param FunctionAppName string

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

var varSessionHostConfigurationScriptUri = '${BaseScriptUri}scripts/Set-SessionHostConfiguration-arpah.ps1'
var varSessionHostConfigurationScript = './Set-SessionHostConfiguration-arpah.ps1'
var varFslogixSharePath = '\\\\${FslogixStorageName}.file.${environment().suffixes.storage}\\${FslogixFileShareName}' 
var varFslogixStorageFqdn = '${FslogixStorageName}.file.${environment().suffixes.storage}'
var fslogix = true


// Param(
//   [parameter(Mandatory=$false)]
//   [string]
//   $IdentityDomainName, 
  
//   [parameter(Mandatory)]
//   [string]
//   $AmdVmSize, 
  
//   [parameter(Mandatory)]
//   [string]
//   $IdentityServiceProvider,
  
//   [parameter(Mandatory)]
//   [string]
//   $Fslogix,
  
//   [parameter(Mandatory=$false)]
//   [string]
//   $FslogixFileShare,
  
//   [parameter(Mandatory=$false)]
//   [string]
//   $fslogixStorageFqdn,
  
//   [parameter(Mandatory)]
//   [string]
//   $HostPoolRegistrationToken,    
  
//   [parameter(Mandatory)]
//   [string]
//   $NvidiaVmSiz



var varScriptArguments = '-IdentityDomainName ${DomainJoinObject.DomainName} -AmdVmSize ${varAmdVmSize} -IdentityServiceProvider ${AVDIdentityServiceProvider} -Fslogix ${fslogix} -FslogixFileShare ${varFslogixSharePath} -FslogixStorageFqdn ${varFslogixStorageFqdn} -HostPoolRegistrationToken ${HostPoolToken} -NvidiaVmSize ${varNvidiaVmSize} -verbose'
//var varScriptArguments = '-IdentityDomainName ${DomainJoinObject.DomainName} -AmdVmSize ${varAmdVmSize} -IdentityServiceProvider ${AVDIdentityServiceProvider} -Fslogix ${fslogix} -FslogixFileShare ${varFslogixSharePath} -HostPoolRegistrationToken ${HostPoolToken} -NvidiaVmSize ${varNvidiaVmSize} -verbose'
//var varBaseScriptArguments = '-IdentityServiceProvider ${identityServiceProvider} -Fslogix ${fslogix} -HostPoolRegistrationToken "${hostPool.listRegistrationTokens().value[0].token}" -AmdVmSize ${varAmdVmSize} -NvidiaVmSize ${varNvidiaVmSize}'

var varAmdVmSizes = [
  'Standard_NV4as_v4'
  'Standard_NV8as_v4'
  'Standard_NV16as_v4'
  'Standard_NV32as_v4'
]
var varAmdVmSize = contains(varAmdVmSizes, VMSize)
var varNvidiaVmSizes = [
  'Standard_NV6'
  'Standard_NV12'
  'Standard_NV24'
  'Standard_NV12s_v3'
  'Standard_NV24s_v3'
  'Standard_NV48s_v3'
  'Standard_NC4as_T4_v3'
  'Standard_NC8as_T4_v3'
  'Standard_NC16as_T4_v3'
  'Standard_NC64as_T4_v3'
  'Standard_NV6ads_A10_v5'
  'Standard_NV12ads_A10_v5'
  'Standard_NV18ads_A10_v5'
  'Standard_NV36ads_A10_v5'
  'Standard_NV36adms_A10_v5'
  'Standard_NV72ads_A10_v5'
]
var varNvidiaVmSize = contains(varNvidiaVmSizes, VMSize)

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

// get existing vm ss
// resource vmssFlex 'Microsoft.Compute/virtualMachineScaleSets@2024-03-01'existing = {
//   name: VmssName
// }

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
    // virtualMachineScaleSet:{
    //   id: vmssFlex.id
    // }
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

  // HostPool join 
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
    dependsOn: [ 
      AddWVDHost 
      //RBACVmContributor
    ]
  }

  resource AntiMalwareExtension 'extensions@2023-09-01' = {
    name: 'MicrosoftAntiMalware'
    //parent: virtualMachine
    location: Location
    properties: {
      publisher: 'Microsoft.Azure.Security'
      type: 'IaaSAntimalware'
      typeHandlerVersion: '1.3'
      autoUpgradeMinorVersion: true
      enableAutomaticUpgrade: false
      settings: {
          AntimalwareEnabled: true
          RealtimeProtectionEnabled: 'true'
          ScheduledScanSettings: {
              isEnabled: 'true'
              day: '7' // Day of the week for scheduled scan (1-Sunday, 2-Monday, ..., 7-Saturday)
              time: '120' // When to perform the scheduled scan, measured in minutes from midnight (0-1440). For example: 0 = 12AM, 60 = 1AM, 120 = 2AM.
              scanType: 'Quick' //Indicates whether scheduled scan setting type is set to Quick or Full (default is Quick)
          }
          Exclusions: {
              Extensions: '*.vhd;*.vhdx'
              Paths: '"%ProgramFiles%\\FSLogix\\Apps\\frxdrv.sys;%ProgramFiles%\\FSLogix\\Apps\\frxccd.sys;%ProgramFiles%\\FSLogix\\Apps\\frxdrvvt.sys;%TEMP%\\*.VHD;%TEMP%\\*.VHDX;%Windir%\\TEMP\\*.VHD;%Windir%\\TEMP\\*.VHDX;${varFslogixSharePath}\\*\\*.VHD;${varFslogixSharePath}\\*\\*.VHDX'
              Processes: '%ProgramFiles%\\FSLogix\\Apps\\frxccd.exe;%ProgramFiles%\\FSLogix\\Apps\\frxccds.exe;%ProgramFiles%\\FSLogix\\Apps\\frxsvc.exe'
          }
      }
      // protectedSettings: !empty(protectedSettings) ? protectedSettings : null
      // suppressFailures: supressFailures
    }
  }

  tags: Tags
}

// // Add antimalware extension to session host.
// module sessionHostsAntimalwareExtension '../../../../avm/1.0.0/res/compute/virtual-machine/extension/main.bicep' = [for i in range(1, count): {
//   scope: resourceGroup('${subscriptionId}', '${computeObjectsRgName}')
//   name: 'SH-Antimal-${namePrefix}-${batchId}-${i - 1}-${time}'
//   params: {
//       location: location
//       virtualMachineName: '${namePrefix}${padLeft((i + countIndex), 4, '0')}'
//       name: 'MicrosoftAntiMalware'
//       publisher: 'Microsoft.Azure.Security'
//       type: 'IaaSAntimalware'
//       typeHandlerVersion: '1.3'
//       autoUpgradeMinorVersion: true
//       enableAutomaticUpgrade: false
//       settings: {
//           AntimalwareEnabled: true
//           RealtimeProtectionEnabled: 'true'
//           ScheduledScanSettings: {
//               isEnabled: 'true'
//               day: '7' // Day of the week for scheduled scan (1-Sunday, 2-Monday, ..., 7-Saturday)
//               time: '120' // When to perform the scheduled scan, measured in minutes from midnight (0-1440). For example: 0 = 12AM, 60 = 1AM, 120 = 2AM.
//               scanType: 'Quick' //Indicates whether scheduled scan setting type is set to Quick or Full (default is Quick)
//           }
//           Exclusions: createAvdFslogixDeployment ? {
//               Extensions: '*.vhd;*.vhdx'
//               Paths: '"%ProgramFiles%\\FSLogix\\Apps\\frxdrv.sys;%ProgramFiles%\\FSLogix\\Apps\\frxccd.sys;%ProgramFiles%\\FSLogix\\Apps\\frxdrvvt.sys;%TEMP%\\*.VHD;%TEMP%\\*.VHDX;%Windir%\\TEMP\\*.VHD;%Windir%\\TEMP\\*.VHDX;${fslogixSharePath}\\*\\*.VHD;${fslogixSharePath}\\*\\*.VHDX'
//               Processes: '%ProgramFiles%\\FSLogix\\Apps\\frxccd.exe;%ProgramFiles%\\FSLogix\\Apps\\frxccds.exe;%ProgramFiles%\\FSLogix\\Apps\\frxsvc.exe'
//           } : {}
//       }
//   }
//   dependsOn: [
//       sessionHosts
//   ]
// }]

// get existing DCR

// resource existingDataCollectionRule 'Microsoft.Insights/dataCollectionRules@2022-06-01' existing = {
//   name: DataCollectionRuleName
// }

// Data collection rule association
module dataCollectionRuleAssociation '.bicep/dataCollectionRulesAssociation.bicep' =  {
  //scope: resourceGroup('${subscriptionId}', '${computeObjectsRgName}')
  name: 'DCR-Asso-${VMName}'
  params: {
      virtualMachineName: VMName
      dataCollectionRuleId: DataCollectionRuleName
  }
  dependsOn: [
      VM
  ]
}

resource sessionHostConfig 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  name:'SH-Config'
  location: Location
  parent: VM
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: array(varSessionHostConfigurationScriptUri)
    }
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File ${varSessionHostConfigurationScript} ${varScriptArguments}'
    }
  }
}

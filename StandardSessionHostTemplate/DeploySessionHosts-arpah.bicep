// This is a sample bicep file //


param Location string = resourceGroup().location
param AvailabilityZones array = []
param VMNames array
param VMSize string

param SubnetID string

param AdminUsername string

param AcceleratedNetworking bool
param DiskType string

param Tags object = {}

param ImageReference object
param SecurityProfile object = {}

//HostPool join
param HostPoolName string
@secure()
param HostPoolToken string
param WVDArtifactsURL string = 'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_01-19-2023.zip'

//Domain Join
param DomainJoinObject object = {}

@secure()
param DomainJoinPassword string = ''

@sys.description('Required, the storage account name for the FSLogix profile container')
param FslogixStorageName string

@sys.description('Required, the file share name for the FSLogix profile container')
param FslogixFileShareName string

@sys.description('Required, the file for configuring the session host')
param BaseScriptUri string

@sys.description('Required, the name of the virtual machine scale set')
param VmssName string

// @sys.description('Required, Host Pool Resource Group')
// param HostPoolResourceGroup string

// @sys.description('Required, Function App Name')
// param FunctionAppName string

module deploySessionHosts 'modules/AVDStandardSessionHost-arpah.bicep' = [for vm in VMNames: {
  name: 'deploySessionHost-${vm}'
  params: {
    AcceleratedNetworking: AcceleratedNetworking
    AdminUsername: AdminUsername
    HostPoolName: HostPoolName
    HostPoolToken:  HostPoolToken
    ImageReference: ImageReference
    SecurityProfile: SecurityProfile
    SubnetID: SubnetID
    VMName: vm
    VMSize: VMSize
    DiskType: DiskType
    WVDArtifactsURL:  WVDArtifactsURL
    DomainJoinObject: DomainJoinObject
    DomainJoinPassword: DomainJoinPassword
    Location: Location
    AvailabilityZones: AvailabilityZones
    BaseScriptUri: BaseScriptUri
    FslogixStorageName: FslogixStorageName
    FslogixFileShareName: FslogixFileShareName
    VmssName: VmssName
    // HostPoolResourceGroup: HostPoolResourceGroup
    // FunctionAppName: FunctionAppName
    Tags: Tags
  }
}]

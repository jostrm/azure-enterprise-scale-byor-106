@description('Specifies the project number, such as a string "005". This is used to generate the projectName to embed in resources such as "prj005"')
param projectNumber string
@description('Specifies the name of the environment [dev,test,prod]. This name is reflected in resource group and sub-resources')
param env string
@description('ESML COMMON Resource Group prefix. If "rg-msft-word" then "rg-msft-word-esml-common-weu-dev-001"')
param commonRGNamePrefix string
@description('Such as "weu" or "swc" (swedencentral datacenter).Reflected in resource group and sub-resources')
param locationSuffix string
@description('AI Factory suffix. If you have multiple instances, -001')
param aifactorySuffixRG string
@description('Specifies the tags2 that should be applied to newly created resources')
param tags object
@description('Deployment location.')
param location string
@description('Resource group where your vNet resides')
param commonResourceSuffix string
@description('Specifies the virtual network name')
param vnetNameBase string = 'vnt-esmlcmn'
param vnetResourceGroup_param string = ''
param vnetNameFull_param string = ''
param network_env string = ''
param subscriptions_subscriptionId string = subscription().subscriptionId

var projectName = 'prj${projectNumber}'
var subscriptionIdDevTestProd = subscription().subscriptionId
var targetResourceGroup = '${commonRGNamePrefix}esml-${replace(projectName, 'prj', 'project')}-${locationSuffix}-${env}${aifactorySuffixRG}-rg'
var vnetId = '${subscriptions_subscriptionId}/resourceGroups/${vnetResourceGroup_param}/providers/Microsoft.Network/virtualNetworks/${vnetNameFull}'
var uniqueDepl = '${projectName}${locationSuffix}${env}${aifactorySuffixRG}'
var vnetNameFull = vnetNameFull_param != '' ?  replace(vnetNameFull_param, '<network_env>', network_env) : '${vnetNameBase}-${locationSuffix}-${env}${commonResourceSuffix}'

resource projectResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: targetResourceGroup
  scope:subscription(subscriptionIdDevTestProd)
}

param aks_dev_defaults array = [
  'Standard_B4ms' // 4 cores, 16GB, 32GB storage: Burstable (2022-11 this was the default in Azure portal)
  'Standard_A4m_v2' // 4cores, 32GB, 40GB storage (quota:100)
  'Standard_D3_v2' // 4 cores, 14GB RAM, 200GB storage
] 
param aks_testProd_defaults array = [
  'Standard_DS13-2_v2' // 8 cores, 14GB, 112GB storage
  'Standard_A8m_v2' // 8 cores, 64GB RAM, 80GB storage (quota:100)
]

param kubernetesVersionAndOrchestrator string = '1.30.3'
@description('DEV default  VM size for the default AKS cluster:Standard_D12. More: Standard_D3_v2(4,14)')
param aksVmSku_dev string = aks_dev_defaults[0]
@description('DEV default  VM size for the default AKS cluster:Standard_D12. More: Standard_D3_v2(4,14)')
param aksVmSku_testProd string = aks_testProd_defaults[0]
@description('EMSL will use default subnetID, built on projectname example: ork/virtualNetworks/vnetNameFull/subnets/snt-prj003-aks')
param overrideSubnetId string = ''
@description('Keep it short. 1 char, since max 16 chars in name')
param aksSuffix string = ''  // sdf


var aksSubnetName  = 'snt-prj${projectNumber}-aks'
var aksSubnetId = '${vnetId}/subnets/${aksSubnetName}' // ${subscriptions_subscriptionId}/resourceGroups/${commonResourceGroup}/providers/Microsoft.Network/virtualNetworks/${vnetNameFull}/subnets/snt-prj003-aks
var activeAksSubnetId = overrideSubnetId == ''? aksSubnetId: overrideSubnetId
var aksName = 'esml${projectNumber}-${locationSuffix}-${env}${aksSuffix}' // esml001-weu-prod (20/16) VS esml001-weu-prod (16/16)
var nodeResourceGroupName = 'aks${aksSuffix}-${resourceGroup().name}' // aks-abc-def-esml-project001-weu-dev-003-rg (unique within subscription)

module aksDev '../../azure-enterprise-scale-ml/environment_setup/aifactory/bicep/modules/aksCluster.bicep'  = if(env == 'dev'){
  scope: resourceGroup(subscriptionIdDevTestProd,targetResourceGroup)
  name: 'AMLAKSDev4${uniqueDepl}'
  params: {
    name: aksName //'aks-{projectNumber}-${locationSuffix}-${env}${prjResourceSuffix}'
    tags: tags
    location: location
    kubernetesVersion: kubernetesVersionAndOrchestrator // az aks get-versions --location westeurope --output table    // in Westeurope '1.21.2'  is not allowed/supported
    dnsPrefix: '${aksName}-dns'
    enableRbac: true
    nodeResourceGroup: nodeResourceGroupName // 'esml-${replace(projectName, 'prj', 'project')}-aksnode-${env}-rg'
    agentPoolProfiles: [
      {
        name: toLower('agentpool')
        count: 1
        vmSize: aksVmSku_dev
        osType: 'Linux'
        osSKU: 'Ubuntu'
        mode: 'System'
        vnetSubnetID: activeAksSubnetId
        type: 'VirtualMachineScaleSets'
        maxPods: 30 //110  total maxPods(maxPods per node * node count), the total maxPods(10 * 1) should be larger than 30.
        orchestratorVersion: kubernetesVersionAndOrchestrator // in Westeurope '1.21.2'  is not allowed/supported
        osDiskSizeGB: 128
      }
    ]
  }
  dependsOn: [
    projectResourceGroup
  ]
}

module aksTestProd '../../azure-enterprise-scale-ml/environment_setup/aifactory/bicep/modules/aksCluster.bicep'  = if(env == 'test' || env == 'prod'){
  scope: resourceGroup(subscriptionIdDevTestProd,targetResourceGroup)
  name: 'AMLAKSTestProd4${uniqueDepl}'
  params: {
    name: aksName 
    tags: tags
    location: location
    kubernetesVersion: kubernetesVersionAndOrchestrator 
    dnsPrefix: '${aksName}-dns' 
    enableRbac: true
    nodeResourceGroup: nodeResourceGroupName 
    agentPoolProfiles: [
      {
        name: 'agentpool'
        count: 3
        vmSize: aksVmSku_testProd
        osType: 'Linux'
        osSKU: 'Ubuntu'
        mode: 'System'
        vnetSubnetID: activeAksSubnetId
        type: 'VirtualMachineScaleSets'
        maxPods: 30 // maxPods: 110
        orchestratorVersion: kubernetesVersionAndOrchestrator
      }
    ]
  }
  dependsOn: [
    projectResourceGroup
  ]
}

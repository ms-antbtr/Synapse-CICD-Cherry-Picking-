# Import-Module -Name C:\Repos\FIN-STR-PLR-MercV2-Core\_\Common\PowerShell\Modules\ConfigFunctions

# $Dict = @{
# a = "foo";
# b = 'bar';
# }

# $Dict.Keys

# $Dict.GetEnumerator() | Select-Object -Property Value, Name

# Import-Module -Name C:\Users\traberc\Downloads\Infrastructure\PowerShell\Modules\ConfigFunctions

# $Params = @{
#     ArmTemplatePath      = 'C:\Users\traberc\Downloads\Infrastructure\ServiceGroupRoot\ARM\Templates\SynapseWorkspace_BigDataPool.template.json';
#     ConfigPath           = 'C:\Users\traberc\Downloads\Infrastructure\Config\Environment\NonProd-RV-WestUS2.json';
#     OutputFolder         = 'C:\Temp\MercuryV2CICD\Target';
#     OutputFolderSuffixes = @('ARM', 'Parameters');
#     TemplateNameList     = 'SynapseWorkspace_BigDataPool';
#     ItemNameList         = 'AdHoc';
# }

# ProcessTemplateParameterCopy @Params

<#
function Touch-Path {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    (Test-Path -Path $Path) ? (Get-Item -Path $Path) : (New-Item -Path $Path -ItemType Directory)
}
#>

$ErrorActionPreference = 'stop'

Import-Module -Name C:\Repos\FIN-STR-PLR-MercV2-Core\_\Common\PowerShell\Modules\ConfigFunctions
Import-Module -Name C:\Repos\FIN-STR-PLR-MercV2-Core\_\Common\PowerShell\Modules\SynapseFunctions -Force

$Params = @{
    EnvironmentConfigPath = 'C:\Users\traberc\Downloads\Infrastructure\Config\Environment';
    OutputFolder          = 'C:\Temp\MercuryV2CICD\Target';
    SynapseSourcePath     = 'C:\Users\traberc\Downloads\SynapseWorkspace\Source\Synapse';
}

Process-SynapseWorkspaceEnvironmentConfigs @Params

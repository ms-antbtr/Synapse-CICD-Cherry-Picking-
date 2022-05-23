<#
.DESCRIPTION

Takes a path containing Synapse Spark job configuration files. Names of all linked Spark data pools are extracted and
matched with the provided environment configuration.

Iterates over the list of Spark data pools and initiates an ARM template deployment for each Spark pool
#>
param (
    # Repository root of the synapse workspace
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SynapseSourcePath,

    # Full path to the environment configuration root folder
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ConfigPath,

    # Name of the target environment configuration. Do not include extension (`.json`)
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ConfigName,

    # Full path to ARM template to deploy
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ArmTemplateFile,

    # Full path to ARM template to deploy
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ArmParameterFilePath,

    [switch]$IncludePoolSparkConfig,

    [switch]$WhatIf
)

<#
Read environment configuration file

`<ConfigPath>/<ConfigName>.json`

- $EnvironmentConfig
#>
[System.IO.DirectoryInfo]$ConfigPathObj = Get-Item -Path $ConfigPath

[string]$ConfigFileFullName = Join-Path -Path $ConfigPathObj.FullName -ChildPath ("{0}.json" -f $ConfigName)

if (-not (Test-Path -Path $ConfigFileFullName)) {
    throw "Config file '$ConfigFileFullName' does not exist" 
}

[psobject]$ConfigObj = Get-Content -Path $ConfigFileFullName -Raw | ConvertFrom-Json

[string]$Location = $ConfigObj.Location
[string]$ResourceGroupName = $ConfigObj.ResourceGroup_Name
[string]$SynapseWorkspaceName = $ConfigObj.SynapseWorkspace_Name

Write-Host "Location       : $Location"
Write-Host "Resource group : $ResourceGroupName"
Write-Host "Workspace name : $SynapseWorkspaceName"


<#
ARM template file
#>
if (-not (Test-Path -Path $ArmTemplateFile)) {
    throw "ARM template file '$ArmTemplateFile' not found"
}

$ArmTemplateFileObj = Get-Item -Path $ArmTemplateFile

Write-Verbose "ARM template file: $($ArmTemplateFileObj.FullName)"

# Initialize empty hashtable of data pools to deploy. Hashtable will eliminate duplicates
$DataPoolsToDeploy = New-Object -TypeName System.Collections.Generic.List[string]

<#
    Extract referenced data pool names from job definitions
#>
[string]$JobDefinitionPath = Join-Path -Path $SynapseSourcePath -ChildPath 'sparkJobDefinition'

Write-Verbose "Job definition path: $JobDefinitionPath"

if (-not (Test-Path -Path $JobDefinitionPath)) {
    Write-Warning "Job definition path '$JobDefinitionPath' does not exist"
}
else {
    [System.IO.FileInfo[]]$JobFiles = Get-ChildItem -Path $JobDefinitionPath -File -Filter *.json

    if ($JobFiles.Count -eq 0) {
        Write-Warning "No JSON found in '$JobDefinitionPath'"
    }

    foreach ($File in $JobFiles) {
        [string]$JobName = $File.BaseName
        Write-Host -ForegroundColor Green "Job: $JobName"

        $JobConfiguration = Get-Content -Path $File.FullName -Raw | ConvertFrom-Json

        $JobConfiguration | ConvertTo-Json -Depth 10 | Write-Debug
        
        $DataPoolName = $JobConfiguration.properties.targetBigDataPool.referenceName

        Write-Host -ForegroundColor Cyan "`tData pool name: $DataPoolName"
        $DataPoolsToDeploy.Add($DataPoolName)
    }
}


<#
    Extract referenced data pools from notebooks
#>

[string]$NotebookDefinitionPath = Join-Path -Path $SynapseSourcePath -ChildPath 'notebook'

Write-Verbose "Notebook definition path: $NotebookDefinitionPath"

if (-not (Test-Path -Path $NotebookDefinitionPath)) {
    Write-Warning "Notebook definition path '$NotebookDefinitionPath' does not exist"
}
else {
    [System.IO.FileInfo[]]$NotebookFiles = Get-ChildItem -Path $NotebookDefinitionPath -File -Filter *.json

    if ($NotebookFiles.Count -eq 0) {
        Write-Warning "No JSON found in '$NotebookDefinitionPath'"
    }

    foreach ($File in $NotebookFiles) {
        [string]$NotebookName = $File.BaseName
        Write-Host -ForegroundColor Green "Notebook: $NotebookName"

        $NotebookConfiguration = Get-Content -Path $File.FullName -Raw | ConvertFrom-Json

        $NotebookConfiguration | ConvertTo-Json -Depth 10 | Write-Debug
    
        $DataPoolName = $NotebookConfiguration.properties.bigDataPool.referenceName

        Write-Host -ForegroundColor Cyan "`tData pool name: $DataPoolName"
        $DataPoolsToDeploy.Add($DataPoolName)
    }
}

foreach ($DataPoolName in $DataPoolsToDeploy) {
    Write-Host -ForegroundColor Cyan "Deploying data pool '$DataPoolName'"

    #
    # First, deploy the data pool using an ARM template
    #
    $ArmParameterFileName = Join-Path -Path $ArmParameterFilePath -ChildPath $ConfigName -AdditionalChildPath ($ArmTemplateFileObj.Name.Replace(".template.", ".$($DataPoolName).parameters."))

    Write-Verbose "Parameter file: $ArmParameterFileName"

    Test-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $ArmTemplateFileObj.FullName -TemplateParameterFile $ArmParameterFileName

    New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $ArmTemplateFileObj.FullName -TemplateParameterFile $ArmParameterFileName -WhatIf:$WhatIf

    #
    # Next, upload a data pool Spark configuration if defined in the environment config
    #
    if ($IncludePoolSparkConfig) {
        Write-Verbose "Checking for Spark config"

        $PoolSparkConfig = ($ConfigObj.Synapse.BigDataPools | Where-Object { $_.Name -eq $DataPoolName } | Select-Object -First 1).SparkConfig
        
        if ($null -ne $PoolSparkConfig) {
            $SparkConfigFileName = Join-Path -Path $ENV:TEMP -ChildPath ($DataPoolName + '.txt')

            Write-Verbose $SparkConfigFileName

            $SparkConfigContents = $PoolSparkConfig -join "`r`n"

            Write-Verbose $SparkConfigContents

            $SparkConfigContents | Out-File -FilePath $SparkConfigFileName -Encoding ascii

            if (Test-Path -Path $SparkConfigFileName) {
                Write-Host -ForegroundColor Cyan "`tUploading file '$SparkConfigFileName'"

                $Params = @{
                    ResourceGroupName   = $ConfigObj.ResourceGroup_Name;
                    WorkspaceName       = $ConfigObj.SynapseWorkspace_Name;
                    Name                = $DataPoolName;
                    SparkConfigFilePath = $SparkConfigFileName;
                }

                Write-Verbose $Params

                $SparkPoolObj = Update-AzSynapseSparkPool @Params

                Write-Debug $SparkPoolObj
            }
            else {
                Write-Warning "No config file created"
            }
        }
        else {
            Write-Verbose "No Spark config defined for this pool"
        }
    }
    else {
        Write-Host "Skipping Spark pool config check"
    }
}

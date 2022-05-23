function Deploy-SynapseDataPoolsFromBuild {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ArmTemplateFile,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ArmParameterFilePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceGroupName,

        [switch]$SkipSparkConfig
    )

    #
    # Show parameter values
    #
    Write-Host "ArmTemplateFile      : $ArmTemplateFile"
    Write-Host "ArmParameterFilePath : $ArmParameterFilePath"
    Write-Host "ResourceGroupName    : $ResourceGroupName"
    Write-Host ''

    if (-not (Test-Path -Path $ArmTemplateFile)) {
        throw "ARM template file '$($ArmTemplateFile)' not found"
    }

    $ArmTemplateFileObj = Get-Item -Path $ArmTemplateFile;

    #
    # Find all the matching parameter files for the given template
    #
    $ParameterFileNameFilter = $ArmTemplateFileObj.Name.Replace('.template.', '.*.parameters.')

    Write-Host "Parameter file name filter : $ParameterFileNameFilter"
    Write-Host ''

    $ParameterFileList = Get-ChildItem -Path $ArmParameterFilePath -File -Filter $ParameterFileNameFilter

    $ParameterFileList | Format-List -Property Name, FullName

    #
    # Loop through all the parameter files found in the provided build location
    #
    foreach ($ParameterFile in $ParameterFileList) {
        Write-Host "Parameter file : $($ParameterFile.Name) ($($ParameterFile.FullName))"
        Write-Host ''

        #
        # Deploy Spark data pool using ARM template deployment
        #
        $Params = @{
            ResourceGroupName     = $ResourceGroupName;
            TemplateFile          = $ArmTemplateFile;
            TemplateParameterFile = $ParameterFile.FullName;
        }

        $ResourceGroupDeploymentResult = New-AzResourceGroupDeployment @Params

        $ResourceGroupDeploymentResult | Format-List -Property *

        if (-not $SkipSparkConfig) {
            #
            # Read parameters from JSON file to get values for Spark config release
            #
            $TemplateParameterObj = Get-Content -Path $ParameterFile.FullName -Raw | ConvertFrom-Json

            $DataPoolName = $TemplateParameterObj.parameters.SynapseWorkspace_BigDataPool_Name.value
            $SynapseWorkspaceName = $TemplateParameterObj.parameters.SynapseWorkspace_Name.value

            if (-not $DataPoolName) {
                Write-Warning "Data pool name not found in the template parameter file. Skipping Spark config check"
                continue
            }

            Write-Host "Synapse workspace : $SynapseWorkspaceName"
            Write-Host "Data pool         : $DataPoolName"

            $SparkConfigFileName = Join-Path -Path $ArmParameterFilePath -ChildPath "SparkConfig_$($DataPoolName).txt"

            Write-Host "Config file name  : $SparkConfigFileName"

            if (Test-Path -Path $SparkConfigFileName) {
                Write-Host "`tLoading Spark pool config file"

                $Params = @{
                    ResourceGroupName   = $ResourceGroupName;
                    WorkspaceName       = $SynapseWorkspaceName;
                    Name                = $DataPoolName;
                    SparkConfigFilePath = $SparkConfigFileName;
                }

                $SparkPoolObj = Update-AzSynapseSparkPool @Params

                $SparkPoolObj | Format-List
            }
            else {
                Write-Host "`tNo pool-specific config found"
            }

            Write-Host ''
        }
    }
}
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ConfigPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputFolder,

    [string[]]$OutputFolderSuffixes = @(),

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TemplateFile,

    [string[]]$DataPoolNames = @()
)

#
# Output parameter values to verbose output
#
$OriginalParameters = @{
    ConfigPath           = $ConfigPath;
    OutputFolder         = $OutputFolder;
    OutputFolderSuffixes = ($OutputFolderSuffixes -join ', ');
    TemplateFile         = $TemplateFile;
    DataPoolNames        = ($DataPoolNames -join ', ');
}

Write-Verbose '-- Start: Parameters --'
$MaxKeyLength = $OriginalParameters.Keys | ForEach-Object { $_.Length } | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
$OriginalParameters.Keys | Sort-Object | ForEach-Object { Write-Verbose ("{0,-$MaxKeyLength} : {1}" -f $_, $OriginalParameters.Item($_)) }
Write-Verbose '-- End: Parameters --'

#
# Get all the environment config file in $ConfigPath
#
$ConfigFiles = Get-ChildItem -Path $ConfigPath -File -Filter *.json | Where-Object { -not $_.Name.StartsWith('_') } | Select-Object -Property BaseName, Name, FullName
$ConfigFiles | Format-Table -Property Name, FullName -AutoSize

#
# Create root output folder
#
$OutputFolderObj = Touch-Path -Path $OutputFolder
Write-Host -ForegroundColor Gray "Output folder root : $($OutputFolderObj.FullName)"

#
# Get the contents of the ARM template file. This will be used to generate the parameter files later on
#
$TemplateFileContent = Get-Content -Path $TemplateFile -Raw

#
# Loop through each config file to get the configuration for each Spark pool, then output a specialized parameter file using those values.
#
foreach ($File in $ConfigFiles) {
    $EnvironmentConfigName = $File.BaseName

    Write-Host -ForegroundColor Green "Environment: $EnvironmentConfigName"

    #
    # Read the current configuration file JSON into a PowerShell object
    #
    $EnvironmentConfigObj = Get-Content -Path $File.FullName -Raw | ConvertFrom-Json -AsHashtable
    $SynapseWorkspaceName = $EnvironmentConfigObj.Synapse_Workspace_Name
    $Location = $EnvironmentConfigObj.Location

    # Create the target output folder
    $ThisOutputFolderName = Join-Path -Path $OutputFolderObj.FullName -ChildPath $EnvironmentConfigName -AdditionalChildPath $OutputFolderSuffixes
    $ThisOutputFolderObj = Touch-Path -Path $ThisOutputFolderName

    Write-Host "Output folder: $($ThisOutputFolderObj.FullName)"

    # Select a filtered list if $DataPoolNames were provided
    if ($null -ne $DataPoolNames -and $DataPoolNames.Count -gt 0) {
        $BigDataPools = $EnvironmentConfigObj.Synapse.BigDataPools | Where-Object { $DataPoolNames -contains $_.Name }
    }
    else {
        $BigDataPools = $EnvironmentConfigObj.Synapse.BigDataPools
    }

    # Loop through the selected Spark pools
    foreach ($BigDataPool in $BigDataPools) {
        Write-Host -ForegroundColor Cyan "`tPool name: $($BigDataPool.Name)"

        $ThisParameterFileName = Join-Path -Path $ThisOutputFolderObj.FullName -ChildPath ("SynapseWorkspace_BigDataPool.{0}.parameters.json" -f $BigDataPool.Name)

        Write-Verbose "Output file name: $ThisParameterFileName"

        $ParameterValues = $BigDataPool | Convert-ObjectPropertiesToDictionary -KeyPrefix 'SynapseWorkspace_BigDataPool_'
        $ParameterValues['Synapse_Workspace_Name'] = $SynapseWorkspaceName
        $ParameterValues['Location'] = $Location

        # $ParameterValues.Keys | Sort-Object | ForEach-Object { Write-Host -ForegroundColor White ("{0} : {1}" -f $_, $ParameterValues[$_])}

        $ParameterFileContent = $TemplateFileContent | ConvertTo-ArmParameterTemplate -ParameterValues $ParameterValues
        $ParameterFileContent | Out-File -FilePath $ThisParameterFileName

        if ($BigDataPool.SparkConfig) {
            $SparkConfig = $BigDataPool.SparkConfig -join "`r`n"

            Write-Host "Spark config:`r`n$SparkConfig"

            $SparkConfigFileName = Join-Path -Path $ThisOutputFolderObj.FullName -ChildPath ("SparkConfig_{0}.txt" -f $BigDataPool.Name)

            $SparkConfig | Out-File -FilePath $SparkConfigFileName -Encoding ascii
        }
    }
}
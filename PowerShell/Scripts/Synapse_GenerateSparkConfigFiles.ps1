<#
Import-Module -Name C:\Repos\FIN-STR-PLR-Data-FeedGenerator\_\Common\PowerShell\Modules\ConfigFunctions
#>

param (
    # Config path
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$EnvironmentConfigPath,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputFolder,

    [string[]]$OutputFolderSuffixes = @(),

    # Data pool names, or empty for all
    [string[]]$DataPoolNames = @()
)

Write-Host -ForegroundColor Magenta "Environment config path: $EnvironmentConfigPath"
Write-Host

$EnvironmentConfigPathObj = Get-Item -Path $EnvironmentConfigPath

$ConfigFiles = Get-ChildItem -Path $EnvironmentConfigPathObj.FullName -File -Filter *.json | Where-Object { -not $_.Name.StartsWith('_') }

$OutputFolderObj = Touch-Path -Path $OutputFolder

foreach ($ConfigFileObj in $ConfigFiles) {
    $ConfigName = $ConfigFileObj.BaseName

    Write-Host -ForegroundColor Green "Config: $ConfigName"
    Write-Host -ForegroundColor DarkGray "`t$($ConfigFileObj.FullName)"

    $ConfigObj = Get-Content -Path $ConfigFileObj.FullName -Raw | ConvertFrom-Json -AsHashtable

    if ($ConfigObj.Synapse.BigDataPool_SparkConfig) {
        Write-Host -ForegroundColor Cyan "`t'Synapse/BigDataPool_SparkConfig' key found"
        #Write-Host -ForegroundColor Gray $ConfigObj.Synapse.BigDataPool_SparkConfig

        $SparkConfigs = $ConfigObj.Synapse.BigDataPool_SparkConfig # | Convert-ObjectPropertiesToDictionary

        foreach ($SparkConfigName in $SparkConfigs.Keys) {
            if ($DataPoolNames.Count -gt 0 -and -not $DataPoolNames.Contains($SparkConfigName)) {
                Write-Host "Data pool '$SparkConfigName' not in selected list"
                continue
            }

            Write-Host -ForegroundColor Cyan "`t`t$SparkConfigName"

            $SparkConfigFileContent = $SparkConfigs[$SparkConfigName]

            $SparkConfigOutputFileName = "SparkConfig_$SparkConfigName.txt"
            $SparkConfigOutputFolder = Join-Path -Path $OutputFolderObj.FullName -ChildPath $ConfigName -AdditionalChildPath $OutputFolderSuffixes
            $SparkConfigOutputFolderObj = Touch-Path -Path $SparkConfigOutputFolder

            $SparkConfigOutputFileFullName = Join-Path -Path $SparkConfigOutputFolderObj.FullName -ChildPath $SparkConfigOutputFileName
 
            $SparkConfigFileContent | Out-File -FilePath $SparkConfigOutputFileFullName -Encoding ascii
        }
    }
    else {
        Write-Warning "`t'Synapse.BigDataPool_SparkConfig' key not found in config file"
    }

    Write-Host
}
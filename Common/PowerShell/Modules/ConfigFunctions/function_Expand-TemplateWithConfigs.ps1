<#
.SYNOPSIS

TBD

.INPUTS

TBD

.OUTPUTS

TBD
#>
function Expand-TemplateWithConfigs {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TemplateFile,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigPath,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputFolder,

        [string[]]$OutputFolderSuffixes = @(),

        [bool]$ExceptionOnMissingValue = $true
    )

    if (-not (Test-Path -Path $TemplateFile)) {
        throw "Template file '$TemplateFile' does not exist"
    }

    $TemplateFileObj = Get-Item -Path $TemplateFile
    $TemplateName = $TemplateFileObj.BaseName.Split('.')[0]

    Write-Host -ForegroundColor Magenta "Template name : $TemplateName"
    Write-Host -ForegroundColor DarkMagenta "Template file : $($TemplateFileObj.FullName)"

    $TemplateFileContent = Get-Content -Path $TemplateFileObj.FullName -Raw

    $ConfigFiles = Get-ChildItem -Path $ConfigPath -File -Filter *.json

    if ($ConfigFiles.Count -eq 0) {
        throw "No config files found in '$ConfigPath'"
    }

    Write-Host "Reading config files from '$ConfigPath'"

    $OutputFolderObj = Touch-Path -Path $OutputFolder

    Write-Host "Writing output files to '$($OutputFolderObj.FullName)'"

    foreach ($ConfigFileObj in $ConfigFiles) {
        $ThisConfigName = $ConfigFileObj.BaseName

        Write-Host -ForegroundColor Green "Config: $ThisConfigName"
        Write-Host -ForegroundColor DarkGreen "$($ConfigFileObj.FullName)"

        $ThisConfigFileValues = Get-Content -Path $ConfigFileObj.FullName -Raw | ConvertFrom-Json -AsHashtable

        $MaxLength = $ThisConfigFileValues.Keys | ForEach-Object { $_.Length } | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum

        # $ThisConfigFileValues | Format-Table -AutoSize

        $ThisConfigFileValues.Keys | Sort-Object | ForEach-Object { Write-Host ('{0} : {1}' -f $_.PadRight($MaxLength), $ThisConfigFileValues[$_])}

        $ThisOutputFileContent = $TemplateFileContent | ReplaceTokens -TokenValues $ThisConfigFileValues -Debug -ExceptionOnMissingValue:$ExceptionOnMissingValue

        # Create parent folder if it doesn't exist and return folder object
        $ThisOutputFileName = '{0}{1}' -f $TemplateName, $TemplateFileObj.Extension
        $ThisOutputFolder = Join-Path -Path $OutputFolderObj.FullName -ChildPath $ThisConfigName -AdditionalChildPath $OutputFolderSuffixes
        $ThisOutputFolderObj = Touch-Path -Path $ThisOutputFolder
        $ThisOutputFileFullName = Join-Path -Path $ThisOutputFolderObj.FullName -ChildPath $ThisOutputFileName
 
        Write-Host -ForegroundColor DarkGray "Writing contents to '$ThisOutputFileFullName'"

        $ThisOutputFileContent | Out-File -FilePath $ThisOutputFileFullName -Encoding utf8NoBOM
    }
}
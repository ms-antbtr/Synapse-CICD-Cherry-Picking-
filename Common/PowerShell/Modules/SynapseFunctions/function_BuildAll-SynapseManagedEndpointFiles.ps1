function BuildAll-SynapseManagedEndpointFiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigPath,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputFolder,

        [string[]]$OutputFolderSuffixes = @()
    )
    # import-module -Name C:\Repos\FIN-STR-PLR-MercV2-Core\_\Common\PowerShell\Modules\SynapseFunctions

    # Import-Module ConfigFunctions
    
    if (-not (Test-Path -Path $ConfigPath)) {
        throw "Config path '$ConfigPath' not found"
    }
    
    $ConfigPathObj = Get-Item -Path $ConfigPath

    $OutputFolderObj = Touch-Path -Path $OutputFolder

    $ConfigFileItems = Get-ChildItem -Path $ConfigPathObj.FullName -File -Filter *.json | Where-Object { -not $_.Name.StartsWith('_') }

    foreach ($FileObj in $ConfigFileItems) {
        Write-Host -ForegroundColor Green "Config file: $($FileObj.Name) ($($FileObj.FullName)))"

        $ConfigName = $FileObj.BaseName

        $ThisOutputFolder = Join-Path -Path $OutputFolderObj.FullName -ChildPath $ConfigName -AdditionalChildPath $OutputFolderSuffixes

        Build-SynapseManagedEndpointFiles -ConfigFile $FileObj.FullName -OutputFolder $ThisOutputFolder
    }
}
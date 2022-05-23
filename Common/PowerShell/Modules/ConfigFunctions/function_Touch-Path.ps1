<#
.SYNOPSIS

TBD
#>
function Touch-Path {
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [switch]$CleanFolder
    )

    Write-Verbose "Touch-Path: $Path"
    if (-not (Test-Path -Path $Path)) {
        Write-Verbose "Touch-Path: Creating folder"
        $Item = New-Item -Path $Path -ItemType Directory
    }
    else {
        Write-Verbose "Touch-Path: Folder already exists"
        $Item = Get-Item -Path $Path

        if ($CleanFolder) {
            $RemovedFiles = Get-ChildItem -Path $Path -Recurse | Remove-Item -Confirm

            Write-Debug $RemovedFiles
        }
    }

    $Item
}
<#
.SYNOPSIS

Reads the specified JSON file and returns the contents as a PSOjebct

.INPUTS

string path to the file to read

.OUTPUTS

PSObject
#>
function GetObjectFromJsonFile {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        throw "Source file '$Path' not found"
    }

    $FileObj = Get-Item -Path $Path

    Get-Content -Path $FileObj.FullName -Raw | ConvertFrom-Json
}
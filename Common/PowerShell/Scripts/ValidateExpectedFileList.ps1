param (
    # Folder to validate against the provided file list
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    # File containing the expected list of files. Comments can be included by starting the line with "#"
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ExpectedFileListFile,

    # If provided, the build id is included as a comment in the actual file list
    [string]$BuildId = $null,

    # Location to store the actual file list file
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputFolder,

    # Whether to generate an error on a mismatch (default) or just a warning
    [boolean]$ErrorOnFileMismatch = $true
)

$Arguments = @{
    BuildId              = $BuildId;
    ErrorOnFileMismatch  = $ErrorOnFileMismatch;
    ExpectedFileListFile = $ExpectedFileListFile;
    OutputFolder         = $OutputFolder;
    Path                 = $Path;
}

Write-Host '##[section]Arguments'
$MaxArgumentLength = ($Arguments.Keys | Measure-Object -Property Length -Maximum).Maximum
$FormatString = "{0,-$MaxArgumentLength} : {1}"
$Arguments.GetEnumerator() | Sort-Object -Property Key | ForEach-Object { Write-Host -ForegroundColor Yellow ($FormatString -f $_.Key, $_.Value) }
Write-Host ('-' * 100)
Write-Host

if (-not (Test-Path -Path $Path)) {
    Write-Error ('##[error]Path to validate "{0}" not found!' -f $Path)
    return
}

# Ternary operator "?" only works in PowerShell 7 and above (pwsh)
$OutputFolderObj = (-not (Test-Path -Path $OutputFolder)) ? (New-Item -Path $OutputFolder -ItemType Directory) : (Get-Item -Path $OutputFolder)

#
# Get actual file list first. This is output whether or not the expected file exists so the output can be used to create or update the expected file list file.
#
$PathObj = Get-Item -Path $Path

Write-Host ('##[section]Enumerate source files from "{0}"' -f $Path)

# Output file name
$ActualFileName = 'ActualFileList_{0}.txt' -f $BuildId
# Output full name
$ActualFileFullName = Join-Path -Path $OutputFolderObj.FullName -ChildPath $ActualFileName

Write-Host -ForegroundColor Magenta ('Writing file list to "{0}"' -f $ActualFileFullName)

# Get full list of file recursively
# TODO: Filter files using new parameter $ExcludeFilter
$ActualFiles = Get-ChildItem -Path $PathObj.FullName -Recurse -File

# Calculate the file path relative to the root folder
$RelativePaths = $ActualFiles | Select-Object -Property Name, @{n = 'RelativePath'; e = { [System.IO.Path]::GetRelativePath($PathObj.FullName, $_.FullName) } }, Extension, FullName


$ActualFileContentLines = New-Object -TypeName System.Collections.ArrayList
# $ActualFileContentLines.Add("# BuildId: $BuildId") | Out-Null
# $ActualFileContentLines.Add("# Timestamp: {0}" -f ([DateTime]::Now.ToString('yyyyMMdd-HHmmss'))) | Out-Null

$RelativePaths | Select-Object -ExpandProperty RelativePath | Sort-Object | ForEach-Object { $ActualFileContentLines.Add($_) | Out-Null }

# Write contents to file

$ActualFileContent = ($ActualFileContentLines -join "`r`n")
$ActualFileContent | Out-File -FilePath $ActualFileFullName -Encoding utf8NoBOM

Write-Host '##[group]Artifact file list'
$ActualFileContentLines | Sort-Object | ForEach-Object { Write-Host -ForegroundColor DarkGray $_ }
Write-Host '##[endgroup]'

#
# Validate and show the expected file list
#
if (-not (Test-Path -Path $ExpectedFileListFile)) {
    $ErrorMessage = 'Expected file list file "{0}" not found. Actual file list cannot be validated' -f $ExpectedFileFullName

    if ($ErrorOnFileMismatch) {
        Write-Host ("##[error]{0}" -f $ErrorMessage)
        throw $ErrorMessage
    }
    else {
        Write-Host ("##[warning]{0}" -f $ErrorMessage)
        Write-Warning $ErrorMessage
    }
}

$ExpectedFileListFileObj = Get-Item -Path $ExpectedFileListFile

$ExpectedFileListContent = Get-Content -Path $ExpectedFileListFileObj.FullName

Write-Host -ForegroundColor Cyan '##[group]Expected file list'
$ExpectedFileListContent | ForEach-Object { Write-Host -ForegroundColor DarkGray $_ }
Write-Host -ForegroundColor Cyan '##[endgroup]'

# ------------------------------------------------------------------------------------

Write-Host -ForegroundColor Cyan "##[section]Comparing actual file list with expected file list"

$SourceFileContent = @(Get-Content -Path $ActualFileFullName | Where-Object { -not $_.StartsWith('#') })
$TargetFileContent = @(Get-Content -Path $ExpectedFileListFileObj.FullName | Where-Object { -not $_.StartsWith('#') })

$FileDifferences = Compare-Object -ReferenceObject $TargetFileContent -DifferenceObject $SourceFileContent -IncludeEqual

$MissingInSource = @($FileDifferences | Where-Object { $_.SideIndicator -eq '=>' })
$MissingInTarget = @($FileDifferences | Where-Object { $_.SideIndicator -eq '<=' })

if ($MissingInTarget.Count) {
    Write-Host -ForegroundColor Yellow '##[section]Expected files missing in destination'
    $MissingInTarget | Select-Object -ExpandProperty InputObject | Sort-Object | ForEach-Object { Write-Host ('{0}' -f $_) }
    Write-Host
}

if ($MissingInSource.Count) {
    Write-Host -ForegroundColor Yellow '##[section]Unexpected files in destination'
    $MissingInSource | Select-Object -ExpandProperty InputObject | Sort-Object | ForEach-Object { Write-Host ('{0}' -f $_) }
    Write-Host
}

Write-Host '##[group]TL;DR'
$FileDifferences | Sort-Object -Property InputObject | Format-Table -AutoSize
$FileDifferenceCount = $FileDifferences | Where-Object { $_.SideIndicator -ne '==' } | Measure-Object | Select-Object -ExpandProperty Count
Write-Host '##[endgroup]'

if ($FileDifferenceCount -gt 0) {
    $ErrorMessage = 'Validation failed. {0} differences found' -f $FileDifferenceCount

    if ($ErrorOnFileMismatch) {
        Write-Error ("##[error]{0}" -f $ErrorMessage)
        return
    }
    else {
        Write-Warning ("##[warning]{0}" -f $ErrorMessage)
    }
}
else {
    Write-Host -ForegroundColor Green "No differences found :)"
}
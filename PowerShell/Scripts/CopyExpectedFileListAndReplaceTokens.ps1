param (
    # File containing a list of files with token to replace
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceFile,

    # Folder to place the processed file
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputFolder,

    # Name of the file to create in the output folder
    [string]$OutputFileName = "ExpectedFileList.txt",

    # Value to replace the "__BuildId__" token in the source file
    [string]$BuildId = $null,

    # Additional token values to replace
    [hashtable]$TokenValues = @{}
)

#
# Throw error if the source file does not exist
#
if (-not (Test-Path -Path $SourceFile)) {
    $ErrorMessage = 'Expected file list file "{0}" not found' -f $SourceFile
    Write-Host "[##error]$ErrorMessage"
    throw $ErrorMessage
}

#
# BuildId is optional, but a warning is generated if it isn't provided
#
if (-not [String]::IsNullOrWhiteSpace($BuildId)) {
    Write-Host "Provided BuildId: $BuildId"
    $TokenValues['BuildId'] = $BuildId
}
else {
    Write-Warning "No BuildId provided for token replacement"
}
Write-Host

#
# Import ConfigFunctions module. This must already exist is the PS module path
#
if (-not (Get-Module -Name ConfigFunctions)) {
    Import-Module ConfigFunctions
}

# ---------------------------------------------------------------------------------------------------------------

#
# Get the file object to use its full properties
#
$SourceFileObj = Get-Item -Path $SourceFile

Write-Host "Reading file '$($SourceFileObj.FullName)'"
Write-Host

#
# Read file and replace tokens
#
$ExpectedFileListContents = Get-Content -Path $SourceFileObj.FullName

$ProcessedExpectedFileListContents = ReplaceTokens -Content $ExpectedFileListContents -TokenValues $TokenValues -ExceptionOnMissingValue

#
# Show the expected file contents for easier review in build output
#
Write-Host '##[section]Expected file contents'
$ProcessedExpectedFileListContents | Sort-Object | ForEach-Object { Write-Host $_ }
Write-Host

# ---------------------------------------------------------------------------------------------------------------

#
# Get the output folder object or create it if it doesn't already exist
#
$OutputFolderObj = (Test-Path -Path $OutputFolder) ? (Get-Item -Path $OutputFolder) : (New-Item -Path $OutputFolder -ItemType Directory)

#
# Set the full path of the output "ExpectedFileList.txt" file
#
$OutputFileFullName = Join-Path -Path $OutputFolderObj.FullName -ChildPath $OutputFileName

#
# Save processed contents to file
#
Write-Host "Writing updated contents to '$($OutputFileFullName)'"

# This should overwrite any existing file
$ProcessedExpectedFileListContents | Out-File -FilePath $OutputFileFullName -Encoding utf8NoBOM

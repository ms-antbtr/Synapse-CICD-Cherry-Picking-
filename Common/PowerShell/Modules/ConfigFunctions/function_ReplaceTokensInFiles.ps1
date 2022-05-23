<#
.SYNOPSIS

TBD

.OUTPUTS

TBD
#>
function ReplaceTokensInFiles {
    param (
        # Path to a file or folder containing multiple files to process
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        # Recurse
        [switch]$Recurse,

        # File filter
        [string]$Filter = '*.json',

        # Path to a JSON file containing an object definition. The first-level object property values will be used to replace the tokens in the source files.
        # If '.', each file will be used for its own token values
        [string]$TokenFile = $null,

        # Folder to place output files, which will have the same name as the source file
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputFolder,

        # Hashtable of token values to use in addition to the values from the token file
        [hashtable]$TokenValues = @{},

        # If specified, generate an error if a token is missing a replacement value. The default is to only generate a warning
        [switch]$ExceptionOnMissingValue,

        # By default, JSON files beginning with an underscore, '_', are considered disabled and will be skipped. With this option, these files will also be processed
        [switch]$IncludeCommentedOutFiles,

        <#
        Number of passes through the content to replace tokens. Multiple passes allows for
        tokens values that contain other tokens. This is primarily designed for processing
        environment configuration files where the replacement values are coming from the
        file itself (self-tokens).
        #>
        [int]$Passes = 1
    )

    # Get output folder object or create it if doesn't exist
    $OutputFolderObj = Touch-Path -Path $OutputFolder # -CleanFolder
    Write-Verbose "Output folder : $($OutputFolderObj.FullName)"

    # Get source file or folder object
    $PathObj = Get-Item -Path $Path
    Write-Verbose $PathObj.FullName

    if ($PathObj.PSIsContainer) {
        # Source is a directory, get a list of the JSON files
        if ($IncludeCommentedOutFiles) {
            $JsonFiles = Get-ChildItem -Path $PathObj -File -Filter $Filter -Recurse:$Recurse
        }
        else {
            $JsonFiles = Get-ChildItem -Path $PathObj -File -Filter $Filter -Recurse:$Recurse | Where-Object { -not $_.Name.StartsWith('_') }
        }
    }
    else {
        # Source is a single file
        $JsonFiles = @($PathObj)
    }

    Write-Verbose "Files to process: $($JsonFiles.Count)"

    # Initialize token values
    $TokenFileValues = @{}

    if (-not [string]::IsNullOrEmpty($TokenFile)) {
        if ($TokenFile -ne '.') {
            if (-not (Test-Path -Path $TokenFile)) {
                throw "Token file '$TokenFile' not found"
            }

            $TokenFileValues = Get-Content -Path $TokenFile -Raw | ConvertFrom-Json -AsHashtable
        }
    }

    # Loop through source JSON files
    foreach ($FileObj in $JsonFiles) {
        $FileNameToProcess = $FileObj.BaseName

        Write-Host -ForegroundColor Green "##[section]$($FileNameToProcess)"

        $CurrentFileContent = Get-Content -Path $FileObj.FullName -Raw

        if ($TokenFile -eq '.') {
            $TokenFileValues = Get-Content -Path $FileObj.FullName -Raw | ConvertFrom-Json -AsHashtable
        }

        $ProcessedContent = ReplaceTokens -Content $CurrentFileContent -TokenValues $TokenFileValues -TokenOverrides $TokenValues -Passes $Passes -ExceptionOnMissingValue:$ExceptionOnMissingValue

        if ($Recurse) {
            $CurrentOutputFolderFullName = $FileObj.DirectoryName.Replace($PathObj.FullName, $OutputFolderObj.FullName)

            $CurrentOutputFolderObj = Touch-Path -Path $CurrentOutputFolderFullName

            $CurrentOutputFileName = Join-Path $CurrentOutputFolderObj.FullName -ChildPath $FileObj.Name
        }
        else {
            $CurrentOutputFileName = Join-Path $OutputFolderObj.FullName -ChildPath $FileObj.Name
        }

        Write-Verbose "Writing contents to '$CurrentOutputFileName'"
        
        $ProcessedContent | Out-File -FilePath $CurrentOutputFileName -Encoding utf8NoBOM
    }
}

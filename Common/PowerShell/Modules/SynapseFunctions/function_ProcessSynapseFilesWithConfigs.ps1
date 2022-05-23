<#
.SYNOPSIS

Creates environment-specific Synapse deployment files from git-intergrated Synapse files and environment configuration files
#>
function ProcessSynapseFilesWithConfigs {
    [CmdletBinding()]
    param (
        # Path to the root of the git-integrated Synapse workspace files
        [Parameter(Mandatory = $true)]
        [string]$SynapseJsonRootPath,
    
        # Path to a folder containing JSON files with environment-specific configuration
        [Parameter(Mandatory = $true)]
        [string]$EnvironmentConfigPath,
    
        [Parameter(Mandatory = $true)]
        [string]$OutputFolder,

        [string[]]$OutputFolderSuffixes = @(),

        [string[]]$OnlyObjectTypes = @(),

        [string[]]$ExcludeObjectTypes = @(),

        [switch]$WithReplacementValuesOnly
    )

    # Print out parameter values
    Write-Host
    Write-Host -ForegroundColor White "SynapseJsonRootPath   : $SynapseJsonRootPath"
    Write-Host -ForegroundColor White "EnvironmentConfigPath : $EnvironmentConfigPath"
    Write-Host -ForegroundColor White "OutputFolder          : $OutputFolder"
    Write-Host -ForegroundColor White "OnlyObjectTypes       : $($OnlyObjectTypes -join ', ')"
    Write-Host -ForegroundColor White "ExcludeObjectTypes    : $($ExcludeObjectTypes -join ', ')"
    Write-Host

    # Get directory objects to generate fully-qualified file path and names, regardless of whether the passed parameters are relative or absolute paths
    $EnvironmentConfigPathObj = Get-Item -Path $EnvironmentConfigPath
    $SynapseJsonRootPathObj = Get-Item -Path $SynapseJsonRootPath

    # Get all the JSON files from the Synapse root path that are in subdirectories and meet the object type filters
    $SynapseJsonFiles = Get-ChildItem -Path $SynapseJsonRootPathObj.FullName -Filter '*.json' -File -Recurse |
    Select-Object -Property Name, BaseName, @{n = 'RelativePath'; e = { $_.DirectoryName.Replace($SynapseJsonRootPathObj.FullName, '').TrimStart([System.IO.Path]::DirectorySeparatorChar) } }, FullName | Where-Object { -not [String]::IsNullOrEmpty($_.RelativePath) } |
    Select-Object -Property *, @{n = 'RelativePathParts'; e = { , $_.RelativePath.Split([System.IO.Path]::DirectorySeparatorChar) } } |
    Select-Object -Property @{n = 'TopLevelType'; e = { $_.RelativePathParts[0] } }, * | Where-Object { ($null -eq $OnlyObjectTypes -or $OnlyObjectTypes.Count -eq 0 -or $OnlyObjectTypes -contains $_.TopLevelType) -and ($null -eq $ExcludeObjectTypes -or $ExcludeObjectTypes.Count -eq 0 -or $ExcludeObjectTypes -notcontains $_.TopLevelType) }

    $SynapseJsonFiles | Select-Object -ExcludeProperty FullName | Format-Table -AutoSize

    $ConfigFiles = Get-ChildItem -Path $EnvironmentConfigPathObj.FullName -Filter *.json -File
    $ConfigFiles | Format-Table -Property Name, FullName -AutoSize

    foreach ($FileItem in $SynapseJsonFiles) {
        Write-Host -ForegroundColor Green "Synapse source file : $($FileItem.RelativePath)\$($FileItem.Name)"

        $CurrentSynapseConfigJson = Get-Content -Path $FileItem.FullName -Raw

        foreach ($ConfigFileItem in $ConfigFiles) {
            $ConfigName = $ConfigFileItem.BaseName

            Write-Host -ForegroundColor Cyan "`tEnvironment config : $ConfigName"

            $EnvironmentConfigObj = Get-Content -Path $ConfigFileItem.FullName -Raw | ConvertFrom-Json

            $CurrentOutputDirectoryName = Join-Path -Path $OutputFolder -ChildPath $ConfigFileItem.BaseName -AdditionalChildPath ($OutputFolderSuffixes + $FileItem.RelativePathParts)

            if (-not (Test-Path -Path $CurrentOutputDirectoryName)) {
                New-Item -Path $CurrentOutputDirectoryName -ItemType Directory | Out-Null
            }

            $CurrentOutputFileFullName = Join-Path -Path $CurrentOutputDirectoryName -ChildPath $FileItem.Name

            # Write-Host -ForegroundColor White "Output directory: $CurrentOutputDirectoryName"
            # Write-Host -ForegroundColor White "Output file: $CurrentOutputFileFullName"

            $ReplacementValues = @{}

            if ($null -ne $EnvironmentConfigObj.Synapse) {
                $SynapseConfigObj = $EnvironmentConfigObj | Select-Object -ExpandProperty Synapse

                $ObjectName = '$SynapseConfigObj.''' + ($FileItem.RelativePathParts -join '''.''') + '''.''' + $FileItem.BaseName + ''''

                $Expr = $ObjectName

                Write-Host -ForegroundColor DarkGray "`t`t$Expr"

                $ReplacementValueObj = Invoke-Expression $Expr 

                if ($null -ne $ReplacementValueObj) {
                    $ReplacementValues = $ReplacementValueObj | Convert-ObjectPropertiesToDictionary
                    $ReplacementValues | Format-Table -AutoSize

                    if ($WithReplacementValuesOnly) {
                        $ResultSynapseJson = $CurrentSynapseConfigJson | ApplyJsonReplacementValues -ReplacementValues $ReplacementValues -Verbose:$Verbose
                        $ResultSynapseJson | Out-File -FilePath $CurrentOutputFileFullName -Encoding utf8 -Force
                    }
                }
                else {
                    Write-Host -ForegroundColor Yellow "`t`tNo parameter values found"
                }

                if (-not $WithReplacementValuesOnly) {
                    $ResultSynapseJson = $CurrentSynapseConfigJson | ApplyJsonReplacementValues -ReplacementValues $ReplacementValues -Verbose:$Verbose
                    $ResultSynapseJson | Out-File -FilePath $CurrentOutputFileFullName -Encoding utf8 -Force
                }
            }
            else {
                Write-Host "`t`tNo 'Synapse' element found in environment config"
            }
        }
    }
}
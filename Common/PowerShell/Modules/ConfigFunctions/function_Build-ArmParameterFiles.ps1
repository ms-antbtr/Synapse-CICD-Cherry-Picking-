<#
.SYNOPSIS

Produces ARM template parameter files with enviroment-specific values from JSON config files.

.DESCRIPTION

Takes an ARM template file and a directory containing JSON environment configuration files. Loops through the configuration files and produces an ARM template parameter file using the values from each configuration file.

#>
function Build-ArmParameterFiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$TemplateFile,

        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $true)]
        [string]$OutputFolder,

        [string[]]$OutputFolderSuffixes = @(),

        [string[]]$IncludeChildValues = @()
    )

    BEGIN {
        $OutputFolderObj = Touch-Path -Path $OutputFolder
    }

    PROCESS {
        if (-not (Test-Path -Path $TemplateFile)) {
            Write-Error "Template file '$TemplateFile' not found"
            return
        }

        if (-not (Test-Path -Path $ConfigPath)) {
            Write-Error "Config path '$ConfigPath' not found"
            return
        }

        $TemplateFileObj = Get-Item -Path $TemplateFile
        $TemplateName = $TemplateFileObj.BaseName.Split('.')[0]
        Write-Host "##[section]Template: $TemplateName  ($($TemplateFileObj.FullName))"

        $ResourceTemplateJson = Get-Content -Path $TemplateFileObj.FullName -Raw

        # Get list of JSON config files, excluding any that start with '_'
        $ConfigFiles = Get-ChildItem -Path $ConfigPath -Filter *.json | Where-Object { -not $_.Name.StartsWith('_') }

        # Process each config file in the config path
        foreach ($ConfigFileObj in $ConfigFiles) {
            $ConfigName = $ConfigFileObj.BaseName

            Write-Host ('-' * 100)
            Write-Host "##[section]Config: $ConfigName  ($($ConfigFileObj.FullName))"
            Write-Host

            $ParameterValuesDictionary = Get-Content -Path $ConfigFileObj.FullName -Raw | ConvertFrom-Json -AsHashtable

            if ($IncludeChildValues.Count -gt 0) {
                foreach ($ChildValue in $IncludeChildValues) {
                    if ($ConfigObj.$ChildValue) {
                        $ChildValues = $ConfigObj.$ChildValue

                        foreach ($Key in $ChildValues.Keys) {
                            if ($ParameterValuesDictionary.Keys -contains $Key) {
                                Write-Error "Conflicting value '$Key'"
                            }
                            else {
                                $ParameterValuesDictionary.Add($Key, $ChildValues.$Key) | Out-Null
                            }
                        }
                    }
                }
            }

            $ParameterFileContents = $ResourceTemplateJson | ConvertTo-ArmParameterTemplate -ParameterValues $ParameterValuesDictionary

            $CurrentOutputFolder = Join-Path -Path $OutputFolderObj.FullName -ChildPath $ConfigName -AdditionalChildPath $OutputFolderSuffixes

            $CurrentOutputFolderObj = Touch-Path -Path $CurrentOutputFolder

            $CurrentOutputFileFullName = Join-Path -Path $CurrentOutputFolderObj.FullName -ChildPath ($TemplateName + '.parameters.json')

            Write-Verbose "Writing parameter file '$CurrentOutputFileFullName'"
                
            $ParameterFileContents | Out-File -FilePath $CurrentOutputFileFullName -Encoding utf8NoBOM -NoClobber
        }
    }
}
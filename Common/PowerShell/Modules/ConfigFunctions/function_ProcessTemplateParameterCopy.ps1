function ProcessTemplateParameterCopy {
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ArmTemplatePath,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigPath,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputFolder,

        [string[]]$OutputFolderSuffixes = @(),

        [string[]]$TemplateNameList = @(),

        [string[]]$InstanceNameList = @()
    )

    Write-Host "----- Start: Script parameter values ----- "
    Write-Host "ArmTemplatePath      : $ArmTemplatePath"
    Write-Host "ConfigPath           : $ConfigPath"
    Write-Host "OutputFolder         : $OutputFolder"
    Write-Host "OutputFolderSuffixes : $($OutputFolderSuffixes -join ', ')"
    Write-Host "TemplateNameList     : $($TemplateNameList -join ', ')"
    Write-Host "ItemNameList         : $($ItemNameList -join ', ')"
    Write-Host

    if (-not (Test-Path -Path $ArmTemplatePath)) {
        throw "ARM template path '$ArmTemplatePath' not found!"
    }

    if (-not (Test-Path -Path $ConfigPath)) {
        throw "Config path '$ConfigPath' not found!"
    }

    if (-not (Get-Module -Name ConfigFunctions)) {
        Import-Module -Name ConfigFunctions
    }

    $ArmTemplatePathObj = Get-Item -Path $ArmTemplatePath
    $ConfigPathObj = Get-Item -Path $ConfigPath
    $OutputFolderObj = Touch-Path -Path $OutputFolder

    #
    # Get all the config files to process
    #
    $ConfigFiles = Get-ChildItem -Path $ConfigPathObj.FullName -Filter *.json | Where-Object { -not $_.Name.StartsWith('_') }

    Write-Host '##[section]Config files'
    $ConfigFiles | Format-Table -Property BaseName, Name -AutoSize

    # Loop through environment config files
    foreach ($ConfigFileObj in $ConfigFiles) {
        Write-Host -ForegroundColor DarkGray ('=' * 120)

        $EnvironmentConfigName = $ConfigFileObj.BaseName

        Write-Host -ForegroundColor Green ('##[section]Config: {0} ({1})' -f $ConfigFileObj.BaseName, $ConfigFileObj.FullName)
        Write-Host

        $ConfigValues = Get-Content -Path $ConfigFileObj.FullName -Raw | ConvertFrom-Json -AsHashtable

        if ($ConfigValues.Keys -contains '$TemplateParameterCopy') {
            $CopyTemplates = $ConfigValues['$TemplateParameterCopy']

            Write-Host -ForegroundColor White "Templates to copy: $($CopyTemplates.Keys -join ', ')"

            foreach ($TemplateToReplicate in $CopyTemplates.GetEnumerator()) {
                Write-Host -ForegroundColor DarkGray ('-' * 120)

                $TemplateName = $TemplateToReplicate.Name

                Write-Host -ForegroundColor Cyan "##[section]Template: $TemplateName"
                Write-Host

                if ($TemplateNameList.Count -gt 0 -and -not $TemplateNameList.Contains($TemplateName)) {
                    Write-Host "Template $TemplateName not in filter. Skipping..."
                    continue;
                }

                $ArmTemplateFile = Get-ChildItem -Path $ArmTemplatePathObj.FullName -File -Filter "$($TemplateName).*.json" | Select-Object -First 1

                Write-Host "Template file: $($ArmTemplateFile.Name) ($($ArmTemplateFile.FullName))";

                $ArmTemplateJson = Get-Content -Path $ArmTemplateFile.FullName -Raw

                foreach ($CopyInstance in $TemplateToReplicate.Value.GetEnumerator()) {
                    Write-Host ('.' * 120)
                    $InstanceName = $CopyInstance.Name

                    if ($InstanceNameList.Count -gt 0 -and -not $InstanceNameList.Contains($InstanceName)) {
                        Write-Host "Instance $InstanceName not in filter. Skipping..."
                        continue;
                    }
    
                    Write-Host -ForegroundColor Cyan "##[section]Instance: $InstanceName"
                    Write-Host

                    $ThisOutputFileName = "{0}.{1}.parameters.json" -f $TemplateName, $InstanceName
                    $ThisOutputPath = Join-Path -Path $OutputFolderObj.FullName -ChildPath $EnvironmentConfigName -AdditionalChildPath $OutputFolderSuffixes
                    $ThisOutputPathObj = Touch-Path -Path $ThisOutputPath
                    $ThisOutputFileFullName = Join-Path -Path $ThisOutputPathObj.FullName -ChildPath $ThisOutputFileName

                    Write-Host -ForegroundColor DarkGray ('Output file: {0} ({1})' -f $ThisOutputFileName, $ThisOutputFileFullName)

                    $ThisConfigValues = $ConfigValues.Clone()

                    foreach ($InstanceValue in $CopyInstance.Value.GetEnumerator()) {
                        $Key = $InstanceValue.Name
                        Write-Verbose "Key = $Key"

                        # If the parameter name in the copy config starts with '*', use as-is without prepending the template name
                        # Otherwise, the name is prepended with '<template_name>_'
                        $ParameterName = $Key.StartsWith('*') ? $Key.TrimStart('*') : ($TemplateName + '_' + $Key)
                        Write-Verbose "Parameter name : $ParameterName"

                        $ThisConfigValues[$ParameterName] = $InstanceValue.Value
                    }

                    $ArmTemplateJson | ConvertTo-ArmParameterTemplate -ParameterValues $ThisConfigValues | Out-File -FilePath $ThisOutputFileFullName -Encoding utf8NoBOM
                }
            }
        }
        else {
            Write-Host -ForegroundColor Green "No template copies defined"
        }
    }
}
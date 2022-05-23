<#
.SYNOPSIS

Takes a source ARM template as JSON and produces a matching parameter file as JSON, with provided parameter values used as the template parameter values.

Note: Only parameters with values are included in the resulting template parameter file JSON.

#>
function ConvertTo-ArmParameterTemplate {
    param
    (
        # Raw JSON content from an ARM template parameter file
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceTemplateJson,

        # Hashtable of parameter names and values
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable]$ParameterValues,

        # Don't show pretty output
        [switch]$NoOutput,

        # ARM template schema version
        [string]$TemplateSchemaVersion = '2019-04-01'
    )

    BEGIN {
        <#
        When a file is read using Get-Content, it will either be a single string when read using the "-Raw" switch or string array of the lines of the file if read without the "-Raw" switch.

        When piping the input JSON to this function, the JSON needs to be coalesced into a consistent input, regardless of whether the original input is actually [string] or [string[]].
        #>
        $AllJson = ''

        $ArmTemplateSchemaUrl = 'https://schema.management.azure.com/schemas/{0}/deploymentParameters.json#' -f $TemplateSchemaVersion
    }

    PROCESS {
        <#
        The PROCESS block is run for each input element. When the input is [string[]], each pass will include a single element of input string array, which is then appended to the complete JSON.

        If the input is a single [string], this step is only run once.
        #>
        $AllJson += $ResourceTemplateJson
    }

    END {
        try {
            # Test that the input is valid JSON
            if (-not (Test-Json -Json $AllJson)) {
                Write-Error "ResourceTemplateJson input is not valid JSON!"
                return
            }

            # Convert the raw JSON text of the template into an object
            $ResourceTemplateObj = $AllJson | ConvertFrom-Json -AsHashtable;

            # TODO: Validate that the input is a valid ARM template

            # Print out the parameter values passed to the script
            Write-Host '##[group]Parameters values provided'
            $ParameterValueNameMaxLength = ($ParameterValues.GetEnumerator() | ForEach-Object { $_.Name.Length + $_.Value.GetType().Name.Length } | Measure-Object -Maximum).Maximum # ($ParameterValues.Keys | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
            $ParameterValues.GetEnumerator() | Sort-Object -Property Name | ForEach-Object { Write-Host ("{0} : {1}" -f ("$($_.Name) ($($_.Value.GetType().Name))".PadRight($ParameterValueNameMaxLength + 3)), $_.Value) }
            Write-Host '##[endgroup]'

            # Initialize a hash table to store the values found in the provided parameters
            $OutputParameterValues = @{}

            $DisplayOutputParameterValues = [ordered]@{}

            Write-Host '##[group]Parameter values used for template'

            # Loop through parameter definitions and include the parameter in the output if a value is provided in the application configuration
            foreach ( $ResourceParameter in $ResourceTemplateObj.parameters.GetEnumerator() | Sort-Object Name) {
                $ResourceParameterName = $ResourceParameter.Name
                $ResourceParameterDefinition = $ResourceParameter.Value

                $ResourceParameterType = $ResourceParameterDefinition.type;

                # $Message = "$ResourceParameterName ($ResourceParameterType): "

                if ( $ParameterValues.Keys -contains $ResourceParameterName) {
                    $OutputParameterValues[$ResourceParameterName] = $ParameterValues[$ResourceParameterName];

                    if ($ParameterValues[$ResourceParameterName].GetType().Name.StartsWith('Object') -or $ParameterValues[$ResourceParameterName].GetType().Name -eq 'PSCustomObject') {
                        $DisplayValue = ($ParameterValues[$ResourceParameterName] | ConvertTo-Json)
                    }
                    else {
                        $DisplayValue = ($ParameterValues[$ResourceParameterName])
                    }
                }
                else {
                    $DisplayValue = '<not provided>'
                }

                $DisplayOutputParameterValues["$ResourceParameterName ($ResourceParameterType)"] = $DisplayValue

                # $Message += $DisplayValue
                
                # Write-Host $Message
            }

            $DisplayMaxLength = ($DisplayOutputParameterValues.Keys | Measure-Object -Property Length -Maximum).Maximum
            $DisplayOutputParameterValues.GetEnumerator() | ForEach-Object { Write-Host ('{0} : {1}' -f $_.Name.PadRight($DisplayMaxLength), $_.Value) }

            Write-Host '##[endgroup]'

            $OutputParameterData = [ordered]@{};

            $OutputParameterValues.GetEnumerator() | Sort-Object -Property Name | ForEach-Object { 
                if ($_.Value.GetType().Name -in @('PSCustomObject', 'Hashtable') -and - $null -ne $_.Value['reference']) {
                    $OutputParameterData.Add($_.Name, $_.Value)
                }
                else {
                    $OutputParameterData.Add($_.Name, @{'value' = $_.Value })
                }
            };

            # Set up parameter file output
            $ParameterOutput = New-Object -TypeName psobject;

            $ParameterOutput | Add-Member -MemberType NoteProperty -Name '$schema' -Value $ArmTemplateSchemaUrl;
            $ParameterOutput | Add-Member -MemberType NoteProperty -Name 'contentVersion' -Value (Get-Date -Format 'yyyy.MM.dd.1');
            $ParameterOutput | Add-Member -MemberType NoteProperty -Name 'parameters' -Value $OutputParameterData;

            $ParameterOutput | ConvertTo-Json -Depth 10;
        }
        catch {
            $Error[0];

            throw;
        }
    }
}
<#
.SYNOPSIS

Replaces values within a JSON hierarchy with values from a hash table

.INPUTS

Single string or string array containing valid JSON content

.OUTPUTS

Single string of JSON text with the provided values replaced in the source JSON
#>
function ApplyJsonReplacementValues {
    [CmdletBinding()]
    param (
        # Source JSON text. Must be valid JSON
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [string[]]$SourceJson,

        # Dictionary of replacement values
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]$ReplacementValues,

        # Hierarchy separator in the dictionary key
        [string]$HierarchySeparator = '_'
    )

    BEGIN {
        $AllJson = ''
    }

    PROCESS {
        $AllJson += $SourceJson
    }

    END {
        Write-Debug "Start: ApplyJsonReplacementValues()`r`n"

        Write-Debug "Before:`r`n$AllJson"

        # $SourceJson | ForEach-Object { Write-Debug $_ }

        $ResultObj = $AllJson | ConvertFrom-Json
    
        Write-Verbose ($ReplacementValues.Keys -join ', ')

        if ($ReplacementValues.Count -gt 0) {
            foreach ($Key in $ReplacementValues.Keys) {
                Write-Verbose "`tKey: $Key"

                $NewValue = $ReplacementValues[$Key]
                Write-Debug "`tTarget value: $NewValue"

                $ResultObjectName = '$ResultObj'

                $KeyParts = $Key.Split($HierarchySeparator);
                foreach ($Part in $KeyParts) {
                    $ResultObjectName += ".'$Part'"
                }

                Write-Debug "`tTarget object: $ResultObjectName"

                $CurrentValue = Invoke-Expression $ResultObjectName

                Write-Verbose "`t$CurrentValue => $NewValue"

                $Expr = "$ResultObjectName = `$NewValue"

                Write-Debug "`t$Expr"

                # if ($null -ne $CurrentValue) {
                    Invoke-Expression $Expr
                # }
            }
        }

        $TargetJsonContent = $ResultObj | ConvertTo-Json -Depth 10
        $TargetJsonContent

        Write-Debug "After:`r`n$TargetJsonContent"

        Write-Debug "End: ApplyJsonReplacementValues()`r`n"
    }
}
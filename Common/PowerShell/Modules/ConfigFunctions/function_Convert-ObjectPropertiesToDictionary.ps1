<#
.SYNOPSIS

Return the first level of the input object properties as a dictionary

.INPUTS

Any object

.OUTPUTS

Dictionary of key/value pairs
#>
function Convert-ObjectPropertiesToDictionary {
    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [object]$InputObject,

        # Optional prefix to include on key names. The prefix is only apply on the top-level key when -Recurse is specified
        [string]$KeyPrefix,

        [switch]$Recurse
    )

    BEGIN {}

    PROCESS {
        $ResultDictionary = @{}

        Write-Debug "Input object type: $($InputObject.GetType().Name)"

        $InputObjectType = $InputObject.GetType()

        #
        # If the input is already a hashtable, return it as-is unless -KeyPrefix or -Recurse are specified
        #
        if ($InputObjectType.Name -eq 'Hashtable') {
            Write-Debug 'Processing hashtable'
            foreach ($Item in $InputObject.GetEnumerator()) {
                $TargetKeyName = $Item.Name

                if ($KeyPrefix) {
                    $TargetKeyName = $KeyPrefix + $TargetKeyName
                }

                if ($Recurse) {
                    $TargetValue = $Item.Value | Convert-ObjectPropertiesToDictionary -Recurse
                }
                else {
                    $TargetValue = $Item.Value
                }
                
                $ResultDictionary.Add($TargetKeyName, $TargetValue) | Out-Null
            }

            $ResultDictionary
        }
        #
        # If the input is a custom object, convert the properties to elements in the hash table
        #
        elseif ($InputObjectType.Name -eq 'PSCustomObject') {
            Write-Debug 'PSCustomObject'
            foreach ($PropertyName in ($InputObject | GetObjectPropertyList)) {
                Write-Debug "PSCustomObject: Property name '$PropertyName'"

                $ActualKey = $PropertyName

                if ($KeyPrefix) {
                    $ActualKey = $KeyPrefix + $PropertyName
                }

                $PropertyValue = $InputObject.$PropertyName
                $PropertyValueType = $PropertyValue.GetType()

                if ($Recurse) {
                    Write-Debug "PSCustomObject: Executing recursion."

                    if ($PropertyValueType.Name -eq 'Object[]') {
                        Write-Debug 'PSCustomObject: Processing array'
                        $PropertyValue = @($PropertyValue | ForEach-Object { $_ | Convert-ObjectPropertiesToDictionary -Recurse })
                    }
                    else {
                        $PropertyValue = $PropertyValue | Convert-ObjectPropertiesToDictionary -Recurse
                    }
                }

                $ResultDictionary.Add($ActualKey, $PropertyValue)
            }

            $ResultDictionary
        }
        #
        # If the input object is an array and -Recurse is specified, process each element in the array
        #
        elseif($Recurse -and $InputObjectType.Name -eq 'Object[]') {
            Write-Debug 'Processing array'
            $InputObject | ForEach-Object { $_ | Convert-ObjectPropertiesToDictionary -Recurse }
        }
        #
        # Otherwise, return the input object unchanged
        #
        else {
            Write-Debug 'Returning input value'
            $InputObject
        }
    }

    END {}
}

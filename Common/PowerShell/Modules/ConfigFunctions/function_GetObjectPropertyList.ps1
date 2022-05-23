<#
.SYNOPSIS

Returns a string list of property names of the input object

.INPUTS

Any object

.OUTPUTS

List of the property names of the provided object
#>
function GetObjectPropertyList {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [object]$InputObject
    )

    BEGIN {}

    PROCESS {
        $InputObject | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
    }

    END {}
}
function Deploy-SynapseManagedEndpointFiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SynapseWorkspaceName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SourcePath,

        [switch]$Preview
    )

    if (-not (Test-Path -Path $SourcePath)) {
        throw "Source path '$SourcePath' not found"
    }

    $SourcePathObj = Get-Item -Path $SourcePath

    $SourceFileItems = Get-ChildItem -Path $SourcePathObj.FullName -File -Filter *.json

    foreach ($SourceFileObj in $SourceFileItems) {
        Write-Host "Deploying $($SourceFileObj.Name)"

        $Params = @{
            WorkspaceName  = $SynapseWorkspaceName;
            Name           = $SourceFileObj.BaseName;
            DefinitionFile = $SourceFileObj.FullName;
        }

        if ($Preview) {
            $Params.GetEnumerator() | ForEach-Object { Write-Host ('{0} : {1}' -f $_.Name, $_.Value)}
            Write-Host
        }
        else {
            $NewEndpoint = New-AzSynapseManagedPrivateEndpoint @Params
            $NewEndpoint | Format-List
        }
    }
}
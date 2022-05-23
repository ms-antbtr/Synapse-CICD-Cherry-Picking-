[CmdletBinding(DefaultParameterSetName = 'File')]
param (
    [parameter(Mandatory = $true, ParameterSetName = 'File')]
    [string]$ConfigFile,

    [parameter(Mandatory = $true, ParameterSetName = 'Pipeline', ValueFromPipeline = $true)]
    [string[]]$ConfigJson,

    [string]$SchemaFilePath,

    [switch]$Execute
)

begin {
    $AllJson = ''
}

process {
    $AllJson += $ConfigJson
}

end {
    if (-not [string]::IsNullOrEmpty($AllJson)) {
        Write-Host -ForegroundColor magenta "Using JSON from pipeline"

        $ConfigJson = $AllJson
    }
    elseif (-not [string]::IsNullOrEmpty($ConfigFile)) {
        Write-Host -ForegroundColor Magenta "Using config file '$ConfigFile'"

        if (-not (Test-Path -Path $ConfigFile)) {
            Write-Error "Config file not found!"
        }

        $ConfigJson = Get-Content -Path $ConfigFile -Raw 
    }
    else {
        Write-Error 'Invalid input type'
        return
    }

    try {
        if (-not [string]::IsNullOrEmpty($SchemaFilePath)) {
            $JsonErrors = $ConfigJson | Test-Json -SchemaFile $SchemaFilePath
        }
        else {
            $JsonErrors = $ConfigJson | Test-Json
        }
    }
    catch {
        Write-Error "Config JSON is not valid"

        $JsonErrors | Format-Table

        return
    }

    $ConfigObj = $ConfigJson | ConvertFrom-Json

    $SynapseWorkspaceName = $ConfigObj.SynapseWorkspace_Name

    Write-Host -ForegroundColor Green "Synapse workspace: $SynapseWorkspaceName"

    if (-not $ConfigObj.Synapse.ManagedPrivateEndpoint) {
        Write-Warning "No managed endpoints defined in the config file"
        return
    }

    $ConfigManagedPrivateEndpoints = $ConfigObj.Synapse.ManagedPrivateEndpoint
    $ActualManagedPrivateEndpoints = az synapse managed-private-endpoints list --workspace-name $SynapseWorkspaceName | ConvertFrom-Json | Select-Object -ExpandProperty name | Sort-Object

    # $ActualManagedPrivateEndpoints

    $AzAccount = az account show | ConvertFrom-Json
    $CurrentSubscriptionId = $AzAccount.id

    $DefaultResourceGroupName = $ConfigObj.ResourceGroup_Name

    foreach ($EndpointDefinition in $ConfigManagedPrivateEndpoints) {
        $EndpointName = $EndpointDefinition.EndpointName;

        Write-Host -ForegroundColor Cyan "Configuring '$EndpointName'"

        if ($ActualManagedPrivateEndpoints -contains $EndpointName) {
            Write-Host -ForegroundColor White "`tEndpoint already exists"
            continue
        }

        Write-Host -ForegroundColor Magenta "`tCreating endpoint..."

        $TargetSubscriptionId = $CurrentSubscriptionId

        if (-not [string]::IsNullOrEmpty($EndpointDefinition.TargetSubscriptionId)) {
            $TargetSubscriptionId = $EndpointDefinition.TargetSubscriptionId
        }

        $TargetResourceGroupName = $DefaultResourceGroupName

        if (-not [string]::IsNullOrEmpty($EndpointDefinition.TargetResourceGroupName)) {
            $TargetResourceGroupName = $EndpointDefinition.TargetResourceGroupName
        }
    
        $ResourceId = '/subscriptions/{0}/resourceGroups/{1}/providers/{2}/{3}' -f $TargetSubscriptionId, $TargetResourceGroupName, $EndpointDefinition.TargetResourceType, $EndpointDefinition.TargetResourceName

        Write-Host -ForegroundColor DarkGray "`t`t$ResourceId"

        $AzParams = @(
            'synapse', 'managed-private-endpoints', 'create',
            '--workspace-name', $SynapseWorkspaceName,
            '--pe-name', $EndpointDefinition.EndpointName,
            '--resource-id', $ResourceId,
            '--group-Id', $EndpointDefinition.GroupId,
            '--subscription', $TargetSubscriptionId
        )
        
        $AzParams | ForEach-Object { Write-Host -ForegroundColor Gray "`t`t$($_)"}

        if ($Execute) {
            az $AzParams
        }
    }
}
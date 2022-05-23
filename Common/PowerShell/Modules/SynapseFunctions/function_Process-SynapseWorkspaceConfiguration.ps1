function Process-SynapseWorkspaceConfiguration {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WorkspaceName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WorkspaceLocation,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WorkspaceResourceGroupName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WorkspaceSubscriptionId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable]$WorkspaceConfiguration,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputFolder,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SynapseSourcePath
    )

    if (-not (Get-Module -Name ConfigFunctions)) {
        Import-Module -Name ConfigFunctions
    }

    Write-Host -ForegroundColor Cyan "Workspace: $WorkspaceName"

    $WorkspaceOutputFolderName = Join-Path -Path $OutputFolder -ChildPath $WorkspaceName
    $WorkspaceOutputFolderObj = Touch-Path -Path $WorkspaceOutputFolderName
    $WorkspaceOutputFolderFullName = $WorkspaceOutputFolderObj.FullName

    Write-Host -ForegroundColor DarkGray "Output path: $WorkspaceOutputFolderFullName"
    Write-Host

    #
    # RoleAssignments
    #
    if ($WorkspaceConfiguration.Keys -contains 'RoleAssignments') {
        Write-Host -ForegroundColor Magenta "Processing workspace roles"

        foreach ($RoleAssignment in $WorkspaceConfiguration.RoleAssignments) {
            Write-Host -ForegroundColor White "`t$($RoleAssignment.Name) - $($RoleAssignment.RoleDefinitionName)"
        }

        $CurrentOutputFileName = 'RoleAssignments.json'
        $CurrentOutputFileFullName = Join-Path -Path $WorkspaceOutputFolderFullName -ChildPath $CurrentOutputFileName

        $WorkspaceConfiguration.RoleAssignments | ConvertTo-Json -Depth 2 -AsArray | Out-File -FilePath $CurrentOutputFileFullName -Encoding utf8NoBOM
    }
    else {
        Write-Host -ForegroundColor Magenta "No workspace roles defined"
    }

    #
    # ManagedPrivateEndpoints
    #
    if ($WorkspaceConfiguration.Keys -contains 'ManagedPrivateEndpoints') {
        Write-Host -ForegroundColor Magenta "Processing managed private endpoints"

        foreach ($Endpoint in $WorkspaceConfiguration.ManagedPrivateEndpoints.GetEnumerator()) {
            $EndpointName = $Endpoint.Name
            $EndpointConfig = $Endpoint.Value

            Write-Host -ForegroundColor White "`t$EndpointName"

            $ThisEndpointSubscriptionId = $EndpointConfig.TargetSubscriptionId ?? $WorkspaceSubscriptionId
            $ThisEndpointResourceGroupName = $EndpointConfig.TargetResourceGroupName ?? $WorkspaceResourceGroupName

            $ThisEndpointFqdn = $null

            switch ($EndpointConfig.TargetResourceType) {
                'Microsoft.DocumentDb/databaseAccounts' {
                    $ThisEndpointFqdn = '{0}-{1}.documents.azure.com' -f $EndpointConfig.TargetResourceName, $WorkspaceLocation
                }
                'Microsoft.Sql/servers' {
                    $ThisEndpointFqdn = $EndpointConfig.TargetResourceName + '.database.windows.net'
                }
                'Microsoft.EventHub/namespaces' {
                    $ThisEndpointFqdn = $EndpointConfig.TargetResourceName + '.servicebus.windows.net'
                }
                'Microsoft.KeyVault/vaults' {
                    $ThisEndpointFqdn = $EndpointConfig.TargetResourceName + '.vaultcore.azure.net'
                }
                'Microsoft.Storage/storageAccounts' {
                    switch ($EndpointConfig.GroupId) {
                        'dfs' {
                            $ThisEndpointFqdn = $EndpointConfig.TargetResourceName + '.dfs.core.windows.net'
                        }
                        'blob' {
                            $ThisEndpointFqdn = $EndpointConfig.TargetResourceName + '.blob.core.windows.net'
                        }
                    }
                }
            }

            $EndpointConfigResult = [ordered]@{
                name       = $EndpointName;
                properties = [ordered]@{
                    privateLinkResourceId = "/subscriptions/{0}/resourceGroups/{1}/providers/{2}/{3}" -f $ThisEndpointSubscriptionId, $ThisEndpointResourceGroupName, $EndpointConfig.TargetResourceType, $EndpointConfig.TargetResourceName;
                    groupId               = $EndpointConfig.GroupId;
                    fqdns                 = @()
                }
            }

            if (-not [String]::IsNullOrEmpty($ThisEndpointFqdn)) {
                $EndpointConfigResult.properties.fqdns += $ThisEndpointFqdn.ToLower()
            }

            $ThisOutputFileName = $EndpointName + '.json'
            $ThisOutputFolderName = Join-Path -Path $WorkspaceOutputFolderFullName -ChildPath ManagedPrivateEndpoints
            $ThisOutputFolderObj = Touch-Path -Path $ThisOutputFolderName
            $ThisOutputFileFullName = Join-Path $ThisOutputFolderObj.FullName -ChildPath $ThisOutputFileName

            $EndpointConfigResult | ConvertTo-Json | Out-File -FilePath $ThisOutputFileFullName -Encoding utf8NoBOM
        }
    }
    else {
        Write-Host -ForegroundColor Magenta "No managed private endpoints defined"
    }

    if ($WorkspaceConfiguration.Keys -contains 'LinkedServices') {
        Write-Host -ForegroundColor Magenta "Processing linked services"

        foreach ($LinkedService in $WorkspaceConfiguration.LinkedServices.GetEnumerator()) {
            $LinkedServiceName = $LinkedService.Name
            $LinkedServiceConfig = $LinkedService.Value

            Write-Host -ForegroundColor White "`t$LinkedServiceName"

            $LinkedServiceDefinitionFileName = Join-Path -Path $SynapseSourcePath -ChildPath linkedService -AdditionalChildPath ($LinkedServiceName + '.json')

            $CurrentOutputFolderName = Join-Path -Path $WorkspaceOutputFolderFullName -ChildPath LinkedServices
            $CurrentOutputFolderObj = Touch-Path -Path $CurrentOutputFolderName

            if (Test-Path -Path $LinkedServiceDefinitionFileName) {
                $LinkedServiceDefinitionJson = Get-Content -Path $LinkedServiceDefinitionFileName -Raw

                $CurrentOutputFileName = $LinkedServiceName + '.json'
                $CurrentOutputFileFullName = Join-Path -Path $CurrentOutputFolderObj.FullName -ChildPath $CurrentOutputFileName

                $ResultSynapseJson = $LinkedServiceDefinitionJson | ApplyJsonReplacementValues -ReplacementValues $LinkedServiceConfig
                $ResultSynapseJson | Out-File -FilePath $CurrentOutputFileFullName -Encoding utf8 -Force
            }
            else {
                Write-Warning -Message "Linked service definition file '$LinkedServiceDefinitionFileName' not found. Cannot process configuration."
            }
        }
    }
    else {
        Write-Host -ForegroundColor Magenta "No linked services defined"
    }

    #
    # BigDataPool_SparkConfigs
    #
    if ($WorkspaceConfiguration.Keys -contains 'BigDataPool_SparkConfigs') {
        Write-Host -ForegroundColor Magenta "Processing big data pool Spark configs"

        $CurrentOutputFolderName = Join-Path -Path $WorkspaceOutputFolderFullName -ChildPath BigDataPool_SparkConfigs
        $CurrentOutputFolderObj = Touch-Path -Path $CurrentOutputFolderName

        foreach ($Pool in $WorkspaceConfiguration.BigDataPool_SparkConfigs.GetEnumerator()) {
            $PoolName = $Pool.Name
            $PoolConfig = $Pool.Value

            Write-Host -ForegroundColor White "`t$PoolName"

            $CurrentOutputFileName = '{0}.txt' -f $PoolName
            $CurrentOutputFileFullName = Join-Path -Path $CurrentOutputFolderObj.FullName -ChildPath $CurrentOutputFileName

            $SparkConfig = $PoolConfig -join "`r`n"
            $SparkConfig | Out-File -FilePath $CurrentOutputFileFullName -Encoding utf8NoBOM
        }
    }
    else {
        Write-Host -ForegroundColor Magenta "No big data pool Spark configs defined"
    }
}
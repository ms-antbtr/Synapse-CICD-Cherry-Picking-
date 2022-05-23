function Build-SynapseManagedEndpointFiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigFile,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputFolder
    )

    if (-not (Test-Path -Path $ConfigFile)) {
        throw "Config file '$ConfigFile' not found"
    }

    $ConfigFileObj = Get-Item -Path $ConfigFile

    $ConfigObj = Get-Content -Path $ConfigFileObj.FullName -Raw | ConvertFrom-Json

    $EnvironmentName = $ConfigFileObj.BaseName
    $EnvironmentSubscriptionId = $ConfigObj.SubscriptionId
    $EnvironmentResourceGroupName = $ConfigObj.ResourceGroup_Name
    $EnvironmentLocation = $ConfigObj.Location

    Write-Host -ForegroundColor Cyan "Environment         : $EnvironmentName"
    Write-Host -ForegroundColor Cyan "Subscription id     : $EnvironmentSubscriptionId"
    Write-Host -ForegroundColor Cyan "Resource group name : $EnvironmentResourceGroupName"

    $OutputFolderObj = Touch-Path -Path $OutputFolder
    Write-Host -ForegroundColor Cyan "Output folder       : $($OutputFolderObj.FullName)"

    $EndpointConfig = $ConfigObj.Synapse.ManagedPrivateEndpoint

    foreach ($Endpoint in $EndpointConfig) {
        Write-Host -ForegroundColor Green $Endpoint.EndpointName

        $ThisEndpointSubscriptionId = $Endpoint.TargetSubscriptionId ?? $EnvironmentSubscriptionId
        $ThisEndpointResourceGroupName = $Endpoint.TargetResourceGroupName ?? $EnvironmentResourceGroupName

        $ThisEndpointFqdn = $null

        switch ($Endpoint.TargetResourceType) {
            'Microsoft.DocumentDb/databaseAccounts' {
                #$CosmosDbAccount = Get-AzCosmosDBAccount -ResourceGroupName $ThisEndpointResourceGroupName -Name $Endpoint.TargetResourceName
                #$CosmosDbUri = New-Object -TypeName System.Uri -ArgumentList $CosmosDbAccount.DocumentEndpoint
                #$ThisEndpointFqdn = $CosmosDbUri.Host

                $ThisEndpointFqdn = '{0}-{1}.documents.azure.com' -f $Endpoint.TargetResourceName, $EnvironmentLocation
            }

            'Microsoft.Sql/servers' {
                # $ThisEndpointFqdn = Get-AzSqlServer -ServerName mercurysqlint | Select-Object -ExpandProperty FullyQualifiedDomainName

                $ThisEndpointFqdn = $Endpoint.TargetResourceName + '.database.windows.net'
            }

            'Microsoft.EventHub/namespaces' {
                #$EventHubNamespace = Get-AzEventHubNamespace -ResourceGroupName $ThisEndpointResourceGroupName -Namespace $Endpoint.TargetResourceName
                #$EventHubNamespaceUrl = New-Object -TypeName System.Uri -ArgumentList $EventHubNamespace.ServiceBusEndpoint
                #$ThisEndpointFqdn = $EventHubNamespaceUrl.Host

                $ThisEndpointFqdn = $Endpoint.TargetResourceName + '.servicebus.windows.net'
            }

            'Microsoft.KeyVault/vaults' {
                #$KeyVault = Get-AzKeyVault -ResourceGroupName $ThisEndpointResourceGroupName -VaultName $Endpoint.TargetResourceName
                #$KeyVaultUri = New-Object -TypeName System.Uri -ArgumentList $KeyVault.VaultUri
                #$ThisEndpointFqdn = $KeyVaultUri.Host

                $ThisEndpointFqdn = $Endpoint.TargetResourceName + '.vaultcore.azure.net'
            }

            'Microsoft.Storage/storageAccounts' {
                #$StorageAccount = Get-AzStorageAccount -ResourceGroupName $ThisEndpointResourceGroupName -Name $Endpoint.TargetResourceName

                switch ($Endpoint.GroupId) {
                    'dfs' {
                        # $StorageAccountUri = New-Object -TypeName System.Uri -ArgumentList $StorageAccount.PrimaryEndpoints.Dfs
                        # $ThisEndpointFqdn = $StorageAccountUri.Host
                        $ThisEndpointFqdn = $Endpoint.TargetResourceName + '.dfs.core.windows.net'
                    }

                    'blob' {
                        #$StorageAccountUri = New-Object -TypeName System.Uri -ArgumentList $StorageAccount.PrimaryEndpoints.Blob
                        #$ThisEndpointFqdn = $StorageAccountUri.Host
                        $ThisEndpointFqdn = $Endpoint.TargetResourceName + '.blob.core.windows.net'
                    }
                }
            }
        }

        $EndpointConfigResult = [ordered]@{
            name       = $Endpoint.EndpointName;
            properties = [ordered]@{
                privateLinkResourceId = "/subscriptions/{0}/resourceGroups/{1}/providers/{2}/{3}" -f $ThisEndpointSubscriptionId, $ThisEndpointResourceGroupName, $Endpoint.TargetResourceType, $Endpoint.TargetResourceName;
                groupId               = $Endpoint.GroupId;
                fqdns                 = @()
            }
        }

        if (-not [String]::IsNullOrEmpty($ThisEndpointFqdn)) {
            $EndpointConfigResult.properties.fqdns += $ThisEndpointFqdn.ToLower()
        }

        $ThisOutputFileName = $Endpoint.EndpointName + '.json'
        $ThisOutputFileFullName = Join-Path $OutputFolderObj.FullName -ChildPath $ThisOutputFileName

        #$EndpointConfigResult | ConvertTo-Json

        Write-Host -ForegroundColor Magenta "Writing endpoint config to '$ThisOutputFileFullName'"
        $EndpointConfigResult | ConvertTo-Json | Out-File -FilePath $ThisOutputFileFullName -Encoding utf8NoBOM
    }

}
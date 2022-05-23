param (
    [parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [parameter(Mandatory = $true)]
    [string]$KeyVaultName,

    [parameter(Mandatory = $true)]
    [ValidateSet('Add', 'Remove')]
    [string]$Action,

    [parameter(ParameterSetName = 'UseCurrentIp')]
    [switch]$UseCurrentIp,

    [parameter(Mandatory = $true, ParameterSetName = 'IpAddress')]
    [string]$IPAddress,

    [Alias('Delay')]
    [int]$DelayInSeconds = 30
)

$KeyVault = Get-AzKeyVault -ResourceGroupName $ResourceGroupName -VaultName $KeyVaultName

Write-Host "Key Vault details"

$KeyVault | Format-List -Property VaultName, ResourceGroupName, Location

Write-Host "Current network rule configuration"

$KeyVault.NetworkAclsText

if ($KeyVault.NetworkAcls.DefaultAction -eq "Deny") {
    Write-Host "Key Vault firewall is enabled"

    if ($UseCurrentIp) {
        $WebResponse = Invoke-WebRequest -Uri https://api.ipify.org/?format=json -UseBasicParsing
        $IPAddress = $WebResponse.Content | ConvertFrom-Json | Select-Object -ExpandProperty ip

        Write-Host "Current public IP address: $IPAddress"
    }
    else {
        Write-Host "IP address : $IPAddress"
    }

    $IPAddressRange = '{0}/32' -f $IPAddress

    $RuleExists = ($KeyVault.NetworkAcls.IpAddressRanges | Where-Object { $_ -eq $IPAddressRange } | Measure-Object | Select-Object -ExpandProperty Count) -gt 0

    if ($Action -eq 'Add') {
        if ($RuleExists) {
            Write-Host "IP rule already exists"
        }
        else {
            Write-Host "Adding new IP rule"
        
            Add-AzKeyVaultNetworkRule -VaultName $KeyVault.VaultName -ResourceGroupName $KeyVault.ResourceGroupName -IpAddressRange $IPAddressRange

            Write-Host "Rule added"

            if ($DelayInSeconds -gt 0) {
                Write-Host -ForegroundColor Magenta "Pausing for $DelayInSeconds seconds..."
                Start-Sleep -Seconds $DelayInSeconds
            }
        }
    }
    elseif ($Action -eq 'Remove') {
        if ($RuleExists) {
            Write-Host "Removing IP rule"

            $KeyVault.NetworkAcls.IpAddressRanges | Where-Object { $_ -eq $IPAddressRange } | ForEach-Object { Remove-AzKeyVaultNetworkRule -VaultName $KeyVault.VaultName -ResourceGroupName $KeyVault.ResourceGroupName -IpAddressRange $_ }

            Write-Host "Rule removed"
        }
        else {
            Write-Host "No IP rule to remove"
        }
    }
    else {
        Write-Error "Invalid action '$Action'"
        return
    }

    Write-Host "Resulting network rule configuration"

    $KeyVault = Get-AzKeyVault -VaultName $KeyVaultName

    $KeyVault.NetworkAclsText
}
else {
    Write-Host "Storage account firewall is disabled"
}
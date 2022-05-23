param (
    # Resource group containing the target storage account
    [parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    # Storage account name
    [parameter(Mandatory = $true)]
    [string]$StorageAccountName,

    # Action to take - add or remove firewall rule
    [parameter(Mandatory = $true)]
    [ValidateSet('Add', 'Remove')]
    [string]$Action,

    # Option 1 - Detect the current public IP of the source
    [parameter(ParameterSetName = 'UseCurrentIp')]
    [switch]$UseCurrentIp,

    # Option 2 - Use specific IP address
    [parameter(Mandatory = $true, ParameterSetName = 'IpAddress')]
    [string]$IPAddress,

    # Delay after adding a firewall rule to allow time for the rule to take effect before continuing
    [Alias('Delay')]
    [int]$DelayInSeconds = 45
)

$NetworkRuleSet = Get-AzStorageAccountNetworkRuleSet -ResourceGroupName $ResourceGroupName -Name $StorageAccountName

if ($NetworkRuleSet.DefaultAction -eq "Deny") {
    Write-Host "Storage account firewall is enabled"

    if ($UseCurrentIp) {
        $WebResponse = Invoke-WebRequest -Uri https://api.ipify.org/?format=json -UseBasicParsing
        $IPAddress = $WebResponse.Content | ConvertFrom-Json | Select-Object -ExpandProperty ip

        Write-Host "Current public IP address: $IPAddress"
    }
    else {
        Write-Host "IP address : $IPAddress"
    }

    $ExistingIPRule = $NetworkRuleSet.IpRules | Where-Object { $_.Action -eq 'Allow' -and $_.IPAddressOrRange -eq $IPAddress }

    if ($Action -eq 'Add') {
        if ($ExistingIPRule) {
            Write-Host "IP rule already exists"

            $NetworkRuleSet.IpRules | Format-Table -AutoSize
        }
        else {
            Write-Host "Adding new IP rule"
        
            Add-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -IPAddressOrRange $IPAddress | Format-Table -AutoSize

            Write-Host "Rule added"

            if ($DelayInSeconds -gt 0) {
                Write-Host -ForegroundColor Magenta "Pausing for $DelayInSeconds seconds..."
                Start-Sleep -Seconds $DelayInSeconds
            }
        }
    }
    elseif ($Action -eq 'Remove') {
        if ($ExistingIPRule) {
            Write-Host "Removing IP rule"

            Remove-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -IPAddressOrRange $IPAddress | Format-Table -AutoSize

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
}
else {
    Write-Host "Storage account firewall is disabled"
}
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TemplateFile,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TemplateParameterFile,

    [switch]$Preview
)

Write-Host -ForegroundColor Magenta "----- Script parameters -----"
Write-Host "Resource group name     : $ResourceGroupName"
Write-Host "Template file           : $TemplateFile"
Write-Host "Template parameter file : $TemplateParameterFile"
Write-Host "Preview                 : $Preview"
Write-Host ""

if (-not (Get-Module -Name ConfigFunctions)) {
    Import-Module -Name ConfigFunctions
}

#
# Get parameter values from ARM template parameter file
#
Write-Host -ForegroundColor Magenta "----- Template parameter file values -----"

$TemplateParameters = (Get-Content -Path $TemplateParameterFile -Raw | ConvertFrom-Json -AsHashtable).Item('parameters')
$TemplateParameters | Format-List

$TemplateParameterValues = @{}
$TemplateParameters.GetEnumerator() | ForEach-Object { $TemplateParameterValues.Add($_.Name, $_.Value.value) }
$TemplateParameterValues | Format-List

<#
If this is a new Key Vault, the values from the parameter file will be used as-is.

If this is an existing Key Vault, the current access policies are used for the "KeyVault_AccessPolicies" parameter
and the values from the parameter file are used for the "KeyVault_AdditionalAccessPolicies" parameter. The existing 
allowed IP addresses are also merged with the values from the parameter file.
#>

$DeploymentParameters = @{
    ResourceGroupName     = $ResourceGroupName;
    TemplateFile          = $TemplateFile;
    TemplateParameterFile = $TemplateParameterFile;
    KeyVault_CreateMode   = 'default';
}

$KeyVaultName = $TemplateParameterValues.KeyVault_Name

$KeyVault = Get-AzKeyVault -VaultName $KeyVaultName

if ($KeyVault) {
    Write-Host "Key vault $KeyVaultName exists"

    #
    # Copy the parameter file access policies to the "KeyVault_AdditionalAccessPolicies" parameter
    #
    if ($TemplateParameterValues.ContainsKey('KeyVault_AccessPolicies') -and $TemplateParameterValues.Item('KeyVault_AccessPolicies').Count) {
        $DeploymentParameters['KeyVault_AdditionalAccessPolicies'] = $TemplateParameterValues.Item('KeyVault_AccessPolicies')
    }

    #
    # Extract the current access policies for the "KeyVault_AccessPolicies" parameter
    #
    $ExistingAccessPolicies = New-Object -TypeName System.Collections.ArrayList

    $KeyVault.AccessPolicies | ForEach-Object {
        $Result = @{
            applicationId = $_.ApplicationId;
            objectId      = $_.ObjectId;
            tenantId      = $_.TenantId;
            permissions   = @{
                keys         = $_.PermissionsToKeys;
                secrets      = $_.PermissionsToSecrets;
                certificates = $_.PermissionsToCertificates;
                storage      = $_.PermissionsToStorage;
            }
        }

        $ExistingAccessPolicies.Add($Result) | Out-Null;
    }

    Write-Host -ForegroundColor Magenta '----- Existing Key Vault access policies -----'
    
    $ExistingAccessPolicies | ForEach-Object { $_ | Format-Table -AutoSize }

    if ($ExistingAccessPolicies.Count -gt 0) {
        $DeploymentParameters['KeyVault_AccessPolicies'] = $ExistingAccessPolicies.ToArray()
    }

    $AllowedIpAddresses = New-Object -TypeName System.Collections.ArrayList

    if ($TemplateParameterValues.ContainsKey('KeyVault_AllowedIPAddresses') -and $TemplateParameterValues['KeyVault_AllowedIPAddresses'].Count) {
        $TemplateParameterValues.KeyVault_AllowedIPAddresses | ForEach-Object { 
            $Item = @{
                Name  = $_.Name;
                Value = $_.Value
            }

            Write-Verbose $Item; 

            $AllowedIpAddresses.Add($Item) | Out-Null
        }
    }

    $AllowedIpAddresses | ForEach-Object { $_ | Format-Table -AutoSize }

    #
    # Add the existing allowed IP ranges to the list
    #
    Write-Host -ForegroundColor Magenta '----- Existing Key Vault IP rules -----'

    Write-Host ($KeyVault.NetworkAcls | ConvertTo-Json -Depth 10)

    Write-Verbose "KeyVault.NetworkAcls.IpAddressRanges.Count = $($KeyVault.NetworkAcls.IpAddressRanges.Count)"

    if ($KeyVault.NetworkAcls.IpAddressRanges.Count) {
        foreach ($IpRange in $KeyVault.NetworkAcls.IpAddressRanges) {
            Write-Host "Existing range: $IpRange"

            if (-not ($AllowedIpAddresses | Where-Object { $_.Value -eq $IpRange })) {
                Write-Warning "Existing IP range $IpRange not in config"
                $AllowedIpAddresses.Add((@{Name = 'Existing IP range'; Value = $IpRange }))
            }
            else {
                Write-Host "- Range already exists in target"
            }
        }
    }

    Write-Host ($AllowedIpAddresses | ConvertTo-Json -Depth 10)

    if ($AllowedIpAddresses.Count -gt 0) {
        $DeploymentParameters['KeyVault_AllowedIPAddresses'] = $AllowedIpAddresses.ToArray();
    }
}
else {
    Write-Host "Key Vault $KeyVaultName does not exist"
}

Write-Host -ForegroundColor Magenta "---- Deployment parameters ----"
Write-Host -ForegroundColor Cyan ($DeploymentParameters | ConvertTo-Json -Depth 10)

if ($Preview) {
    Write-Warning "PREVIEW mode. Skipping ARM template deployment"
}

Write-Host "Testing deployment..."
Test-AzResourceGroupDeployment @DeploymentParameters

Write-Host "Running deployment..."
$DeploymentResult = New-AzResourceGroupDeployment @DeploymentParameters -WhatIf:$Preview

$DeploymentResult

<#
{
        "applicationId": "string",
        "objectId": "string",
        "permissions": {
          "certificates": [ "string" ],
          "keys": [ "string" ],
          "secrets": [ "string" ],
          "storage": [ "string" ]
        },
        "tenantId": "string"
      }
#>
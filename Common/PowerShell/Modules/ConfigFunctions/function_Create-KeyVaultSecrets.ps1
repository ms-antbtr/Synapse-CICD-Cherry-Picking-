function Create-KeyVaultSecrets {
    param (
        [parameter(Mandatory = $true)]
        [string]$KeyVaultName,


        [object[]]$SecretConfig = @()
    )

    Write-Host
    Write-Host "Key vault: $KeyVaultName"

    # $KeyVault = Get-AzKeyVault -VaultName $KeyVaultName

    # $KeyVault

    $SecretConfig | Format-List *

    $ExistingSecrets = Get-AzKeyVaultSecret -VaultName $KeyVaultName

    $ExistingSecretNames = $ExistingSecrets | Select-Object -ExpandProperty Name
    
    foreach ($Item in ($SecretConfig | Where-Object { $_.Name -notin $ExistingSecretNames })) {
        $SecretName = $Item.Name
        Write-Host -ForegroundColor Cyan "Create secret '$SecretName'"

        $SecretValue = ' '

        if ($Item.InitialValueType -eq "NewGuid") {
            $SecretValue = [Guid]::NewGuid().ToString()
        }
        elseif (-not [string]::IsNullOrEmpty($Item.InitialValue)) {
            $SecretValue = $Item.InitialValue
        }

        $SetSecret = Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -SecretValue (ConvertTo-SecureString -String $SecretValue -AsPlainText -Force)

        $SetSecret
    }

}
<#
$ConfigFile = 'C:\Repos\FIN-STR-PLR-MercV2-Core\_\Infrastructure\Config\DEMO1-WestUS2.json'
$Config = get-content -Path $ConfigFile -Raw | ConvertFrom-Json

Create-KeyVaultSecrets -KeyVaultName mercuryv2-demo1-wus2-kv -SecretConfig $Config.KeyVault_SecretDefinitions
#>
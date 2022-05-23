param
(
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$KeyVaultName,

    [parameter(Mandatory = $true, ParameterSetName = "FromFile")]
    [ValidateNotNullOrEmpty()]
    [string]$SecretConfigFile,

    [parameter(Mandatory = $true, ParameterSetName = "FromConfig", ValueFromPipeline = $true)]
    [object[]]$SecretConfig
)

Write-Host -ForegroundColor Gray "Key vault   : $KeyVaultName";

if ($SecretConfigFile) {
    Write-Host -ForegroundColor Gray "Config file : $SecretConfigFile";

    if ( -not (Test-Path -Path $SecretConfigFile) ) {
        Write-Error "Config file '$SecretConfigFile' not found";
    }

    $SecretConfig = Get-Content -Path $SecretConfigFile | ConvertFrom-Json;
}

if (-not $SecretConfig) {
    throw "Missing secret configuration"
}

Write-Verbose ($SecretConfig | ConvertTo-Json -Depth 3)

$AzContext = Get-AzContext;

Write-Host -ForegroundColor Yellow "Adding access policy";

Set-AzKeyVaultAccessPolicy -VaultName $KeyVaultName -ServicePrincipalName $AzContext.Account.Id -PermissionsToSecrets @('list', 'get', 'set');

# $SecretConfig

# Get-AzContext

$ExistingSecretNames = Get-AzKeyVaultSecret -VaultName $KeyVaultName | Select-Object -ExpandProperty Name;

Write-Host "Existing secrets : $($ExistingSecretNames -join ', ')";

foreach ( $ConfigItem in $SecretConfig.Secrets ) {
    Write-Host -ForegroundColor Green $ConfigItem.Name;

    if ( $ExistingSecretNames -notcontains $ConfigItem.Name ) {
        Write-Host -ForegroundColor Yellow 'Create new secret';

        $SecretValue = $null;
        $ContentType = $null;

        if ( $ConfigItem.ContentType ) {
            $ContentType = $ConfigItem.ContentType;
        }

        if ( -not $ConfigItem.Default ) {
            Write-Warning "Missing default configuration"
            continue
        }

        if ($ConfigItem.Default.Value) {
            $SecretValue = $ConfigItem.Default.Value;

            if ( -not $ContentType ) {
                $ContentType = 'Initialized from secret config file';
            }
        }
        elseif ( $ConfigItem.Default.ValueType -eq 'EmptyString' ) {
            $SecretValue = ' ';

            if ( -not $ContentType ) {
                $ContentType = 'To be set - initialized to empty string';
            }
        }
        elseif ( $ConfigItem.Default.ValueType -eq 'NewGUID' ) {
            $SecretValue = [GUID]::NewGuid().Guid;
            
            if ( -not $ContentType ) {
                $ContentType = 'Initialized to new GUID'
            }
        }
        else {
            Write-Warning "Invalid default value type provided";
            continue;
        }

        Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $ConfigItem.Name -SecretValue (ConvertTo-SecureString -AsPlainText $SecretValue -Force) -ContentType $ContentType;
    }
    else {
        Write-Host -ForegroundColor Cyan 'Secret already exists';
    }
}
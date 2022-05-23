function Process-SynapseWorkspaceEnvironmentConfigs {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$EnvironmentConfigPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputFolder,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SynapseSourcePath
    )

    #
    # Output argument values for reference
    #
    $ArgValues = @{
        EnvironmentConfigPath = $EnvironmentConfigPath;
        OutputFolder          = $OutputFolder;
        SynapseSourcePath     = $SynapseSourcePath;
    }

    $ArgMaxLength = ($ArgValues.Keys | Measure-Object -Property Length -Maximum).Maximum
    $ArgFormatString = "{0,-$ArgMaxLength} : {1}"

    Write-Host -ForegroundColor Yellow ('-' * 120)
    Write-Host -ForegroundColor Yellow "Function agruments:"
    Write-Host
    $ArgValues.GetEnumerator() | Sort-Object -Property Name | ForEach-Object { Write-Host -ForegroundColor Yellow ($ArgFormatString -f $_.Name, $_.Value) }
    Write-Host -ForegroundColor Yellow ('-' * 120)
    Write-Host

    if (-not (Test-Path -Path $EnvironmentConfigPath)) {
        Write-Error "Environment config path '$EnvironmentConfigPath' not found"
    }

    if (-not (Test-Path -Path $SynapseSourcePath)) {
        Write-Error "Synapse source path '$SynapseSourcePath' not found"
    }

    function TouchPath {
        param (
            [Parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [string]$Path
        )

        return ((Test-Path -Path $Path) ? (Get-Item -Path $Path) : (New-Item -Path $Path -ItemType Directory))
    }

    #
    # Get folder objects from paths
    #
    $OutputFolderObj = TouchPath -Path $OutputFolder
    $EnvironmentConfigPathObj = Get-Item -Path $EnvironmentConfigPath

    $EnvironmentConfigFiles = Get-ChildItem -Path $EnvironmentConfigPathObj.FullName -File -Filter *.json | Sort-Object -Property BaseName
    $EnvironmentConfigFiles | Format-Table -Property BaseName, Name, FullName -AutoSize

    # Loop through and process each environment config file
    foreach ($EnvironmentConfigFile in $EnvironmentConfigFiles) {
        Write-Host -ForegroundColor DarkGray ('=' * 120)

        $EnvironmentName = $EnvironmentConfigFile.BaseName
        Write-Host -ForegroundColor Green "Environment: $EnvironmentName"

        $EnvironmentSynapseOutputFolderName = Join-Path -Path $OutputFolderObj.FullName -ChildPath $EnvironmentName -AdditionalChildPath Synapse
        Write-Host -ForegroundColor DarkGray "Output path: $EnvironmentSynapseOutputFolderName"

        # Read the config file contents from JSON into custom object
        $EnvironmentConfig = Get-Content -Path $EnvironmentConfigFile.FullName -Raw | ConvertFrom-Json -AsHashtable

        if ($EnvironmentConfig.Keys -contains 'Synapse') {
            # Loop through each target Synapse workspace and write out the necessary files
            foreach ($SynapseWorkspaceConfiguration in $EnvironmentConfig.Synapse.GetEnumerator()) {
                Write-Host -ForegroundColor DarkGray ('-' * 120)

                $WorkspaceName = $SynapseWorkspaceConfiguration.Name
                $WorkspaceConfig = $SynapseWorkspaceConfiguration.Value

                if ($WorkspaceName -eq '.') {
                    $WorkspaceName = $EnvironmentConfig.SynapseWorkspace_Name
                }

                $WorkspaceParams = @{
                    OutputFolder               = $EnvironmentSynapseOutputFolderName;
                    SynapseSourcePath          = $SynapseSourcePath;
                    WorkspaceConfiguration     = $WorkspaceConfig;
                    WorkspaceLocation          = $EnvironmentConfig.Location;
                    WorkspaceName              = $WorkspaceName;
                    WorkspaceResourceGroupName = $EnvironmentConfig.ResourceGroup_Name;
                    WorkspaceSubscriptionId    = $EnvironmentConfig.SubscriptionId;
                }

                Process-SynapseWorkspaceConfiguration @WorkspaceParams
            }
        }
        else {
            Write-Host -ForegroundColor DarkGray ('-' * 120)
            Write-Warning "'Synapse' key not found in environment configuration"
        }
    }
}
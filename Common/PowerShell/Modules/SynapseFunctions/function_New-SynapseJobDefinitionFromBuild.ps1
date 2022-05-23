function New-SynapseJobDefinitionFromBuild {
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceSynapseJobDefinitionFile,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetSynapseJobDefinitionPath,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BuildArtifactPath,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetStoragePath
    )

    #
    # Show parameter values
    #
    Write-Host "BuildArtifactPath              : $BuildArtifactPath";
    Write-Host "SourceSynapseJobDefinitionFile : $SourceSynapseJobDefinitionFile";
    Write-Host "TargetStoragePath              : $TargetStoragePath";
    Write-Host "TargetSynapseJobDefinitionPath : $TargetSynapseJobDefinitionPath";

    #
    # Import ConfigFunctions module with utility functions
    #
    Import-Module -Name ConfigFunctions

    #
    # Throw error if job definition file does not exist
    #
    if (-not (Test-Path -Path $SourceSynapseJobDefinitionFile)) {
        throw "Job definition file '$SourceSynapseJobDefinitionFile' not found!"
    }

    #
    # Get job definition file object to use path components for other tasks
    #
    $SourceSynapseJobDefinitionFileObj = Get-Item -Path $SourceSynapseJobDefinitionFile
    $SourceJsonFile = $SourceSynapseJobDefinitionFileObj.FullName

    Write-Host "Reading JSON file '$SourceJsonFile'"

    $SourceJson = Get-Content -Path $SourceJsonFile -Raw

    #
    # Find the first JAR file in the "target" folder in $BuildArtifactPath
    #
    $MainFileItem = Get-ChildItem -Path (Join-Path -Path $BuildArtifactPath -ChildPath target) -File -Recurse -Filter *.jar | Select-Object -First 1

    #
    # Throw error if no main JAR file is not found
    #
    if ($null -eq $MainFileItem) {
        throw "No main class file found in '$BuildArtifactPath'"
    }

    $MainFileItem | Format-List -Property Name, FullName, BaseName, Extension, Length

    $MainFileRelativeName = $MainFileItem.FullName.Substring($MainFileItem.FullName.IndexOf('\bin\', [System.StringComparison]::InvariantCultureIgnoreCase) + 5)

    Write-Host "Main JAR file : $MainFileRelativeName"

    $MainFileStorageName = '{0}/{1}' -f $TargetStoragePath, $MainFileRelativeName.Replace('\', '/')

    Write-Host "Main file target storage path : $MainFileStorageName"

    #
    # Populate replacement values
    #
    $Props = @{}
    $Props['properties_jobProperties_file'] = $MainFileStorageName.Replace('\', '/')
    $Jars = New-Object -TypeName System.Collections.ArrayList

    $LibFiles = Get-ChildItem -Path (Join-Path -Path $BuildArtifactPath -ChildPath lib) -File -Recurse -Filter *.jar
    $LibFiles | ForEach-Object {
        $CurrentJarStoragePath = '{0}/lib/{1}' -f $TargetStoragePath, $_.Name;
        Write-Host "Adding target reference JAR : $CurrentJarStoragePath";
        $Jars.Add($CurrentJarStoragePath) | Out-Null;
    }

    $PackageFiles = Get-ChildItem -Path (Join-Path -Path $BuildArtifactPath -ChildPath packages) -File -Recurse -Filter *.jar
    $PackageFiles | Foreach-Object {
        $CurrentJarStoragePath = '{0}/packages/{1}' -f $TargetStoragePath, $_.Name;
        Write-Host "Adding target reference JAR : $CurrentJarStoragePath";
        $Jars.Add($CurrentJarStoragePath) | Out-Null;
    }

    $Props['properties_jobProperties_jars'] = $Jars

    $Props.Keys | Sort-Object | Foreach-Object { Write-Host "$_ : $($Props[$_])" }

    #
    # Replace values in original JSON content and write to target location
    #
    $TargetJson = $SourceJson | ApplyJsonReplacementValues -ReplacementValues $Props

    $TargetSynapseJobDefinitionPathObj = Touch-Path -Path $TargetSynapseJobDefinitionPath

    $TargetFileName = Join-Path -Path $TargetSynapseJobDefinitionPathObj.FullName -ChildPath $SourceSynapseJobDefinitionFileObj.Name

    $TargetJson | Out-File -FilePath $TargetFileName -Encoding utf8
}
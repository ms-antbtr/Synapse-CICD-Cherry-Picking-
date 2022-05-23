function Test-ConfigFileSchema {
    param (
        [parameter(Mandatory = $true)]
        [string]$ConfigPath,

        [string]$SchemaFile,

        [switch]$ErrorOnMissingSchemaFile
    )

    class JsonFileInfo {
        [string]$Name
        [bool]$IsValid = $false
        [string]$Path
        [bool]$FileExsts = $false
        [string]$FullName = $null
        [string]$JsonText = $null
        [bool]$IsJsonValid = $false
        [string]$SchemaFile = $null
        [bool]$SchemaFileExists = $false
        [string]$SchemaFileFullName = $null
        [string]$SchemaText = $null
        [bool]$IsSchemaValid = $true
        [object]$ValidationErrors = $null

        JsonFileInfo (
            [string]$Path
        ) {
            $this.SetPath($Path)
        }

        JsonFileInfo (
            [string]$Path,
            [string]$SchemaFile
        ) {
            $this.SetPath($Path)

            if (-not [string]::IsNullOrEmpty($SchemaFile)) {
                $this.SetSchemaFile($SchemaFile)
            }
        }

        [void] hidden SetPath (
            [string]$Path
        ) {
            $This.Path = $Path   
            $This.FileExsts = Test-Path -Path $Path

            $PathSplit = $Path -split "[\\/]"
            $This.Name = $PathSplit[$PathSplit.Count - 1].Split('.')[0]

            if ($This.FileExsts) {
                $FileObj = Get-Item -Path $Path

                $This.FullName = $FileObj.FullName
                $This.JsonText = Get-Content -Path $This.FullName
                $This.IsJsonValid = Test-Json -Json $This.JsonText
            }
            else {
                $This.FullName = $null
                $This.JsonText = $null
                $This.IsJsonValid = $false
                $This.IsValid = $false
            }

            $This.Validate()
        }

        [void] hidden SetSchemaFile (
            [string]$SchemaFile
        ) {
            $This.SchemaFile = $SchemaFile
            $This.SchemaFileExists = Test-Path -Path $SchemaFile

            if ($This.SchemaFileExists) {
                $SchemafileObj = Get-Item -Path $SchemaFile

                $This.SchemaFileFullName = $SchemafileObj.FullName
                $This.SchemaText = Get-Content -Path $This.SchemaFileFullName -Raw
            }
            else {
                $This.SchemaFileFullName = $null
                $This.SchemaText = $null
            }

            $This.Validate()
        }

        [void] hidden Validate() {
            if ($This.FileExsts) {
                try {
                    if ($This.SchemaFileExists) {
                        $This.IsValid = Test-Json -Json $This.JsonText -Schema $This.SchemaText
                    }
                    else {
                        $This.IsValid = Test-Json -Json $This.JsonText
                    }
                }
                catch {
                    $This.IsValid = $false

                    $This.ValidationErrors = $_
                }
            }
            else {
                $This.IsValid = $false
            }
        }
    }

    Write-Host "Config path : $ConfigPath"

    $ConfigPathExists = Test-Path -Path $ConfigPath

    Write-Host "Config path exists : $ConfigPathExists"

    if (-not $ConfigPathExists) {
        Write-Error "Config path does not exist"
        return
    }

    $ConfigPathObj = Get-Item -Path $ConfigPath
    $ConfigFiles = Get-ChildItem -Path $ConfigPathObj.FullName -Filter *.json -File

    if (-not [string]::IsNullOrEmpty($SchemaFile)) {
        Write-Host "Schema file : $SchemaFile"

        $SchemaFileExists = Test-Path -Path $SchemaFile
    
        Write-Host "Schema file  exists : $SchemaFileExists"
    
        if (-not $SchemaFileExists) {
            if ($ErrorOnMissingSchemaFile) {
                throw 'Schema file not found'
            }
            else {
                Write-Warning 'Schema file not found'
            }
        }
    }

    $ValidationResults = New-Object -TypeName System.Collections.ArrayList

    foreach ($ConfigFileObj in $ConfigFiles) {
        $CurrentConfigName = $ConfigFileObj.BaseName.Split('.')[0]

        Write-Host -ForegroundColor Green "Environment: $CurrentConfigName"

        $CurrentFileInfo = [JsonFileInfo]::New($ConfigFileObj.FullName, $SchemaFile)

        $ValidationResults.Add($CurrentFileInfo) | Out-Null
    }
 
    $ValidationResults | Select-Object -Property Name, IsValid, Path | Format-Table -AutoSize

    $ValidationResults | Where-Object { -not $_.IsValid } | Select-Object Name, ValidationErrors

    if ($ValidationResults | Where-Object { -not $_.IsValid }) {
        Write-Error "Config file validation failed"
    }
}
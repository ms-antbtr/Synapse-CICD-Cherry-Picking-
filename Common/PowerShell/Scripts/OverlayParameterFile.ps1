param (
    [Parameter(Mandatory=$true)]
    [string]$TemplateFile, # = 'C:\Repos\FIN-STR-PLR-MercV2-Core\2110-1\SynapseSparkJobRelease\Infrastructure\DataProcessing\SynapseSparkJob\DataProcessing.json',

    [Parameter(Mandatory=$true)]
    [string]$ParameterFile, # = 'C:\Repos\FIN-STR-PLR-MercV2-Core\2110-1\SynapseSparkJobRelease\Infrastructure\DataProcessing\SynapseSparkJob\Config\mercurysynapsedev1_flattened.json',

    [string]$HierarchySeparator = '_',

    [Parameter(Mandatory=$true)]
    [string]$OutputFolder, # = 'C:\Repos\FIN-STR-PLR-MercV2-Core\2110-1\SynapseSparkJobRelease\Infrastructure\DataProcessing\SynapseSparkJob\obj',

    $AdditionalProperties = @{}
)

function GetObjectPropertyNames ([object]$Obj) {
    if ($null -ne $Obj) {
        $Obj | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
    }
}

$TemplateFileObj = Get-Item -Path $TemplateFile
$TemplateObj = Get-Content -Path $TemplateFile | ConvertFrom-Json

$ParameterFileObj = Get-Item -Path $ParameterFile
$ParameterObj = Get-Content -Path $ParameterFile | ConvertFrom-Json

$TemplateObj | Format-List *

$ParameterObj | Format-List *

$ParameterNames = GetObjectPropertyNames -Obj $ParameterObj

Write-Host -ForegroundColor Cyan ($ParameterNames -join ', ')

foreach ($Item in $ParameterNames) {
    Write-Host -ForegroundColor Green $Item

    $ItemParts = $Item.Split($HierarchySeparator);
    # $ItemParts

    $TargetObjectName = '$TemplateObj'

    foreach ($Part in $ItemParts) {
        $TargetObjectName += ".'$Part'"
    }

    # Write-Host $TargetObjectName
    $CurrentValue = Invoke-Expression $TargetObjectName
    $NewValue = $ParameterObj.$Item

    Write-Host -ForegroundColor White "`t$CurrentValue => $NewValue"

    $Expr = "$TargetObjectName = '$NewValue'"

    Write-Host -ForegroundColor Gray "`t$Expr"
    Invoke-Expression $Expr
}

if ($null -ne $AdditionalProperties -and $AdditionalProperties.Count -gt 0) {
    foreach ($Key in $AdditionalProperties.Keys) {
        Write-Host -ForegroundColor Green $Key

        $KeyParts = $Key.Split($HierarchySeparator);

        $TargetObjectName = '$TemplateObj'

        foreach ($Part in $KeyParts) {
            $TargetObjectName += ".'$Part'"
        }

        $CurrentValue = Invoke-Expression $TargetObjectName
        $NewValue = $AdditionalProperties[$Key]

        $Expr = "$TargetObjectName = `$NewValue"

        Write-Host -ForegroundColor White "`t$CurrentValue => $NewValue"

        Write-Host -ForegroundColor Gray "`t$Expr"

        if ($NewValue -ne $CurrentValue) {
            Invoke-Expression $Expr
        } else {
            Write-Host -ForegroundColor Gray "`tNo change"
        }
    }
}

if (-not (Test-Path -Path $OutputFolder)) {
    New-Item -Path $OutputFolder -ItemType Directory
}

$OutputFileName = "{0}_{1}.json" -f $TemplateFileObj.BaseName, $ParameterFileObj.BaseName
$OutputFileFullName = Join-Path -Path $OutputFolder -ChildPath $OutputFileName

Write-Host -ForegroundColor Yellow $OutputFileFullName

$TemplateObj | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFileFullName -Encoding utf8
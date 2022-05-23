#
# Uses Azure DevOps pipeline logging commands to set variables in a pipeline
param
(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ConfigFile,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$KeyNames,

    [switch]$FailIfKeyNotExists
)

$Message = "Reading from '$( $ConfigFile )'"

Write-Host $Message;
Write-Host

try {
    # Check that config file exists
    if (-not (Test-Path -Path $ConfigFile)) {
        throw "Config file '$($ConfigFile)' not found!";
    }

    Write-Host "Keys to extract:`r`n`t- $( ($KeyNames | Sort-Object) -join "`r`n`t- ")";
    Write-Host;

    # Read config file
    $ConfigObj = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json;

    # Get a list of the keys defined in the config file
    $ConfigParameterNames = $ConfigObj | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name

    # Get a list of requested keys that aren't in the file
    $MissingKeyNames = $KeyNames | Where-Object { $ConfigParameterNames -notcontains $_ } | Sort-Object;
    $ExistingKeyNames = $KeyNames | Where-Object { $ConfigParameterNames -contains $_ } | Sort-Object;

    if ($MissingKeyNames) {
        # FailIfKeyNotExists
        if ($FailIfKeyNotExists) {
            throw "FailIfKeyNotExists specified and requested keys missing from config file: $($MissingKeyNames -join ', ')";
        }
        else {
            $Message = "Requested keys missing from config file: $($MissingKeyNames -join ', ')"
 
            Write-Warning $Message;
            Write-Host "##vso[task.logissue type=warning]$Message"
        }
    }

    $MaxLength = ($ExistingKeyNames | Measure-Object -Maximum -Property length).Maximum;
    
    # Loop through the keys that do exist in the file
    $ExistingKeyNames | ForEach-Object { 
        $ParameterName = $_;
        $ParameterValue = $ConfigObj.$ParameterName;

        Write-Host ("##vso[task.setvariable variable={0};isOutput=true]{1}" -f $ParameterName, $ParameterValue );

        Write-Host ("{0,-$MaxLength} = {1}" -f $ParameterName, $ParameterValue);
    }

    Write-Host "##vso[task.complete result=Succeeded;]Done"
}
catch {
    Write-Host -ForegroundColor Red ($Error[0].Exception.Message);

    Write-Host "##vso[task.LogIssue type=error]$( $Error[0].Exception.Message )";
    Write-Host "##vso[task.complete result=Failed]Failed with exception";

    # Return failure code
    exit 1;
}
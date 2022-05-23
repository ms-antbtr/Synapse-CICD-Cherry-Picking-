param (
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$AasServerName,

    [parameter(Mandatory = $true)]
    [ValidateSet('Active', 'Paused')]
    $DesiredState
)

try {
    $AasServer = Get-AzAnalysisServicesServer -Name $AasServerName -ResourceGroupName $ResourceGroupName
}
catch {
    Write-Warning "Analysis Services instance '$AasServerName' does not exist in resource group '$ResourceGroupName'"
    return
}

Write-Host "Server '$AasServerName' is $($AasServer.State)"

if ($AasServer.State -eq 'Succeeded') {
    Write-Host "##vso[task.setvariable variable=ServerState;isOutput=true;]Active"
}
else {
    Write-Host "##vso[task.setvariable variable=ServerState;isOutput=true;]$($AasServer.State)"
}

$StateChanged = $false

if ($DesiredState -eq 'Active') {
    if ($AasServer.State -ne 'Succeeded') {
        Write-Host "Starting server..."

        Resume-AzAnalysisServicesServer -Name $AasServerName -ResourceGroupName $ResourceGroupName

        $StateChanged = $true
    }
}
elseif ($DesiredState -eq 'Paused') {
    if ($AasServer.State -ne $DesiredState) {
        Write-Host "Pausing server..."

        Suspend-AzAnalysisServicesServer -Name $AasServerName -ResourceGroupName $ResourceGroupName

        $StateChanged = $true
    }
}
else {
    throw "Invalid desired state '$DesiredState'"
}

if ($StateChanged) {
    Write-Host

    $AasServer = Get-AzAnalysisServicesServer -Name $AasServerName -ResourceGroupName $ResourceGroupName

    Write-Host "Server '$AasServerName' is $($AasServer.State)"
}
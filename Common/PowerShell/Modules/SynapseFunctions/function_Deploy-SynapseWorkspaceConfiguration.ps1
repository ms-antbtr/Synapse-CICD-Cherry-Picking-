function Deploy-SynapseWorkspaceConfiguration {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$SynapseWorkspaceName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$WorkspaceConfigPath,

        [switch]$Preview
    )

    if (-not (Test-Path -Path $WorkspaceConfigPath)) {
        Write-Error "Workspace config path '$WorkspaceConfigPath' not found"
        return
    }

    $WorkspaceConfigPathObj = Get-Item -Path $WorkspaceConfigPath

    #-------------------------------------------------------------------------------------------------------
    Write-Host '##[section]Role assignments'

    $RoleAssignmentFile = Join-Path -Path $WorkspaceConfigPathObj.FullName -ChildPath 'RoleAssignments.json'

    if (Test-Path -Path $RoleAssignmentFile) {
        Write-Host -ForegroundColor Cyan "Processing role assignments from '$RoleAssignmentFile'"

        $RoleAssignments = Get-Content -Path $RoleAssignmentFile -Raw | ConvertFrom-Json

        foreach ($RoleItem in $RoleAssignments) {
            Write-Host "Permission to add:"
            $RoleItem | Format-List -Property *

            $ExistingAssignment = az synapse role assignment list --workspace-name $SynapseWorkspaceName --role $RoleItem.RoleDefinitionName --assignee-object-id $RoleItem.ObjectId --only-show-errors | ConvertFrom-Json

            if ($ExistingAssignment -and $ExistingAssignment.Count -gt 0) {
                Write-Host "Assignment exists:"
                $ExistingAssignment | Format-List -Property *
            } else {
                Write-Host "Creating role assignment:"

                $Params = @(
                    'synapse', 'role', 'assignment', 'create', 
                    '--workspace-name', '$(ReleaseParameters.SynapseWorkspace_Name)',
                    '--role', $RoleItem.RoleDefinitionName, 
                    '--assignee-principal-type', $RoleItem.PrincipalType,
                    '--assignee-object-id', $RoleItem.ObjectId,
                    '--only-show-errors'
                )

                Write-Host ("Az parameters: {0}" -f ($Params -join ' '))

                if (-not $Preview) {
                    az $Params
                }
            }
        }
    }
    else {
        Write-Host -ForegroundColor Yellow 'No role assignment file found'
    }

    #-------------------------------------------------------------------------------------------------------
    Write-Host '##[section]Managed private endpoints'

    $PrivateEndpointPath = Join-Path -Path $WorkspaceConfigPathObj.FullName -ChildPath ManagedPrivateEndpoints

    if (Test-Path -Path $PrivateEndpointPath) {
        Write-Host "Processing managed private endpoints from '$PrivateEndpointPath'"

        Deploy-SynapseManagedEndpointFiles -SynapseWorkspaceName $SynapseWorkspaceName -SourcePath $PrivateEndpointPath -Preview:$Preview
    }
    else {
        Write-Host "Private endpoint path '$PrivateEndpointPath' not found"
    }
}

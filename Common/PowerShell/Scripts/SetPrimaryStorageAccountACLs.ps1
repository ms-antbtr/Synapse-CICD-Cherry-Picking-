param (
    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceName
)

function GetStorageAccountContext {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$StorageAccountName
    )

    Write-Debug "START: GetStorageAccountContext"

    $StorageAccountResource = Get-AzResource -ResourceType Microsoft.Storage/storageAccounts -Name $StorageAccountName

    $StorageAccount = $StorageAccountResource | Get-AzStorageAccount
    $StorageAccountKey1 = $StorageAccount | Get-AzStorageAccountKey | Where-Object { $_.KeyName -eq 'key1' } | Select-Object -ExpandProperty Value -First 1

    #
    # Get storage context
    #
    $StorageAccountContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey1

    $StorageAccountContext

    Write-Debug "END: GetStorageAccountContext"
}

function TouchDataLakePath {
    param (
        $StorageAccountContext,

        [string]$Filesystem,

        [string]$Path
    )

    try {
        $Item = Get-AzDataLakeGen2Item -Context $StorageAccountContext -FileSystem $Filesystem -Path $Path
    }
    catch [ArgumentException] {
        $Item = New-AzDataLakeGen2Item -Context $StorageAccountContext -FileSystem $Filesystem -Path $Path -Directory
    }

    $Item
}

Write-Host "Workspace name    : $WorkspaceName"

#
# Get the Azure resource for the Synapse workspace to retrieve the assigned identities
#
$WorkspaceResource = Get-AzResource -Name $WorkspaceName -ResourceType Microsoft.Synapse/workspaces

if (-not $WorkspaceResource) {
    Write-Warning "Workspace resource not found"
    return
}

$WorkspaceIdentity = $WorkspaceResource.Identity

#
# Get the workspace from the resource
#
$Workspace = Get-AzSynapseWorkspace -ResourceGroupName $WorkspaceResource.ResourceGroupName -Name $WorkspaceResource.Name
# $Workspace

#
# Get primary storage account details
#
$Uri = New-Object -TypeName System.Uri -ArgumentList $Workspace.DefaultDataLakeStorage.DefaultDataLakeStorageAccountUrl

$PrimaryStorageAccountName = $Uri.Host.Split('.')[0]
$PrimaryStorageContainerName = $Workspace.DefaultDataLakeStorage.DefaultDataLakeStorageFilesystem

Write-Host "Primary storage account   : $PrimaryStorageAccountName"
Write-Host "Primary storage container : $PrimaryStorageContainerName"

$PrimaryStorageAccountContext = GetStorageAccountContext -StorageAccountName $PrimaryStorageAccountName

#
# Update storage container ACLs
#
$filesystem = Get-AzDataLakeGen2Item -Context $PrimaryStorageAccountContext -FileSystem $PrimaryStorageContainerName

$ACL = $filesystem.ACL

Write-Host "ACL before:"

$ACL | Format-Table -AutoSize

$ACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType user -EntityID $WorkspaceIdentity.PrincipalId -Permission rwx -InputObject $ACL
$ACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType user -EntityID $WorkspaceIdentity.PrincipalId -Permission rwx -DefaultScope -InputObject $ACL

Write-Host "ACL after:"

$ACL | Format-Table -AutoSize

Write-Host "Updating ACL on container"

Update-AzDataLakeGen2Item -Context $PrimaryStorageAccountContext -FileSystem $PrimaryStorageContainerName -Acl $ACL

<#
#
# -----------------------------------------------------------------------------------------------------------------------
#

Write-Host "Linked storage account    : $LinkedStorageAccountName"
Write-Host "Linked storage container  : $LinkedStorageContainerName"

$LinkedStorageAccountContext = GetStorageAccountContext -StorageAccountName $LinkedStorageAccountName

#
# Updated storage container ACLs
#
$filesystem = Get-AzDataLakeGen2Item -Context $LinkedStorageAccountContext -FileSystem $LinkedStorageContainerName

$ACL = $filesystem.ACL

Write-Host "ACL before:"

$ACL | Format-Table -AutoSize

$ACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType user -EntityID $WorkspaceIdentity.PrincipalId -Permission rwx -InputObject $ACL
$ACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType user -EntityID $WorkspaceIdentity.PrincipalId -Permission rwx -DefaultScope -InputObject $ACL

Write-Host "ACL after:"

$ACL | Format-Table -AutoSize

Write-Host "Updating ACL on container"

Update-AzDataLakeGen2Item -Context $LinkedStorageAccountContext -FileSystem $LinkedStorageContainerName -Acl $ACL
#>
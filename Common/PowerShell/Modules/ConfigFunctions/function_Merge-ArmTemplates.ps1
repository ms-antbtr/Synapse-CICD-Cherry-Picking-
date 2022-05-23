<#
.OUTPUT

Returns the merged templates as a JSON-formatted string
#>
param
(
    # Array of JSON-formatted template strings
    [parameter(Mandatory=$true)]
    [object[]]$Templates,

    [object[]]$Dependencies = $null,

    [ValidateSet('template', 'parameters')]
    [string]$FileType = 'template'
)

function LogMessage {
    param
    (
        [string]$Message,

        [string]$Color = 'White'
    )

    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm'

    Write-Host -ForegroundColor $Color "$Timestamp  $($PSCommandPath.Split('/\')[-1])  $Message";
}

LogMessage -Color Yellow -Message "---- Start MergeTemplates ----"


LogMessage -Color Cyan -Message "Merging templates"

$Templates | ForEach-Object { LogMessage -Color White -Message "- $( $_.Name )"; }

# Populate the 'SectionNames' array with the list of sections to include in the resulting file
if ( $FileType -eq 'Parameters' )
{
    # If the files to merged are template parameters, only the 'parameters' blocks need to be merged
    $SectionNames = @('parameters');
}
else
{
    # For anything else, merge all the sections
    $SectionNames = @(
        'parameters',
        'variables',
        'resources',
        'outputs'
    )
}

# $Templates[0].Contents

$CombinedTemplate = $Templates[0].Contents | ConvertFrom-Json;

foreach ( $SectionName in $SectionNames )
{
    if ( -not ($CombinedTemplate | Get-Member -MemberType NoteProperty -Name $SectionName) )
    {
        $CombinedTemplate | Add-Member -MemberType NoteProperty -Name $SectionName -Value (New-Object -TypeName PSObject);
    }
}


foreach ( $TemplateItem in $Templates[1..$Templates.Count] )
{
    LogMessage -Color Cyan -Message "Name: $( $TemplateItem.Name )";

    # Read the contents of the current template JSON file
    $TemplateObject = $TemplateItem.Contents | ConvertFrom-Json;

    # Loop through the sections with named element
    foreach ( $SectionName in @('parameters', 'variables', 'outputs') )
    {
        LogMessage -Color Magenta -Message "Section: $SectionName";

        if ( $TemplateObject.$SectionName )
        {
            $ItemNames = $TemplateObject.$SectionName | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name;

            foreach ( $ItemName in $ItemNames )
            {
                LogMessage -Color White -Message "Item: $ItemName";

                if ( -not ($CombinedTemplate.$SectionName | Get-Member -MemberType NoteProperty -Name $ItemName) )
                {
                    $CombinedTemplate.$SectionName | Add-Member -MemberType NoteProperty -Name $ItemName -Value $TemplateObject.$SectionName.$ItemName
                }
            }
        }
    }

    # Resource definitions are added as-is
    if ( $FileType -eq 'Template' )
    {
        $CombinedTemplate.resources += $TemplateObject.resources;
    }
}

if ( $FileType -eq 'Template' -and $Dependencies )
{
    LogMessage -Color Magenta -Message "Processing injected dependencies"

    $DependencyObject = $Dependencies | ConvertFrom-Json;

    # Loop through each dependency
    foreach( $DependencyItem in $DependencyObject )
    {
        LogMessage -Color Cyan -Message $DependencyItem.ResourceName;

        $Resource = $CombinedTemplate.resources | Where-Object { $_.Name -eq $DependencyItem.ResourceName } | Select-Object -First 1;

        if ( $Resource )
        {
            if ( -not ($Resource | get-Member -Name DependsOn) )
            {
                $Resource | Add-Member -MemberType NoteProperty -Name DependsOn -Value @();
            }

            $Resource.DependsOn += $DependencyItem.DependsOn;
        }
    }
}

# From https://www.cryingcloud.com/blog/2017/05/02/replacefix-unicode-characters-created-by-convertto-json-in-powershell-for-arm-templates

$OutputJSON = ($CombinedTemplate | ConvertTo-Json -Depth 50).Replace('\u0027', '''');

Write-Output $OutputJSON;

LogMessage -Color Yellow -Message "---- End MergeTemplates ----";

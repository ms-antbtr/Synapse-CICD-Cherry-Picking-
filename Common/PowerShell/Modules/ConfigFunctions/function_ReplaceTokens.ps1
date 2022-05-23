function ReplaceTokens {
    param (
        # Content to scan for tokens
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Content,

        # Hash table of values to replace tokens with
        [hashtable]$TokenValues = @{},

        # Second hashtable of values that will override the first
        #
        # This is a convenience parameter to enable token values from multiple sources
        [hashtable]$TokenOverrides = @{},

        # Throw an exception if a token in the content does not have a replacement value
        [switch]$ExceptionOnMissingValue,

        # A list of missing tokens to ignore. Can be used when the token will be replaced later.
        [string[]]$MissingValuesToIgnore,

        <#
        Number of passes through the content to replace tokens. Multiple passes allows for
        tokens values that contain other tokens. This is primarily designed for processing
        environment configuration files where the replacement values are coming from the
        file itself (self-tokens).
        #>
        [int]$Passes = 1
    )

    END {
        $AllContent = $Content -join "`r`n"

        Write-Verbose "Start: ReplaceTokens()"

        Write-Host -ForegroundColor DarkGray '##[group]Before token replacement'
        Write-Host -ForegroundColor DarkGray  $AllContent
        Write-Host -ForegroundColor DarkGray '##[endgroup]'

        # Update the replacement values with override values
        foreach ($Key in $TokenOverrides.Keys) {
            $TokenValues[$Key] = $TokenOverrides.Item($Key)
        }

        $MissingTokenValues = @()

        # Process tokens for the specified number of passes
        for ($i = 1; $i -le $Passes; $i++) {
            # Find all tokens using regular expression matching
            $m = $AllContent | Select-String -Pattern "__(?<TokenName>[\w-]+?)__" -AllMatches

            # Break out of the passes if there aren't any more tokens in the content
            if ($null -eq $m -or $null -eq $m.Matches) {
                Write-Verbose 'No more tokens'
                break
            }

            # Extract the token values from the regex match results
            $TokensToReplace = $m.Matches | ForEach-Object { $_.Groups['TokenName'] } | Select-Object -ExpandProperty Value -Unique | Sort-Object

            $MaxTokenLength = ($TokensToReplace | Measure-Object -Property Length -Maximum).Maximum

            Write-Host "##[group]Pass $i - $($TokensToReplace.Length) tokens"

            # Replace tokens with replacement values
            foreach ($TokenName in $TokensToReplace) {
                if ($MissingValuesToIgnore -contains $TokenName) {
                    Write-Warning "Ignoring missing token $TokenName"
                    continue
                }

                Write-Debug "Token: $TokenName"

                if ($TokenValues.$TokenName) {
                    # Replacement value exists
                    $ReplacementValue = $TokenValues.$TokenName

                    Write-Host ('{0} => {1}' -f "__$($TokenName)__".PadRight($MaxTokenLength + 4), $ReplacementValue)

                    $AllContent = $AllContent.Replace("__$($TokenName)__", $ReplacementValue);
                }
                elseif ($i -eq $Passes) {
                    # Last pass through and the replacement value doesn't exist
                    # Accumulating the missing token values to notify the user of all missing values if ExceptionOnMissingValue

                    Write-Warning "Replacement value for token $TokenName not found"
                    $MissingTokenValues += $TokenName
                }
            }

            Write-Host '##[endgroup]'
        }

        if ($ExceptionOnMissingValue -and $MissingTokenValues.Length -gt 0) {
            Write-Error ("Missing replacement values for these tokens not found: {0}" -f ($MissingTokenValues -join ', '))
            return
        }

        Write-Host -ForegroundColor DarkGray '##[group]After token replacement'
        Write-Host -ForegroundColor DarkGray  $AllContent
        Write-Host -ForegroundColor DarkGray '##[endgroup]'

        # Return the updated content
        Write-Output $AllContent

        Write-Verbose "End: ReplaceTokens()"
    }
}
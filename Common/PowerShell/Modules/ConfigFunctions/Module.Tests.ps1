# https://lazywinadmin.com/2016/05/using-pester-to-test-your-manifest-file.html

BeforeAll {
    Import-Module -Name ..\ConfigFunctions -Force
}
$ModuleName = 'ConfigFunctions'

Describe "$ModuleName tests" {

    Context 'Module setup' {
        It "has a $ModuleName.psm1 file" {
            "$PSScriptRoot\$ModuleName.psm1" | Should -Exist
        }

        It "has a $ModuleName.psd1 file" {
            "$PSScriptRoot\$ModuleName.psd1" | Should -Exist

            "$PSScriptRoot\$ModuleName.psd1" | Should -FileContentMatch "$ModuleName.psm1"
        }

        It "$ModuleName folder has functions" {
            "$PSScriptRoot\function_*.ps1" | Should -Exist

            "$PSScriptRoot\function-*.ps1" | Should -Not -Exist
        }

        It "$ModuleName is valid PowerShell" {
            $FileContent = Get-Content -Path "$PSScriptRoot\$ModuleName.psm1" -ErrorAction Stop

            $ParserErrors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($FileContent, [ref]$ParserErrors)
            $ParserErrors.Count | Should -Be 0
        }
    }

    Context "Test function <_>" -Foreach @(
       'ApplyJsonReplacementValues',
        'Build-ArmParameterFiles'
    ) {
        It "Function <_> should exist" {
            "$PSScriptRoot\function_$($_).ps1" | Should -Exist
        }

        $Help = Get-Help -Path "$PSScriptRoot\function_$($_).ps1" -Full

        # Write-Host $Help

        It "Should have a synopsis" {
            $Help.Synopsis | Should -Not -BeNullOrEmpty
        }
            
    }
 
}
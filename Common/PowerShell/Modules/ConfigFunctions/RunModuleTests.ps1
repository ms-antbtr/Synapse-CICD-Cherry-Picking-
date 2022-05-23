Set-Location -Path $PSScriptRoot

Import-Module Pester

Invoke-Pester -Path .\Module.Tests.ps1 -Verbose
BeforeAll {
    # . $PSCommandPath.Replace('.Tests.ps1','.ps1')
    Import-Module -Name $PSScriptRoot -Force
}

Describe "Help!" {
    It "Empty JSON and replacement values" {
        ApplyJsonReplacementValues -SourceJson '{}' -ReplacementValues @{} | Should -Be '{}'
    }

    It "JSON with no replacement values" {
        ApplyJsonReplacementValues -SourceJson '{"foo": "bar"}' -ReplacementValues @{} | ConvertFrom-Json | ConvertTo-Json -Compress | Should -Be '{"foo":"bar"}'
    }

    It "JSON with replacement values" {
        ApplyJsonReplacementValues -SourceJson '{"foo": "bar"}' -ReplacementValues @{Foo = 'Baz'} | ConvertFrom-Json | ConvertTo-Json -Compress | Should -Be '{"foo":"Baz"}'
    }

    It "JSON with replacement values" {
        ApplyJsonReplacementValues -SourceJson '{"foo": {"bar": "baz"}}' -ReplacementValues @{Foo_Bar = 'bat'} | ConvertFrom-Json | ConvertTo-Json -Compress | Should -Be '{"foo":{"bar":"bat"}}'
    }
}
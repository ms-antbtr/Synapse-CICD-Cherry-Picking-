BeforeAll {
    Import-Module -Name $PSScriptRoot -Force
}

Describe "ReplaceTokens" {   
    Context "Content source" {
        BeforeAll {
            $SourceContent = '
                {
                    "foo": "__FooValue__"
                }'

            $ExpectedContent = '
                {
                    "foo": "Bar"
                }'
        }

        It "Content from pipeline" {
            $SourceContent | ReplaceTokens -TokenValues @{FooValue = "Bar" } | Should -Be $ExpectedContent
        } 

        It "Content from -Content parameter" {
            ReplaceTokens -Content $SourceContent -TokenValues @{FooValue = "Bar" } | Should -Be $ExpectedContent
        } 
    }

    Context "ExceptionOnMissingValue" {
        It "Does not throw an exception on missing replacement value without -ExceptionOnMissingValue" {
            $SourceContent = '
                {
                    "foo": "__FooValue__"
                }'

            $SourceContent | ReplaceTokens -TokenValues @{} | Should -Be $SourceContent
        }

        It "Throws an exception on missing replacement value with -ExceptionOnMissingValue" {
            $SourceContent = '
                {
                    "foo": "__FooValue__"
                }'

            $SourceContent | ReplaceTokens -TokenValues @{} -ExceptionOnMissingValue | Should -Throw -ExpectedMessage "Missing replacement values for these tokens not found: FooValue"
        }

        It "Does not throw an exception on missing replacement value with -ExceptionOnMissingValue and -MissingValuesToIgnore" {
            $SourceContent = '
                {
                    "foo": "__FooValue__"
                    "bar": "__BarValue__"
                }'

            $ExpectedContent = '
                {
                    "foo": "FooValue"
                    "bar": "__BarValue__"
                }'

            $SourceContent | ReplaceTokens -TokenValues @{FooValue = "FooValue" } -ExceptionOnMissingValue -MissingValuesToIgnore BarValue | Should -Be $ExpectedContent
        }
    }

    Context "Multiple passes" {
        BeforeAll {
            $SourceContent = '
                {
                    "DefaultStorageAccount": "__DefaultStorageAccount__"
                    "StorageAccount1": "__StorageAccount1__",
                    "StorageAccount2": "__StorageAccount2__"
                }'

            $TokenValues = @{
                DefaultStorageAccount = "mystorageaccount"; 
                StorageAccount1       = "__DefaultStorageAccount__";
                StorageAccount2       = "__StorageAccount1__";
            }
        }

        It "1 pass" {
            $ExpectedContent = '
                {
                    "DefaultStorageAccount": "mystorageaccount"
                    "StorageAccount1": "__DefaultStorageAccount__",
                    "StorageAccount2": "__StorageAccount1__"
                }'

            $SourceContent | ReplaceTokens -TokenValues $TokenValues -Passes 1 | Should -Be $ExpectedContent
        }

        It "2 passes" {
            $ExpectedContent = '
                {
                    "DefaultStorageAccount": "mystorageaccount"
                    "StorageAccount1": "mystorageaccount",
                    "StorageAccount2": "__DefaultStorageAccount__"
                }'

            $SourceContent | ReplaceTokens -TokenValues $TokenValues -Passes 2 | Should -Be $ExpectedContent
        }

        It "3 passes" {
            $ExpectedContent = '
                {
                    "DefaultStorageAccount": "mystorageaccount"
                    "StorageAccount1": "mystorageaccount",
                    "StorageAccount2": "mystorageaccount"
                }'

            $SourceContent | ReplaceTokens -TokenValues $TokenValues -Passes 3 | Should -Be $ExpectedContent
        }
    }

    Context "Token overrides" {
        BeforeAll {
            $SourceContent = '
                {
                    "Foo": "__Foo__"
                    "Bar": "__Bar__"
                }'

            $ExpectedContent = '
                {
                    "Foo": "Foo"
                    "Bar": "Bar"
                }'
        }

        It "Should work with 1 override" {
            $SourceContent | ReplaceTokens -TokenValues @{Foo="Foo"} -TokenOverrides @{Bar="Bar"} | Should -Be $ExpectedContent
        }

        It "Should work with 2 overrides" {
            $SourceContent | ReplaceTokens -TokenValues @{} -TokenOverrides @{Foo="Foo"; Bar="Bar"} | Should -Be $ExpectedContent
        }
    }
}
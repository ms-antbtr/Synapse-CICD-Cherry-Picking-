BeforeAll {
    Import-Module -Name $PSScriptRoot -Force
}

Describe "Touch-Path" {
    BeforeAll {
        $TestPath = 'TestDrive:\TestFolder'
    }

    Context "Folder does not exist" {
        It "Folder should not initially exist" {
            Test-Path -Path $TestPath | Should -BeFalse
        }

        It "Should return a non-null DirectoryInfo object" {
            $TestPathObj = Touch-Path -Path $TestPath
            $TestPathObj | Should -Not -BeNullOrEmpty
            $TestPathObj | Should -BeOfType [System.IO.DirectoryInfo]
        }

        It "Should exist after Touch-Path" {
            Test-Path -Path $TestPath | Should -BeTrue
        }
    }

    Context "Folder already exists" {
        BeforeAll {
            $PathObj = New-Item -Path $TestPath -ItemType Directory
        }

        It "Folder should already exist" {
            Test-Path -Path $TestPath | Should -BeTrue
        }

        It "Should return file object for existing folder" {
            $TestPathObj = Touch-Path -Path $TestPath

            $TestPathObj | Should -Not -BeNullOrEmpty
            $TestPathObj | Should -BeOfType [System.IO.DirectoryInfo]
            Compare-Object -ReferenceObject $PathObj -DifferenceObject $TestPathObj | Should -BeNullOrEmpty
        }
    }
}
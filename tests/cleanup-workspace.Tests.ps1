$scriptPath = Join-Path $PSScriptRoot "..\scripts\cleanup-workspace.ps1"

Describe "cleanup-workspace.ps1" {
    BeforeEach {
        # Create test workspace structure
        $script:testRoot = Join-Path $TestDrive "workspace-test"
        New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null

        # Clean up test root before each test
        if (Test-Path $script:testRoot) {
            Remove-Item -Path $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
            New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null
        }
        Push-Location $script:testRoot
    }

    AfterEach {
        Pop-Location
    }

    Context "Script Validation" {
        It "Script file should exist" {
            Test-Path $scriptPath | Should -Be $true
        }

        It "Script should have valid PowerShell syntax" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $scriptPath -Raw), [ref]$errors)
            $errors.Count | Should -Be 0
        }

        It "Script should support -DryRun parameter" {
            $help = Get-Help $scriptPath
            $help.parameters.parameter.name | Should -Contain 'DryRun'
        }

        It "Script should support -DaysOld parameter" {
            $help = Get-Help $scriptPath
            $help.parameters.parameter.name | Should -Contain 'DaysOld'
        }

        It "Script should support -MinFreeSpaceGB parameter" {
            $help = Get-Help $scriptPath
            $help.parameters.parameter.name | Should -Contain 'MinFreeSpaceGB'
        }

        It "Script should support -ExcludePaths parameter" {
            $help = Get-Help $scriptPath
            $help.parameters.parameter.name | Should -Contain 'ExcludePaths'
        }
    }

    Context "Unity Library Cleanup" {
        It "Should identify Unity Library folders correctly" {
            # Create Unity project structure
            $unityProject = Join-Path $script:testRoot "UnityProject"
            $library = Join-Path $unityProject "Library"
            $assets = Join-Path $unityProject "Assets"

            New-Item -ItemType Directory -Path $library -Force | Out-Null
            New-Item -ItemType Directory -Path $assets -Force | Out-Null

            # Make it old
            (Get-Item $library).LastWriteTime = (Get-Date).AddDays(-10)

            # Run cleanup in dry run mode
            & $scriptPath -DryRun -DaysOld 7

            # Library should still exist (dry run)
            Test-Path $library | Should -Be $true
        }

        It "Should not delete recent Unity Library folders" {
            $unityProject = Join-Path $script:testRoot "UnityProject"
            $library = Join-Path $unityProject "Library"
            $assets = Join-Path $unityProject "Assets"

            New-Item -ItemType Directory -Path $library -Force | Out-Null
            New-Item -ItemType Directory -Path $assets -Force | Out-Null

            # Recent folder
            (Get-Item $library).LastWriteTime = (Get-Date).AddDays(-3)

            & $scriptPath -DaysOld 7

            Test-Path $library | Should -Be $true
        }

        It "Should delete old Unity Library folders" {
            $unityProject = Join-Path $script:testRoot "UnityProject"
            $library = Join-Path $unityProject "Library"
            $assets = Join-Path $unityProject "Assets"

            New-Item -ItemType Directory -Path $library -Force | Out-Null
            New-Item -ItemType Directory -Path $assets -Force | Out-Null

            # Old folder
            (Get-Item $library).LastWriteTime = (Get-Date).AddDays(-10)

            & $scriptPath -DaysOld 7

            Test-Path $library | Should -Be $false
        }
    }

    Context "Build Artifacts Cleanup" {
        It "Should clean old build directories" {
            $buildDirs = @("bin", "obj", "build", "dist")

            foreach ($dir in $buildDirs) {
                $path = Join-Path $script:testRoot $dir
                New-Item -ItemType Directory -Path $path -Force | Out-Null
                (Get-Item $path).LastWriteTime = (Get-Date).AddDays(-10)
            }

            & $scriptPath -DaysOld 7

            foreach ($dir in $buildDirs) {
                $path = Join-Path $script:testRoot $dir
                Test-Path $path | Should -Be $false
            }
        }

        It "Should preserve recent build directories" {
            $buildDir = Join-Path $script:testRoot "build"
            New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
            (Get-Item $buildDir).LastWriteTime = (Get-Date).AddDays(-3)

            & $scriptPath -DaysOld 7

            Test-Path $buildDir | Should -Be $true
        }
    }

    Context "Cache Cleanup" {
        It "Should clean old node_modules" {
            $nodeModules = Join-Path $script:testRoot "node_modules"
            New-Item -ItemType Directory -Path $nodeModules -Force | Out-Null
            (Get-Item $nodeModules).LastWriteTime = (Get-Date).AddDays(-10)

            & $scriptPath -DaysOld 7

            Test-Path $nodeModules | Should -Be $false
        }

        It "Should clean old Python cache directories" {
            $pycache = Join-Path $script:testRoot "__pycache__"
            New-Item -ItemType Directory -Path $pycache -Force | Out-Null
            (Get-Item $pycache).LastWriteTime = (Get-Date).AddDays(-10)

            & $scriptPath -DaysOld 7

            Test-Path $pycache | Should -Be $false
        }
    }

    Context "Temporary Files Cleanup" {
        It "Should clean old temporary files" {
            $tempFiles = @("test.tmp", "data.temp", "backup.bak", "file.old")

            foreach ($file in $tempFiles) {
                $path = Join-Path $script:testRoot $file
                "test content" | Out-File -FilePath $path
                (Get-Item $path).LastWriteTime = (Get-Date).AddDays(-10)
            }

            & $scriptPath -DaysOld 7

            foreach ($file in $tempFiles) {
                $path = Join-Path $script:testRoot $file
                Test-Path $path | Should -Be $false
            }
        }
    }

    Context "Exclusion List" {
        It "Should respect excluded paths" {
            $protectedDir = Join-Path $script:testRoot "protected"
            $protectedBuild = Join-Path $protectedDir "build"

            New-Item -ItemType Directory -Path $protectedBuild -Force | Out-Null
            (Get-Item $protectedBuild).LastWriteTime = (Get-Date).AddDays(-10)

            & $scriptPath -DaysOld 7 -ExcludePaths @($protectedDir)

            Test-Path $protectedBuild | Should -Be $true
        }

        It "Should clean non-excluded old build directories" {
            $protectedDir = Join-Path $script:testRoot "protected"
            $protectedBuild = Join-Path $protectedDir "build"
            $regularBuild = Join-Path $script:testRoot "build"

            New-Item -ItemType Directory -Path $protectedBuild -Force | Out-Null
            New-Item -ItemType Directory -Path $regularBuild -Force | Out-Null
            (Get-Item $protectedBuild).LastWriteTime = (Get-Date).AddDays(-10)
            (Get-Item $regularBuild).LastWriteTime = (Get-Date).AddDays(-10)

            & $scriptPath -DaysOld 7 -ExcludePaths @($protectedDir)

            Test-Path $protectedBuild | Should -Be $true
            Test-Path $regularBuild | Should -Be $false
        }
    }

    Context "Dry Run Mode" {
        It "Should not delete anything in dry run mode" {
            $buildDir = Join-Path $script:testRoot "build"
            New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
            (Get-Item $buildDir).LastWriteTime = (Get-Date).AddDays(-10)

            & $scriptPath -DryRun -DaysOld 7

            Test-Path $buildDir | Should -Be $true
        }
    }

    Context "Logging" {
        It "Should create log file" {
            $logPath = Join-Path $script:testRoot "logs\cleanup.log"

            & $scriptPath -DaysOld 7 -LogPath $logPath

            Test-Path $logPath | Should -Be $true
        }

        It "Should log cleanup operations" {
            $logPath = Join-Path $script:testRoot "logs\cleanup.log"
            $buildDir = Join-Path $script:testRoot "build"
            New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
            (Get-Item $buildDir).LastWriteTime = (Get-Date).AddDays(-10)

            & $scriptPath -DaysOld 7 -LogPath $logPath

            $logContent = Get-Content $logPath -Raw
            $logContent | Should -Match "Workspace Cleanup Script Started"
            $logContent | Should -Match "Cleanup completed"
        }
    }

    Context "Docker Integration" {
        It "Should handle missing Docker gracefully" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'docker' }

            { & $scriptPath -DryRun } | Should -Not -Throw
        }
    }

    Context "Error Handling" {
        It "Should continue on errors and not crash" {
            # Create a file we can't delete (simulate permission error)
            $testFile = Join-Path $script:testRoot "test.tmp"
            "content" | Out-File -FilePath $testFile
            (Get-Item $testFile).LastWriteTime = (Get-Date).AddDays(-10)

            # Script should complete without throwing
            { & $scriptPath -DaysOld 7 } | Should -Not -Throw
        }
    }

    Context "Space Reporting" {
        It "Should report disk space information" {
            $logPath = Join-Path $script:testRoot "logs\cleanup.log"

            & $scriptPath -DryRun -LogPath $logPath

            $logContent = Get-Content $logPath -Raw
            $logContent | Should -Match "Drive.*GB free"
        }
    }
}

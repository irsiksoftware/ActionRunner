#Requires -Version 5.1

BeforeAll {
    $script:ServerPath = Join-Path $PSScriptRoot '..\dashboard\server.ps1'
    $script:IndexPath = Join-Path $PSScriptRoot '..\dashboard\index.html'
    $script:DashboardJsPath = Join-Path $PSScriptRoot '..\dashboard\dashboard.js'
}

Describe "verify-dashboard-server.ps1 - Dashboard Files Validation" {
    It "Server script exists" {
        Test-Path $script:ServerPath | Should -Be $true
    }

    It "Index.html file exists" {
        Test-Path $script:IndexPath | Should -Be $true
    }

    It "Dashboard.js file exists" {
        Test-Path $script:DashboardJsPath | Should -Be $true
    }

    It "Server script has valid PowerShell syntax" {
        $parseErrors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize(
            (Get-Content $script:ServerPath -Raw),
            [ref]$parseErrors
        )
        $parseErrors.Count | Should -Be 0
    }

    It "Server script has proper comment-based help" {
        $content = Get-Content $script:ServerPath -Raw
        $content | Should -Match '\.SYNOPSIS'
        $content | Should -Match '\.DESCRIPTION'
        $content | Should -Match '\.PARAMETER Port'
        $content | Should -Match '\.EXAMPLE'
    }
}

Describe "verify-dashboard-server.ps1 - Server Script Parameters" {
    BeforeAll {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:ServerPath,
            [ref]$null,
            [ref]$null
        )
        $script:Params = $ast.ParamBlock.Parameters
    }

    It "Has Port parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'Port' }
        $param | Should -Not -BeNullOrEmpty
    }

    It "Port parameter is an integer" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'Port' }
        $param.StaticType.Name | Should -Be 'Int32'
    }

    It "Port parameter has default value of 8080" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'Port' }
        $defaultValue = $param.DefaultValue.Extent.Text
        $defaultValue | Should -Be '8080'
    }

    It "Port parameter is not mandatory" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'Port' }
        $mandatoryAttr = $param.Attributes | Where-Object { $_.TypeName.Name -eq 'Parameter' }
        $mandatoryAttr.NamedArguments | Where-Object { $_.ArgumentName -eq 'Mandatory' -and $_.Argument.VariablePath.UserPath -eq 'true' } | Should -BeNullOrEmpty
    }
}

Describe "verify-dashboard-server.ps1 - Server Script Content" {
    BeforeAll {
        $script:Content = Get-Content $script:ServerPath -Raw
    }

    It "Creates HttpListener object" {
        $script:Content | Should -Match 'New-Object System\.Net\.HttpListener'
    }

    It "Configures server prefix with port" {
        $script:Content | Should -Match '\$listener\.Prefixes\.Add\('
        $script:Content | Should -Match 'http://localhost:\$Port'
    }

    It "Starts the listener" {
        $script:Content | Should -Match '\$listener\.Start\(\)'
    }

    It "Handles root path (/) route" {
        $script:Content | Should -Match '\$url -eq "/"'
    }

    It "Handles /index.html route" {
        $script:Content | Should -Match '\$url -eq "/index\.html"'
    }

    It "Handles /dashboard.js route" {
        $script:Content | Should -Match '\$url -eq "/dashboard\.js"'
    }

    It "Handles /api/dashboard-data API endpoint" {
        $script:Content | Should -Match '\$url -eq "/api/dashboard-data"'
    }

    It "Sets correct content type for HTML" {
        $script:Content | Should -Match '\$response\.ContentType = "text/html'
    }

    It "Sets correct content type for JavaScript" {
        $script:Content | Should -Match '\$response\.ContentType = "application/javascript'
    }

    It "Sets correct content type for JSON" {
        $script:Content | Should -Match '\$response\.ContentType = "application/json'
    }

    It "Returns 404 for unknown routes" {
        $script:Content | Should -Match '\$response\.StatusCode = 404'
    }

    It "Uses UTF-8 encoding" {
        $script:Content | Should -Match 'UTF8'
    }

    It "Closes response after handling" {
        $script:Content | Should -Match '\$response\.Close\(\)'
    }

    It "Stops listener in finally block" {
        $script:Content | Should -Match 'finally\s*\{[\s\S]*?\$listener\.Stop\(\)'
    }

    It "Uses try-finally for cleanup" {
        $script:Content | Should -Match 'try\s*\{[\s\S]*?\}\s*finally\s*\{'
    }

    It "Uses ErrorActionPreference" {
        $script:Content | Should -Match '\$ErrorActionPreference'
    }
}

Describe "verify-dashboard-server.ps1 - API Endpoint Data Structure" {
    BeforeAll {
        $script:Content = Get-Content $script:ServerPath -Raw
    }

    It "Returns status field" {
        # Status can be "online", "offline", or "idle" depending on data source
        $script:Content | Should -Match 'status\s*='
    }

    It "Returns timestamp field" {
        $script:Content | Should -Match 'timestamp\s*='
    }

    It "Returns metrics object" {
        $script:Content | Should -Match 'metrics\s*=\s*@\{'
    }

    It "Metrics includes totalJobsToday" {
        $script:Content | Should -Match 'totalJobsToday\s*='
    }

    It "Metrics includes successfulJobs" {
        $script:Content | Should -Match 'successfulJobs\s*='
    }

    It "Metrics includes failedJobs" {
        $script:Content | Should -Match 'failedJobs\s*='
    }

    It "Metrics includes successRate" {
        $script:Content | Should -Match 'successRate\s*='
    }

    It "Metrics includes diskFreeGB" {
        $script:Content | Should -Match 'diskFreeGB\s*='
    }

    It "Metrics includes diskTotalGB" {
        $script:Content | Should -Match 'diskTotalGB\s*='
    }

    It "Metrics includes avgJobDuration" {
        $script:Content | Should -Match 'avgJobDuration\s*='
    }

    It "Metrics includes queueLength" {
        $script:Content | Should -Match 'queueLength\s*='
    }

    It "Metrics includes uptimeHours" {
        $script:Content | Should -Match 'uptimeHours\s*='
    }

    It "Returns charts object" {
        $script:Content | Should -Match 'charts\s*=\s*@\{'
    }

    It "Charts includes jobsPerDay array" {
        $script:Content | Should -Match 'jobsPerDay\s*=\s*@\(\)'
    }

    It "Charts includes diskPerDay array" {
        $script:Content | Should -Match 'diskPerDay\s*=\s*@\(\)'
    }

    It "Returns recentJobs array" {
        $script:Content | Should -Match 'recentJobs\s*=\s*@\(\)'
    }

    It "Uses ConvertTo-Json to serialize data" {
        $script:Content | Should -Match 'ConvertTo-Json -Depth'
    }
}

Describe "verify-dashboard-server.ps1 - Disk Space Retrieval" {
    BeforeAll {
        $script:Content = Get-Content $script:ServerPath -Raw
    }

    It "Retrieves disk information using Get-PSDrive" {
        $script:Content | Should -Match 'Get-PSDrive -PSProvider FileSystem'
    }

    It "Filters for C drive" {
        $script:Content | Should -Match 'Where-Object.*Name -eq "C"'
    }

    It "Calculates disk free space in GB" {
        $script:Content | Should -Match '\$disk\.Free / 1GB'
    }

    It "Calculates disk total space in GB" {
        $script:Content | Should -Match '\(\$disk\.Used \+ \$disk\.Free\) / 1GB'
    }

    It "Rounds disk space values" {
        $script:Content | Should -Match '\[math\]::Round\('
    }
}

Describe "verify-dashboard-server.ps1 - System Uptime" {
    BeforeAll {
        $script:Content = Get-Content $script:ServerPath -Raw
    }

    It "Retrieves system uptime" {
        $script:Content | Should -Match 'Get-Uptime'
    }

    It "Converts uptime to hours" {
        $script:Content | Should -Match '\.TotalHours'
    }

    It "Rounds uptime value" {
        $script:Content | Should -Match '\[math\]::Round\(.*\.TotalHours'
    }
}

Describe "verify-dashboard-server.ps1 - Chart Data Generation" {
    BeforeAll {
        $script:Content = Get-Content $script:ServerPath -Raw
    }

    It "Generates 7 days of jobs per day data (fallback)" {
        $script:Content | Should -Match 'for \(\$i = 6; \$i -ge 0; \$i--\)'
    }

    It "Adds dates using AddDays" {
        $script:Content | Should -Match '\.AddDays\(-\$i\)'
    }

    It "Formats dates for chart labels" {
        $script:Content | Should -Match 'ToString\("MMM dd"\)'
    }

    It "Includes date field in chart data" {
        $script:Content | Should -Match 'date\s*='
    }

    It "Includes count field in jobsPerDay" {
        $script:Content | Should -Match 'count\s*='
    }

    It "Includes freeGB field in diskPerDay" {
        $script:Content | Should -Match 'freeGB\s*='
    }
}

Describe "verify-dashboard-server.ps1 - Recent Jobs and Status" {
    BeforeAll {
        $script:Content = Get-Content $script:ServerPath -Raw
    }

    It "Assigns job status values" {
        # Status values used in data (online/offline/idle for runner, success/failure for jobs)
        $script:Content | Should -Match '"offline"'
    }

    It "Checks for C drive by name" {
        $script:Content | Should -Match 'Name -eq "C"'
    }

    It "Includes status field" {
        $script:Content | Should -Match 'status\s*='
    }

    It "Includes timestamp field" {
        $script:Content | Should -Match 'timestamp\s*='
    }

    It "Includes recentJobs array" {
        $script:Content | Should -Match 'recentJobs\s*='
    }
}

Describe "verify-dashboard-server.ps1 - HTML Content Validation" {
    BeforeAll {
        $script:HtmlContent = Get-Content $script:IndexPath -Raw
    }

    It "Has valid HTML structure" {
        $script:HtmlContent | Should -Match '<!DOCTYPE html>'
        $script:HtmlContent | Should -Match '<html.*>'
        $script:HtmlContent | Should -Match '</html>'
    }

    It "Includes head section" {
        $script:HtmlContent | Should -Match '<head>'
        $script:HtmlContent | Should -Match '</head>'
    }

    It "Includes body section" {
        $script:HtmlContent | Should -Match '<body>'
        $script:HtmlContent | Should -Match '</body>'
    }

    It "Includes title for dashboard" {
        $script:HtmlContent | Should -Match '<title>.*Runner.*Dashboard.*</title>'
    }

    It "References dashboard.js script" {
        $script:HtmlContent | Should -Match '<script.*src="dashboard\.js"'
    }

    It "Contains status indicator element" {
        $script:HtmlContent | Should -Match 'statusDot|status-dot|status_dot'
    }

    It "Contains metrics display elements" {
        $script:HtmlContent | Should -Match 'totalJobs|total-jobs|total_jobs'
    }

    It "Contains success rate display" {
        $script:HtmlContent | Should -Match 'successRate|success-rate|success_rate'
    }

    It "Uses UTF-8 charset" {
        $script:HtmlContent | Should -Match 'charset.*utf-8'
    }
}

Describe "verify-dashboard-server.ps1 - JavaScript Content Validation" {
    BeforeAll {
        $script:JsContent = Get-Content $script:DashboardJsPath -Raw
    }

    It "Defines loadDashboard function" {
        $script:JsContent | Should -Match 'function loadDashboard'
    }

    It "Makes API call to /api/dashboard-data" {
        $script:JsContent | Should -Match '/api/dashboard-data'
    }

    It "Uses fetch or XMLHttpRequest for API calls" {
        ($script:JsContent -match 'fetch\(') -or ($script:JsContent -match 'XMLHttpRequest') | Should -Be $true
    }

    It "Handles JSON response parsing" {
        $script:JsContent | Should -Match '\.json\(\)|JSON\.parse'
    }

    It "Defines updateDashboard function" {
        $script:JsContent | Should -Match 'function updateDashboard'
    }

    It "Defines generateMockData function" {
        $script:JsContent | Should -Match 'function generateMockData'
    }

    It "Updates DOM elements with dashboard data" {
        $script:JsContent | Should -Match 'getElementById|querySelector'
    }

    It "Implements auto-refresh mechanism" {
        $script:JsContent | Should -Match 'setInterval'
    }
}

Describe "verify-dashboard-server.ps1 - Security Considerations" {
    BeforeAll {
        $script:ServerContent = Get-Content $script:ServerPath -Raw
    }

    It "Binds to localhost by default (not 0.0.0.0)" {
        $script:ServerContent | Should -Match 'localhost'
    }

    It "Does not expose sensitive system information" {
        # Should not contain credential paths, tokens, or keys
        $script:ServerContent | Should -Not -Match 'password|secret|api_key|token.*='
    }

    It "Uses proper error handling" {
        $script:ServerContent | Should -Match '\$ErrorActionPreference'
    }

    It "Serves static files from dashboard directory only" {
        $script:ServerContent | Should -Match '\$dashboardDir'
    }
}

Describe "verify-dashboard-server.ps1 - Logging and Monitoring" {
    BeforeAll {
        $script:Content = Get-Content $script:ServerPath -Raw
    }

    It "Logs server startup" {
        $script:Content | Should -Match 'Write-Host.*Starting.*Server'
    }

    It "Logs incoming requests" {
        $script:Content | Should -Match 'Write-Host.*\$url|Write-Host.*\$request'
    }

    It "Logs server port information" {
        $script:Content | Should -Match 'Write-Host.*Port'
    }

    It "Displays access URL to user" {
        $script:Content | Should -Match 'http://localhost:\$Port'
    }

    It "Logs server shutdown" {
        $script:Content | Should -Match 'Write-Host.*stopped|Write-Host.*Stopping'
    }

    It "Uses colored output for better readability" {
        $script:Content | Should -Match '-ForegroundColor'
    }
}

Describe "verify-dashboard-server.ps1 - HTTP Server Functionality" {
    Context "When server components are available" {
        BeforeAll {
            $script:HttpListenerAvailable = $null -ne ([System.Net.HttpListener] -as [type])
        }

        It "System.Net.HttpListener is available in PowerShell" -Skip:(-not $script:HttpListenerAvailable) {
            [System.Net.HttpListener] | Should -Not -BeNullOrEmpty
        }

        It "Can create HttpListener instance" -Skip:(-not $script:HttpListenerAvailable) {
            { $listener = New-Object System.Net.HttpListener } | Should -Not -Throw
        }
    }
}

Describe "verify-dashboard-server.ps1 - Documentation and Help" {
    BeforeAll {
        $script:Content = Get-Content $script:ServerPath -Raw
    }

    It "Includes usage example in help" {
        $script:Content | Should -Match '\.EXAMPLE'
        $script:Content | Should -Match 'server\.ps1.*-Port'
    }

    It "Documents Port parameter" {
        $script:Content | Should -Match '\.PARAMETER Port'
    }

    It "Has meaningful synopsis" {
        $script:Content | Should -Match '\.SYNOPSIS'
        $script:Content | Should -Match 'HTTP server|dashboard'
    }

    It "Has detailed description" {
        $script:Content | Should -Match '\.DESCRIPTION'
    }
}

Describe "verify-dashboard-server.ps1 - DashboardDataProvider Integration" {
    BeforeAll {
        $script:Content = Get-Content $script:ServerPath -Raw
        $script:ModulePath = Join-Path $PSScriptRoot '..\modules\DashboardDataProvider.psm1'
    }

    It "Imports DashboardDataProvider module" {
        $script:Content | Should -Match 'Import-Module \$modulePath'
    }

    It "DashboardDataProvider module exists" {
        Test-Path $script:ModulePath | Should -Be $true
    }

    It "Uses Get-DashboardData function for real data" {
        $script:Content | Should -Match 'Get-DashboardData'
    }

    It "Has LogPath parameter for specifying runner logs" {
        $script:Content | Should -Match '\$LogPath'
    }

    It "Has fallback data when module unavailable" {
        $script:Content | Should -Match 'if \(\$null -eq \$data\)'
    }

    It "Module exports required functions" {
        Import-Module $script:ModulePath -Force -WarningAction SilentlyContinue
        Get-Command -Name 'Get-DashboardData' -Module 'DashboardDataProvider' | Should -Not -BeNullOrEmpty
        Get-Command -Name 'Parse-WorkerLogs' -Module 'DashboardDataProvider' | Should -Not -BeNullOrEmpty
        Get-Command -Name 'Get-RunnerStatus' -Module 'DashboardDataProvider' | Should -Not -BeNullOrEmpty
        Get-Command -Name 'Get-DiskMetrics' -Module 'DashboardDataProvider' | Should -Not -BeNullOrEmpty
    }
}

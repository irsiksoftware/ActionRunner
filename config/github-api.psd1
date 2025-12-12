# GitHub API Configuration
# Central source of truth for GitHub API endpoints and constants
# Used by register-runner.ps1 and other scripts that interact with GitHub API

@{
    # GitHub API base URLs
    ApiBaseUrl = 'https://api.github.com'
    GitHubBaseUrl = 'https://github.com'

    # GitHub Actions Runner API endpoints (relative to ApiBaseUrl)
    Endpoints = @{
        RunnerReleases = '/repos/actions/runner/releases/latest'
        OrgRegistrationToken = '/orgs/{org}/actions/runners/registration-token'
        RepoRegistrationToken = '/repos/{repo}/actions/runners/registration-token'
    }

    # API headers
    Headers = @{
        Accept = 'application/vnd.github+json'
        ApiVersion = '2022-11-28'
    }
}

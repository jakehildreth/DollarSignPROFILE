<#
.SYNOPSIS
    Installs DollarSignPROFILE to the current user's PowerShell profile.

.DESCRIPTION
    Downloads DollarSignPROFILE.ps1 from GitHub and writes it to $PROFILE,
    creating the parent directory if needed. Then dot-sources the profile
    to make it immediately active in the current session.

.EXAMPLE
    iwr profile.jakehildreth.com | iex

.EXAMPLE
    Invoke-RestMethod -Uri https://profile.jakehildreth.com | Invoke-Expression

.OUTPUTS
    None

.NOTES
    Source: https://github.com/jakehildreth/DollarSignPROFILE
#>

$SourceUri = 'https://raw.githubusercontent.com/jakehildreth/DollarSignPROFILE/refs/heads/main/DollarSignPROFILE.ps1'
$ErrorActionPreference = 'Stop'

try {
    $ProfileContent = (Invoke-WebRequest -Uri $SourceUri).Content

    $ProfileDirectory = Split-Path -Path $PROFILE -Parent
    if (-not (Test-Path -Path $ProfileDirectory)) {
        New-Item -ItemType Directory -Path $ProfileDirectory -Force | Out-Null
    }

    Set-Content -Path $PROFILE -Value $ProfileContent -Encoding UTF8
    Write-Host "[+] Profile written to $PROFILE"

    . $PROFILE
    Write-Host "[+] Profile loaded successfully"
} catch {
    Write-Error "Installation failed: $_"
}
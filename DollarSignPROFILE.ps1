# Change (In the House of Flies)
#region Self-Update
try {
    $selfUpdateUrl = 'https://raw.githubusercontent.com/jakehildreth/DollarSignPROFILE/refs/heads/main/DollarSignPROFILE.ps1'
    $localContent  = [System.IO.File]::ReadAllText($PROFILE)

    $preference = $null
    if ($localContent -match '(?m)^# DollarSignPROFILE:AutoUpdate=(\w+)') {
        $preference = $Matches[1]
    }

    if ($preference -ne 'never') {
        $localStripped    = ($localContent -replace '(?m)^# DollarSignPROFILE:AutoUpdate=\w+(\r?\n)?', '').Trim() -replace '\r\n', "`n"
        $remoteContent    = (Invoke-WebRequest -Uri $selfUpdateUrl -UseBasicParsing).Content
        $remoteNormalized = $remoteContent.Trim() -replace '\r\n', "`n"

        if ($localStripped -ne $remoteNormalized) {
            if ($preference -eq 'always') {
                Set-Content -Path $PROFILE -Value ("# DollarSignPROFILE:AutoUpdate=always`n" + $remoteContent) -Encoding UTF8
                . $PROFILE
                return
            } else {
                $caption = 'DollarSignPROFILE update available'
                $message = 'A new version of your PowerShell profile is available. Apply it?'
                $choices = @(
                    [System.Management.Automation.Host.ChoiceDescription]::new('Yes, &always',        'Always apply updates silently.')
                    [System.Management.Automation.Host.ChoiceDescription]::new('Yes, &just this time', 'Apply this update; ask again next time.')
                    [System.Management.Automation.Host.ChoiceDescription]::new('No, &not this time',   'Skip this update; ask again next time.')
                    [System.Management.Automation.Host.ChoiceDescription]::new('No, ne&ver',           'Never check for or apply updates.')
                )
                $result = $Host.UI.PromptForChoice($caption, $message, $choices, 2)
                switch ($result) {
                    0 {
                        Set-Content -Path $PROFILE -Value ("# DollarSignPROFILE:AutoUpdate=always`n" + $remoteContent) -Encoding UTF8
                        . $PROFILE
                        return
                    }
                    1 {
                        Set-Content -Path $PROFILE -Value $remoteContent -Encoding UTF8
                        . $PROFILE
                        return
                    }
                    3 {
                        $neverContent = "# DollarSignPROFILE:AutoUpdate=never`n" + ($localContent -replace '(?m)^# DollarSignPROFILE:AutoUpdate=\w+(\r?\n)?', '')
                        Set-Content -Path $PROFILE -Value $neverContent -Encoding UTF8
                    }
                }
            }
        }
    }
} catch {
    # Network unavailable or other error - continue loading profile as-is
}
#endregion Self-Update

[Console]::OutputEncoding = [Text.Encoding]::UTF8

# Enable Ctrl+U to clear line on Windows
Set-PSReadLineKeyHandler -Chord 'Ctrl+u' -Function BackwardDeleteLine

# Enable ESC to clear full comand on macOS
Set-PSReadLineKeyHandler -Chord 'Escape' -Function RevertLine

# Make Alt+Arrow and Ctrl+Arrow work the same on Mac+Windows
Set-PSReadLineKeyHandler -Chord 'Alt+LeftArrow'  -Function BackwardWord
Set-PSReadLineKeyHandler -Chord 'Alt+RightArrow' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow'  -Function BackwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord

# Make Ctrl+Backspace and Alt+Backspace work the same on Mac+Windows
Set-PSReadLineKeyHandler -Chord 'Ctrl+Backspace' -Function BackwardDeleteWord
Set-PSReadLineKeyHandler -Chord 'Alt+Backspace' -Function BackwardDeleteWord

# Make Ctrl+Delete and Alt+Delete work the same on Mac+Windows
Set-PSReadLineKeyHandler -Chord 'Ctrl+Delete' -Function DeleteWord
Set-PSReadLineKeyHandler -Chord 'Alt+Delete' -Function DeleteWord

function New-Credential {
    param(
        [string]$User
    )

    Write-Host @"

PowerShell credential request
Enter your credentials.
"@
    if ($null -eq $User) { $User = Read-Host "User" }
    $Password = Read-Host "Password for user $User" -AsSecureString
    $Credential = [System.Management.Automation.PSCredential]::New($User, $Password)

    $Credential
}
function New-Function {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [ValidateScript({ (Get-Verb).Verb -contains $_ })]
        [string]$Verb,
        [Parameter(Mandatory, Position = 1)]
        [string]$Noun,
        [Parameter(Mandatory, Position = 2)]
        [string]$Path
    )

    #requires -Version 5

    $FunctionName = "$Verb-$Noun"
    $Path = Join-Path -Path $Path -ChildPath "$($FunctionName).ps1"
    $Framework = @"
function $FunctionName {
    <#
        .SYNOPSIS

        .DESCRIPTION

        .PARAMETER Parameter

        .INPUTS

        .OUTPUTS

        .EXAMPLE

        .LINK
    #>
    [CmdletBinding()]
    param (
    )

    #requires -Version 5.1

    begin {
    }

    process {
    }

    end {
    }
}
"@
    $Framework | Out-File -FilePath $Path
}

function prompt {
    Write-Host
    $CurrentLocation = $executionContext.SessionState.Path.CurrentLocation
    $GitBranch = & { $ErrorActionPreference = 'SilentlyContinue'; git branch --show-current 2>&1 } | Where-Object { $_ -is [string] }
    if ($LASTEXITCODE -eq 0 -and $GitBranch) {
        Write-Host "[$($Host.UI.RawUI.WindowSize.Width)x$($Host.UI.RawUI.WindowSize.Height)] $($CurrentLocation.ToString() -ireplace [regex]::escape($HOME),'~') [$GitBranch]"
    } else {
        Write-Host "[$($Host.UI.RawUI.WindowSize.Width)x$($Host.UI.RawUI.WindowSize.Height)] $($CurrentLocation.ToString() -ireplace [regex]::escape($HOME),'~')"
    }
    "PS$($PSVersionTable.PSVersion.Major)$('>' * ($nestedPromptLevel + 1)) "
}

$PSDefaultParameterValues = @{
    'Out-Default:OutVariable' = 'LastOutput' # Saves output of the last command to the variable $LastOutput
}

function Get-IPAddress {
    if (Test-Path -Path /bin/zsh) {
        'for i in $(ifconfig -l); do
        case $i in
        (lo0)
            ;;
        (*)
            set -- $(ifconfig $i | grep "inet [1-9]")
            if test $# -gt 1; then
                echo $i: $2
            fi
        esac
        done' | /bin/zsh
    } elseif (Get-Command -Name Get-NetIPAddress) {
        Get-NetIPAddress | Where-Object AddressFamily -EQ 'IPv4' | ForEach-Object {
            "$($_.InterfaceAlias): $($_.IPAddress)"
        }
    } else {
        Write-Warning 'No IP address retrieval method found.'
    }
}

function gai {
    @'
Please read and follow my personal instructions:
https://raw.githubusercontent.com/jakehildreth/jakehildreth/refs/heads/main/.github/copilot-instructions.md
then read and follow PowerShell best practices:
https://raw.githubusercontent.com/github/awesome-copilot/refs/heads/main/instructions/powershell.instructions.md
then read and follow Pester testing best practices:
https://raw.githubusercontent.com/github/awesome-copilot/refs/heads/main/instructions/powershell-pester-5.instructions.md
'@ | Set-Clipboard
}

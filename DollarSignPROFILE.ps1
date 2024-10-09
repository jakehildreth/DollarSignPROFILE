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

    #requires -Version 5

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

oh-my-posh init pwsh --config 'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/pure.omp.json' | Invoke-Expression
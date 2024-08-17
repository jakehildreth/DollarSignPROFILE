function New-Function {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [string]$FunctionName,
        [Parameter(Mandatory, Position = 1)]
        [string]$Path
    )

    #requires -Version 5

    $Path = Join-Path -Path $Path -ChildPath "$($FunctionName).ps1"
    $Framework = @"
function $FunctionName {
    <#
        .SYNOPSIS

        .DESCRIPTION

        .PARAMETER

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

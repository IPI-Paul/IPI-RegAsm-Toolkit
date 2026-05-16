function New-RegAsmContext {
    param (
        [string[]]$DllName,
        [string]$OutputPath,
        [string]$FindPath,
        [string]$Replacepath,
        [ValidateSet("Full", "PathOnly", "Diff", "Unregister")]
        [string]$ExportMode = "Full"
    )

    [PSCustomObject]@{
        DllName     = $DllName
        OutputPath  = $OutputPath
        FindPath    = $FindPath
        Replacepath = $Replacepath
        ExportMode  = $ExportMode
        Cancel      = $false
        Progress    = 0
    }
}

Export-ModuleMember -Function New-RegAsmContext
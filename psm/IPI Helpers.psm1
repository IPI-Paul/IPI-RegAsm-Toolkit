function Convert-ToRegPath {
    param (
        $psPath, 
        [string]$sep = ""
    )

    return $psPath -replace ".*Registry::", "" `
                   -replace "HKEY_CLASSES_ROOT", "HKCR$sep" `
                   -replace "HKEY_LOCAL_MACHINE", "HKLM$sep" `
                   -replace "HKEY_CURRENT_USER", "HKCU$sep"
}
function Get-Error {
    param ($Err)

    return "Error: $($Err.Exception.Message) `nType: $($Err.Exception.GetType().FullName) `nLine: $($Err.InvocationInfo.ScriptLineNumber)" + `
           "`nCode: $($Err.InvocationInfo.Line)"
}

Export-ModuleMember -Function Convert-ToRegPath, Get-Error
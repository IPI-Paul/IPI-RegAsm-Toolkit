function Set-Path {
    param ($path, $find, $relocate, $export=$false, $logger, $log)

    try {
        if ($path -match "/" -and -not ($find -match "/")) {
            $find       = ($find -replace "\\", "/")
            $relocate   = ($relocate -replace "\\", "/")
        } elseif ($path -match "\\\\" -and -not ($find -match "\\\\")) {
            $find       = ($find -replace "\\", "\\")
            $relocate   = ($relocate -replace "\\", "\\")
        }
        
        if ($find -and $relocate -and $path -like "*$find*") {
            if (-not $export) {
                $logger.Invoke("Original Path: $path")
                & $log "Green"
            }

            return $path -replace [regex]::Escape($find), $relocate
        }

        $logger.Invoke("Not Found: $path `nFind: $find")
        & $log "DarkRed" -Bold:$true

        return $path
    } catch {
        $logger.Invoke((Get-Error($_)))
        & $log "DarkRed" -Bold:$true
    }
}

Export-ModuleMember -Function Set-Path
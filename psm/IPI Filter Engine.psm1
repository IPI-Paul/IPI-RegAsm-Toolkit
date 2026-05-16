function Select-Keys {
    param ($keys, $context, $logger, $log)

    $logger.Invoke("Filter Mode: $($context.ExportMode)")
    & $log "DarkBlue" -Bold:$true

    switch ($context.ExportMode) {
        "Full" {
            return $keys
        }

        "PathOnly" {
            return $keys.GetEnumerator() | Where-Object {
                $_.CodeBase -like "*$($context.FindPath -replace '\\', '/')*" -or $_.Default -like "*$($context.FindPath -replace '\\', '/')*" -or `
                ($_.CodeBase -replace "\\\\", "/") -like "*$($context.FindPath -replace '\\', '/')*" -or ($_.Default -replace "\\\\", "/") -like "*$($context.FindPath -replace '\\', '/')*" -or `
                ($_.CodeBase -replace "\\\\", "\") -like "*$($context.FindPath)*" -or ($_.Default -replace "\\\\", "\") -like "*$($context.FindPath)*" -or `
                $_.Default -match ($context.DllName -replace "\.dll", "")
            }
        }

        "Diff" {
            # Placeholder for diff logic (expanded later)
            return $keys | Where-Object {
                $_ -match "CLSID|ProgID|TypeLib"
            }
        }
    }
}

Export-ModuleMember -Function Select-Keys
function Get-ParentGUIDs {
    param ($Keys, $logger, $log)

    $allKeys = New-Object System.Collections.Generic.HashSet[string]
    # Process each match found in this specific root key
    foreach ($key in $Keys) {
        # Feature: undoGeneration
        if ($key -match '(^.*?\{[a-fA-F0-9-]+\})') {
            $null = $allKeys.Add("Registry::$($Matches[0] -replace '\[', '')")
        }
    }

    $logger.Invoke("Parent Keys Count: $($allKeys.Count)")
    & $log "Brown" -Italic:$true

    return ($allKeys | Sort-Object -Unique)
}

function New-UndoFile {
    param ($keys, $output, $logger, $log)

    if ($keys) {
        "Windows Registry Editor Version 5.00`r`n" | 
            Out-File $output -Encoding ascii

        foreach ($key in (@($keys) | Sort-Object -Descending)) {
            $reg = Convert-ToRegPath $key
            Add-Content $output "[-$reg]"
        }
    } else {
        $logger.Invoke("No registry keys found!")
        & $log "DarkRed" -Bold:$true
    }
}

Export-ModuleMember -Function Get-ParentGUIDs, New-UndoFile
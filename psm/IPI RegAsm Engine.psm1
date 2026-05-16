Import-Module $Config.FilterEngine -Force
Import-Module $Config.Helpers -Force
Import-Module $Config.PathRewrite -Force
Import-Module $Config.RegistryExport -Force
Import-Module $Config.RegistryScanner -Force
Import-Module $Config.RegistryUndo -Force

function Invoke-RegAsmExport {
    param ($context, $logger, $log)

    if (!$settings) {
        $logger.Invoke("Config not loaded!)")
        & $log "DarkBlue" -Bold:$true
        return
    }

    $allGuids = New-Object System.Collections.Generic.HashSet[string]
    
    $logger.Invoke("Engine Started - Mode: $($context.ExportMode)")
    & $log "DarkBlue" -Bold:$true

    # 1. Find CLSIDs
    $clsids = Find-RegAsmGuids `
        -dll $context.DllName `
        -logger $logger `
        -log $log
        
    $logger.Invoke("CLSIDs: $($clsids.CLSIDs.Count) `nKeys: $($clsids.AllKeys.Count)")
    & $log "Green" -Italic:$true

    $clsids = ($clsids | Where-Object {$_.CLSIDs}) 

    $logger.Invoke(($clsids.CLSIDs | Format-Table -AutoSize | Out-String))
    & $log "DarkGreen"

    if ($context.ExportMode -in @("Full", "Unregister") -and $clsids.CLSIDs.Count -gt 0) {
        foreach ($guid in $clsids.CLSIDs.CLSID) { 
            $null = $allGuids.Add($guid) 
        }

        $logger.Invoke("Getting Missing GUIDs")
        & $log "Purple" -Bold:$true

        if (Test-Path $context.DllName) {
            $dll = $context.DllName
        } else {
            $dllPath    = [regex]::Match($context.DllName,  "(.*)\.").Groups[1].Value
            $dll        = ((($clsids.CLSIDs.Codebase | `
                            Where-Object { $_ -like "*$dllPath.dll"} | `
                            Select-Object -First 1) `
                            -replace "/", "\") `
                            -replace "\\\\", "\") `
                            -replace "file:\\\\"
        }

        $logger.Invoke("DLL: $dll")
        & $log "DarkGreen" -Italic$true

        try {
            $guids = Get-AllGuidsFromFile $dll $clsids.CLSIDs.CLSID $logger $log
        } catch {
            $logger.Invoke((Get-Error($_)))
            & $log "DarkRed" -Bold:$true
        }

        $logger.Invoke("Getting Missing GUID Paths")
        & $log "Purple" -Bold:$true

        try {
            $missing = (Find-RegAsmMissingGuids $guids $logger $log) | Where-Object { $_ -like 'HKEY*'}
        } catch {
            $logger.Invoke((Get-Error($_)))
            & $log "DarkRed" -Bold:$true
        }

        foreach ($guid in $missing) { 
            $null = $allGuids.Add($guid) 
        }
    }

    if ($context.ExportMode -eq "Unregister") {
        return $allGuids
    }

    # 2. Apply export mode filter
    $clsids.CLSIDs = Select-Keys `
        -keys $clsids.CLSIDs `
        -context $context `
        -logger $logger `
        -log $log

    if ($clsids.CLSIDs) {
        $logger.Invoke("After filtering: $($clsids.CLSIDs.Count) Class IDs")
        & $log "Green" -Italic:$true
    }

    if ($clsids.CLSIDs) {
        if ($context.FindPath -and $context.ReplacePath -and $settings.features.pathRewrite) {
            $logger.Invoke("Path rewrite enabled")
            & $log "DarkBlue" -Bold:$true

            foreach ($cls in $clsids.CLSIDs.GetEnumerator()) {
                if ($cls.CodeBase) { 
                    $cls.CodeBase = Set-Path `
                                -path $cls.CodeBase `
                                -find ($context.FindPath -replace '\0', '').Trim() `
                                -relocate ($context.ReplacePath -replace '\0', '').Trim() `
                                -logger $logger `
                                -log $log

                    $logger.Invoke("Path relocated to: $($cls.CodeBase)")
                    & $log "Green" -Italic:$true 
                }
                if($cls.Default -and $cls.Default -match '^([a-zA-Z]:|file:///).*') {
                    $cls.Default = Set-Path `
                                -path $cls.Default `
                                -find ($context.FindPath -replace '\0', '').Trim() `
                                -relocate ($context.ReplacePath -replace '\0', '').Trim() `
                                -logger $logger `
                                -log $log

                    $logger.Invoke("Path relocated to: $($cls.Default)")
                    & $log "Green" -Italic:$true 
                }
            }

            $logger.Invoke("Exporting to reg file: $($context.OutputPath)")
            & $log "DarkBlue" -Bold:$true

            try {
                Export-RegFileWithClsidsRewrite `
                    -keys $clsids.CLSIDs `
                    -output $context.OutputPath `
                    -Find ($context.FindPath -replace '\0', '').Trim() `
                    -Relocate ($context.ReplacePath -replace '\0', '').Trim() `
                    -logger $logger `
                    -log $log 

                if ($settings.features.undoGeneration) {
                    $logger.Invoke("Exporting to reg undo file: $(($context.OutputPath -replace "\.reg", "-undo.reg"))")
                    & $log "DarkBlue" -Bold:$true

                    Export-RegFileWithClsidsRewrite `
                        -keys $clsids.CLSIDs `
                        -output ($context.OutputPath -replace "\.reg", "-undo.reg") `
                        -Find ($context.FindPath -replace '\0', '').Trim() `
                        -Relocate ($context.ReplacePath -replace '\0', '').Trim() `
                        -Undo $true `
                        -logger $logger `
                        -log $log
                }
            } catch {
                $logger.Invoke((Get-Error($_)))
                & $log "DarkRed" -Bold:$true
            }
        } else {
            try {
                $logger.Invoke("Exporting to reg file: $($context.OutputPath)")
                & $log "DarkBlue" -Bold:$true

                if ($context.ExportMode -eq "PathOnly") {
                    Export-RegFileWithClsidsRewrite `
                        -keys $clsids.CLSIDs `
                        -output $context.OutputPath `
                        -Find ""  `
                        -Relocate "" `
                        -Undo $true `
                        -logger $logger `
                        -log $log
                } else {
                    # 3. Export
                    Export-RegFile -keys $allGuids -output $context.OutputPath -logger $logger -log $log

                    if ($settings.features.undoGeneration) {
                        $logger.Invoke("Exporting to reg undo file: $(($context.OutputPath -replace "\.reg", "-undo.reg"))")
                        & $log "DarkBlue" -Bold:$true

                        # 4. Undo generation
                        New-UndoFile -keys $allGuids -output ($context.OutputPath -replace "\.reg", "-undo.reg") -logger $logger -log $log
                    }
                }
            } catch {
                $logger.Invoke((Get-Error($_)))
                & $log "DarkRed" -Bold:$true
            }
        }
        $logger.Invoke("Engine complete")
        & $log "Purple" -Bold:$true
    } else {
        $logger.Invoke("No registry keys found!")
        & $log "DarkRed" -Bold:$true
    }
}

Export-ModuleMember -Function Invoke-RegAsmExport, New-RegAsmContext, Convert-ToRegPath, Get-Error, Set-Path, Get-ParentGUIDs, New-UndoFile, Find-RegAsmMissingGuids
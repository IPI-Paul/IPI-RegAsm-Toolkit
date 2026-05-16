function Unregister-DLL {
    param (        
        [Parameter(Mandatory)]
        [scriptblock]$export,
        [Parameter(Mandatory)]
        [PSObject[]]$context,
        [scriptblock]$logger,
        [scriptblock]$log
    )

    $dll = (Split-Path -Leaf $context.DllName)
    $reg = (Split-Path -Leaf $context.OutputPath)
    $FileName = "$([System.IO.Path]::GetFileNameWithoutExtension($reg)) Unregister Backup $([datetime]::Now.ToString('yyyy-MM-dd HHmmss')).reg"
    $uContext = [PSCustomObject]@{
        DllName     = $dll
        OutputPath  = Join-Path (Split-Path $context.OutputPath) $FileName
        ExportMode  = $context.ExportMode
    }
    
    $uContext.ExportMode = "Full"
    
    $logger.Invoke("Backing up DLL keys for: $($uContext.DllName)") 
    & $log "Purple" -Bold:$true

    & $export `
        -context $uContext `
        -logger $logger `
        -log $log

    # Locate RegAsm
    $regAsm64 = "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\regasm.exe"
    $regAsm32 = "$env:SystemRoot\Microsoft.NET\Framework\v4.0.30319\regasm.exe"

    $logger.Invoke("Unregistering DLL...") 
    & $log "DarkBlue" -Bold:$true
    
    # Run De-Registration (unregisters both the Class and the Type Library)
    & $regAsm64 $context.DllName /unregister /tlb /silent
    & $regAsm32 $context.DllName /unregister /tlb /silent

    $logger.Invoke("Checking to see if all keys removed...") 
    & $log "Purple" -Bold:$true

    $uContext.ExportMode = "Unregister"

    function Remove-RelatedKeys {
        param (
            [string]$msg,
            [switch]$removePrefix
        )

        $keys = & $export `
            -context $uContext `
            -logger $logger `
            -log $log

        if ($keys.Count -ne 0) {
            try {
                $undoKeys = Get-ParentGUIDs `
                                -Keys $keys `
                                -logger $logger `
                                -log $log
            } catch {
                $logger.Invoke((Get-Error($_)))
                & $log "DakRed" -Bold:$true
            }

            $logger.Invoke($msg)
            & $log "DarkRed" -Bold:$true

            foreach ($key in ($undoKeys.GetEnumerator())) {
                if ($removePrefix) {
                    $logger.Invoke("$($key -replace 'Registry::', 'Computer\')")
                } else {
                    $logger.Invoke("$key")
                }
                & $log "Red" -Italic:$true
            }
        }
        return $keys
    }

    $keys = Remove-RelatedKeys -msg "The following orphaned keys have not been removed by the unregister command and an attempt to remove them will follow:"
    
    if ($keys.Count -ne 0) {
        foreach ($key in ($undoKeys.GetEnumerator())) {
            Remove-Item -Path $key -Recurse -Force
        }

        $logger.Invoke("Doing a final Check to see if all keys removed...") 
        & $log "Purple" -Bold:$true

        $msg = "The following orphaned keys have not been removed by the remove command. " + `
                "`nYou will need to open registry editor and copy/paste them into the address bar over " + `
                "`nComputer\* to navigate to that key and delete it manually."

        $keys = Remove-RelatedKeys -msg $msg -removePrefix
    }

    $logger.Invoke("Unregistration complete: $($context.OutputPath)")
    & $log "DarkCyan" -Bold:$true
}

Export-ModuleMember -Function Unregister-DLL
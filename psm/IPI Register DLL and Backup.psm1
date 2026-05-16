function Publish-DLL {
    param (   
        [Parameter(Mandatory)]
        [PSObject[]]$context,
        [Parameter(Mandatory)]
        [scriptblock]$export,
        [bool]$backupOnly,
        [scriptblock]$logger,
        [scriptblock]$log
    )

    if (-not $backupOnly) {
        $logger.Invoke("Registering DLL: $($context.DllName)") 
        & $log "DarkBlue" -Bold:$true

        # Locate RegAsm
        $regAsm64 = "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\regasm.exe"
        $regAsm32 = "$env:SystemRoot\Microsoft.NET\Framework\v4.0.30319\regasm.exe"

        $logger.Invoke("Registering DLL and generating TypeLib...") 
        & $log "DarkBlue" -Bold:$true
        
        # Run Registration (Registers both the Class and the Type Library)
        & $regAsm64 $context.DllName /codebase /tlb /silent
        & $regAsm32 $context.DllName /codebase /tlb /silent

        $logger.Invoke("Registration complete: $($context.DllName)")
        & $log "DarkCyan" -Bold:$true
    }
    
    $logger.Invoke("Backing up DLL keys for: $($context.DllName)") 
    & $log "Purple" -Bold:$true

    $dll = (Split-Path -Leaf $context.DllName)
    $reg = (Split-Path -Leaf $context.OutputPath)
    $FileName = "$([System.IO.Path]::GetFileNameWithoutExtension($reg)) Register Backup $([datetime]::Now.ToString('yyyy-MM-dd HHmmss')).reg"
    $uContext = [PSCustomObject]@{
        DllName     = $dll
        OutputPath  = Join-Path (Split-Path $context.OutputPath) $FileName
        ExportMode  = $context.ExportMode
    }
    
    $uContext.ExportMode = "Full"

    & $export `
        -context $uContext `
        -logger $logger `
        -log $log

    $logger.Invoke("Backup complete: $FileName")
    & $log "DarkCyan" -Bold:$true
}

Export-ModuleMember -Function Publish-DLL
function Get-AllDllGuids {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [scriptblock]$logger,
        [scriptblock]$log
    )
    
    try {
        # Add the type to the current session
        if (-not ([System.Management.Automation.PSTypeName]"Win32.OleAut32").Type) {
            $logger.Invoke("Loading C# Module: $($Config.OleAut32)")
            & $log "Purple" -Italic:$true

            Add-Type -TypeDefinition (Get-Content $Config.OleAut32 -Raw)
        }

        $fullPath   = Resolve-Path $Path
        $typeLib    = $null
    } catch {
        $logger.Invoke((Get-Error($_)))
        & $log "DarkRed" -Bold:$true
    }

    try {
        # Load the type library from the DLL
        [Win32.OleAut32]::LoadTypeLib($fullPath, [ref]$typeLib)

        $logger.Invoke("Loading type library from DLL: $fullPath")
        & $log "Purple" -Italic:$true

        # Get TypeLib GUID
        $libAttrPtr = [IntPtr]::Zero
        $typeLib.GetLibAttr([ref]$libAttrPtr)
        $libAttr    = [System.Runtime.InteropServices.Marshal]::PtrToStructure($libAttrPtr, [type][System.Runtime.InteropServices.ComTypes.TYPELIBATTR])

        $logger.Invoke("--- Type Library ---")
        & $log "DarkCyan" -Bold:$true

        $msg = [PSCustomObject]@{
            Type = "TypeLib"
            Name = (Split-Path $fullPath -Leaf)
            GUID = $libAttr.guid
        } | Format-Table

        $logger.Invoke(($msg | Out-String))
        & $log "DarkGreen"

        $typeLib.ReleaseTLibAttr($libAttrPtr)

        # Iterate through all types to find CLSIDs and Interfaces
        $logger.Invoke("--- Classes (CLSID) and Interfaces (IID) ---")
        & $log "DarkCyan" -Bold:$true

        $results = for ($i = 0; $i -lt $typeLib.GetTypeInfoCount(); $i++) {
            $typeInfo = $null
            $typeLib.GetTypeInfo($i, [ref]$typeInfo)

            $attrPtr    = [IntPtr]::Zero
            $typeInfo.GetTypeAttr([ref]$attrPtr)
            $attr       = [System.Runtime.InteropServices.Marshal]::PtrToStructure($attrPtr, [type][System.Runtime.InteropServices.ComTypes.TYPEATTR])

            $name           = $null
            $doc            = $null
            $helpContext    = 0
            $helpFile       = $null
            $typeInfo.GetDocumentation(-1, [ref]$name, [ref]$doc, [ref]$helpContext, [ref]$helpFile)

            # Map TypeKind to readable string (5 = Coclass/CLSID, 3 = Interface)
            $kind = switch ($attr.typekind) {
                "COCLASS" { "CLSIAD" }
                "INTERFACE" { "Interface (IID)" }
                "DISPATCH" { "DispInterface" }
                Default { $attr.typekind.ToString() }
            }

            [PSCustomObject]@{
                Type = $kind
                Name = $name
                GUID = $attr.guid
            }

            $typeInfo.ReleaseTypeAttr($attrPtr)
        }

        $msg = ($results | Format-Table -AutoSize)
        $logger.Invoke(($msg | Out-String))
        & $log "DarkGreen"

        return $results
    } catch {
        $logger.Invoke((Get-Error($_)))
        & $log "DarkRed" -Bold:$true
    }
    # Usage:
    # Get-AllDllGuids -Path "C:\Windows\System32\shell32.dll"
}

function Get-AllGuidsFromFile {
    param (
        [Parameter(Mandatory=$true)]
        $Path,
        [PSObject[]]$keys,
        [scriptblock]$logger,
        [scriptblock]$log
    )

    if (-not (Test-Path $Path)) {
        $logger.Invoke("File not found: $Path")
        & $log "DarkRed" -Bold:$true
        return
    }

    try {
        $guids = (Get-ParentGUIDs $keys $logger $log | ForEach-Object {
            [regex]::Match($_, "\{([a-zA-Z0-9-]+)\}").Groups[1].Value
        } | Sort-Object -Unique) | ForEach-Object {
            [PSCustomObject]@{
                GUID = $_
                Type = "Detected Pattern in Registry"
            }
        }
    } catch {
        $logger.Invoke((Get-Error($_)))
        & $log "DarkRed" -Bold:$true
    }

    $logger.Invoke(($guids | Format-Table -AutoSize | Out-String))
    & $log "DarkGreen"

    $fullPath = Resolve-Path $Path
    
    $logger.Invoke("Scanning $fullPath for GUIID patterns...")
    & $log "DarkCyan" -Bold:$true

    # GUID Regex Pattern
    $guidPattern = "[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}"

    # Read file as strings (captures both ASCII and Unicode embedded strings)
    # Using -Raw and then matching is faster for large DLLs
    $content = [System.IO.File]::ReadAllText($fullPath)

    $foundGuids = [regex]::Matches($content, $guidPattern)
    
    if ($foundGuids) {
        $msg = ($foundGuids | Select-Object -ExpandProperty Value -Unique | Where-Object { $_ -notin $guids.GUID }) | ForEach-Object {
            [PSCustomObject]@{
                GUID = $_
                Type = "Detected Pattern in File"
            }
        } | Format-Table -AutoSize | Out-String

        $logger.Invoke($msg.Trim())
        & $log "DarkGreen"

        return ($foundGuids | Select-Object -ExpandProperty Value -Unique | Where-Object { $_ -notin $guids.GUID })
    } else {
        $logger.Invoke("No GUIDs found.")
        & $log "DarkRed" -Bold:$true
    }
}

Export-ModuleMember -Function Get-DllGuids, Get-AllDllGuids, Get-AllGuidsFromFile
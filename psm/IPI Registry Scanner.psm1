function Find-RegAsmGuids {
    param (
        [string]$dll, 
        $logger, 
        $log
    )

    $clsLocations = (Get-PathLocations -Type "CLSID")

    $typeLocations = (Get-PathLocations -Type "TypeLib")

    $clsidMatches   = New-Object 'System.Collections.Generic.Dictionary[string, object]'
    $allKeys        = New-Object System.Collections.Generic.HashSet[string]

    function Add-KeyRecursive {
        param ($key, $clsMatch)

        if (-not $key) { return }

        if ($allKeys.Add($key.Name)) {
            foreach ($subName in $key.GetSubKeyNames()) {
                try {
                    $child = $key.OpenSubKey($subName)
                    if ($child) {
                        Add-KeyRecursive $child 
                        $child.Close()
                    }
                } catch {}
            }
        }  else {
            if ($clsMatch) {
                try {
                    $default = (Get-ItemPropertyValue -Path ("Registry::$($key.Name)")  -Name "(default)") 
                } catch {}
                if ($default -and $default -match '^([a-zA-Z]:|file:///).*') {
                    $clsidMatches[$key.Name.ToString().Trim()] = [PSCustomObject]@{
                                                                CodeBase = $null
                                                                Default = $default
                                                            }
                } 
                foreach ($subkName in $key.GetSubKeyNames()) {
                    $childKey = $key.OpenSubKey($subkName)
                    if ($childKey) {
                        Add-KeyRecursive $childKey $clsMatch
                        $childKey.Close()
                    }
                }
            }
        }
    }
    
    foreach ($loc in $clsLocations) {
        $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey($loc.Hive, $loc.View)

        $clsidKey = if ($loc.Path) {
            $baseKey.OpenSubKey($loc.Path)
        } else {
            $baseKey.OpenSubKey("CLSID")
        }

        IF (-not $clsidKey) { continue }

        $logger.Invoke("Scanning $($loc.Hive) [$($loc.View)] $($loc.Path)")
        & $log "DarkBlue" -Bold:$true
        
        foreach ($subName in $clsidKey.GetSubKeyNames()) {
            $subKey = $clsidKey.OpenSubKey($subName)
            if (-not $subKey) { continue }

            $inproc = $subKey.OpenSubKey("InprocServer32")
            if (-not $inproc) { 
                $subKey.Close()
                continue 
            }

            try {
                $codeBase = $inproc.GetValue("CodeBase")

                if ($codeBase) {                    
                    if ($codeBase -match $dll -or $codeBase -match ($dll -replace "\.dll", "") -and "$dll" -ne "") {
                        # Found match
                        $clsidMatches[$subKey.Name] = [PSCustomObject]@{
                                                                            CodeBase    = $codeBase
                                                                            Default     = $null
                                                                            Type        = "CLSID"
                                                                        }

                        # Add full CLSID tree
                        Add-KeyRecursive $subKey
                        
                        Expand related keys
                        $progId = $subKey.GetValue("ProgID")
                        if ($progId) {
                            $progKey = $baseKey.OpenSubKey($progId)
                            if ($progKey) {
                                Add-KeyRecursive $progKey
                                $progKey.Close()
                            }
                        }

                        $vip = $subKey.GetValue("VersionIndependentProgID")
                        if ($vip) {
                            $vipKey = $baseKey.OpenSubKey($vip)
                            if ($vipKey) {
                                Add-KeyRecursive $vipKey
                                $vipKey.Close()
                            }
                        }

                        $typeLib = $subKey.GetValue("TypeLib")
                        if ($typeLib) {
                            $tlPath = "TypeLib\$typeLib"
                            $tlkey  = $baseKey.OpenSubKey($tlPath)
                            if ($tlkey) {
                                Add-KeyRecursive $tlkey
                                $tlkey.Close()
                            }
                        }
                        
                        break
                    }
                }
            } catch {
                $logger.Invoke((Get-Error($_)))
                & $log "DarkRed" -Bold:$true
            } finally {
                $inproc.Close()
            }

            $subKey.Close()
        }

        $clsidKey.Close()
        $baseKey.Close()
    }
    
    foreach ($loc in $typeLocations) {
        $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey($loc.Hive, $loc.View)

        $clsidKey = if ($loc.Path) {
            $baseKey.OpenSubKey($loc.Path)
        } else {
            $baseKey.OpenSubKey("CLSID")
        }

        IF (-not $clsidKey) { continue }

        $logger.Invoke("Scanning $($loc.Hive) [$($loc.View)] $($loc.Path)")
        & $log "DarkBlue" -Bold:$true

        foreach ($subName in $clsidKey.GetSubKeyNames()) {
            $subKey = $clsidKey.OpenSubKey($subName)
            
            if (-not $subKey) { continue }

            $inproc = $subKey.OpenSubKey("InprocServer32")

            if (-not $inproc) {             
                try {
                    try {
                        $subKey = $subKey.OpenSubKey("1.0")
                        if (-not $subKey) { continue }
                        $codeBase = (Get-ItemPropertyValue -Path ("Registry::$($subKey.Name)")  -Name "(default)")
                    } catch {}

                    if ($codeBase) {                    
                        if ($codeBase -match $dll -or $codeBase -match ($dll -replace "\.dll", "") -and "$dll" -ne "") {
                            # Found match
                            if ($codeBase -match '^([a-zA-Z]:|file:///).*') {
                                $clsidMatches[$subKey.Name.ToString().Trim()] = [PSCustomObject]@{
                                                                                    CodeBase    = $null
                                                                                    Default     = $codeBase
                                                                                    Type        = "TypeLib"
                                                                                }
                            }
                            # Add full CLSID tree
                            Add-KeyRecursive $subKey
                            
                            # Expand related keys
                            $verKey = $subKey.OpenSubKey("0")
                            if ($verKey) {
                                Add-KeyRecursive $verKey $true
                                $verKey.Close()
                            }
                            $hlpKey = $subKey.OpenSubKey("HELPDIR")
                            if ($hlpKey) {
                                Add-KeyRecursive $hlpKey $true
                                $hlpKey.Close()
                            }
                            
                            break
                        }
                    }
                } catch {
                    $logger.Invoke((Get-Error($_)))
                    & $log "DarkRed" -Bold:$true
                } finally {
                    # $inproc.Close()
                }
            }

            $subKey.Close()
        }

        $clsidKey.Close()
        $baseKey.Close()
    }
    
    return [PSCustomObject]@{
        CLSIDs  = @($clsidMatches.GetEnumerator() | 
                    ForEach-Object { 
                        [PSCustomObject]@{
                            CLSID       = $_.Key
                            CodeBase    = $_.Value.CodeBase
                            Default     = $_.Value.Default
                            Type        = $_.Value.Type
                        }
                    } | Sort-Object CLSID
                )
        AllKeys = $allKeys | Sort-Object -Unique
    }
}

function Find-RegAsmMissingGuids {
    param (
        [Parameter(Mandatory)]
        [PSObject[]]$Guids,
        [scriptblock]$logger,
        [scriptblock]$log
    )
    
    $foundKeys = New-Object System.Collections.Generic.HashSet[string]

    foreach ($loc in (Get-PathLocations)) {
        $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey($loc.Hive, $loc.View)

        if ($loc.Path) {
            $logger.Invoke("Scanning $($loc.Hive) [$($loc.View)] $($loc.Path)")
            & $log "DarkBlue" -Bold:$true

            try {
                $subKey = $baseKey.OpenSubKey($loc.Path)
                $names  = $subKey.GetSubKeyNames()

                foreach ($guid in $Guids) {
                    foreach ($name in $names) {
                        if ($name -like "*$guid*") {
                            $foundKeys.Add("$($subKey.Name)\$name")
                            break
                        }
                    }
                }

                $subKey.Close()
            } catch {
                $logger.Invoke((Get-Error($_)))
                & $log "DarkRed" -Bold:$true
            }
        }

        $baseKey.Close()
    }
                
    $logger.Invoke(($foundKeys | ForEach-Object { @{Keys = $_} } | Format-Table -AutoSize | Out-String))
    & $log "DarkGreen" 

    return $foundKeys
}

function Get-PathLocations {
    param (
        [ValidateSet("CLSID", "TypeLib", $null)]
        [string]$Type
    )

    $locations = @(
        @{ Hive = [Microsoft.Win32.RegistryHive]::ClassesRoot; View = [Microsoft.Win32.RegistryView]::Default; Path = "CLSID"},
        @{ Hive = [Microsoft.Win32.RegistryHive]::CurrentUser; View = [Microsoft.Win32.RegistryView]::Default; Path = "Software\Classes\CLSID"},
        @{ Hive = [Microsoft.Win32.RegistryHive]::LocalMachine; View = [Microsoft.Win32.RegistryView]::Registry64; Path = "Software\Classes\CLSID"},
        @{ Hive = [Microsoft.Win32.RegistryHive]::LocalMachine; View = [Microsoft.Win32.RegistryView]::Registry32; Path = "Software\Classes\CLSID"},
        @{ Hive = [Microsoft.Win32.RegistryHive]::LocalMachine; View = [Microsoft.Win32.RegistryView]::Registry64; Path = "Software\Classes\Wow6432Node\CLSID"},
        @{ Hive = [Microsoft.Win32.RegistryHive]::ClassesRoot; View = [Microsoft.Win32.RegistryView]::Default; Path = "Interface"},
        @{ Hive = [Microsoft.Win32.RegistryHive]::CurrentUser; View = [Microsoft.Win32.RegistryView]::Default; Path = "Software\Classes\Interface"},
        @{ Hive = [Microsoft.Win32.RegistryHive]::CurrentUser; View = [Microsoft.Win32.RegistryView]::Default; Path = "Software\Classes\WOW6432Node\Interface"},
        @{ Hive = [Microsoft.Win32.RegistryHive]::LocalMachine; View = [Microsoft.Win32.RegistryView]::Registry64; Path = "Software\Classes\Interface"},
        @{ Hive = [Microsoft.Win32.RegistryHive]::LocalMachine; View = [Microsoft.Win32.RegistryView]::Registry32; Path = "Software\Classes\Interface"},
        @{ Hive = [Microsoft.Win32.RegistryHive]::LocalMachine; View = [Microsoft.Win32.RegistryView]::Registry64; Path = "Software\Classes\Wow6432Node\Interface"},
        @{ Hive = [Microsoft.Win32.RegistryHive]::LocalMachine; View = [Microsoft.Win32.RegistryView]::Registry64; Path = "Software\Wow6432Node\Classes\Interface"},
        @{ Hive = [Microsoft.Win32.RegistryHive]::ClassesRoot; View = [Microsoft.Win32.RegistryView]::Default; Path = "TypeLib"},
        @{ Hive = [Microsoft.Win32.RegistryHive]::ClassesRoot; View = [Microsoft.Win32.RegistryView]::Default; Path = "WOW6432Node\TypeLib"},
        @{ Hive = [Microsoft.Win32.RegistryHive]::CurrentUser; View = [Microsoft.Win32.RegistryView]::Default; Path = "Software\Classes\TypeLib"},
        @{ Hive = [Microsoft.Win32.RegistryHive]::LocalMachine; View = [Microsoft.Win32.RegistryView]::Registry64; Path = "Software\Classes\TypeLib"},
        @{ Hive = [Microsoft.Win32.RegistryHive]::LocalMachine; View = [Microsoft.Win32.RegistryView]::Registry32; Path = "Software\Classes\TypeLib"},
        @{ Hive = [Microsoft.Win32.RegistryHive]::LocalMachine; View = [Microsoft.Win32.RegistryView]::Registry64; Path = "Software\Classes\Wow6432Node\TypeLib"},
        @{ Hive = [Microsoft.Win32.RegistryHive]::LocalMachine; View = [Microsoft.Win32.RegistryView]::Registry64; Path = "Software\Wow6432Node\Classes\TypeLib"}
    )

    if ($Type) {
        return ($locations | Where-Object { $_.Path -like "*$Type"})
    }

    return $locations
}

Export-ModuleMember -Function Find-RegAsmGuids, Find-RegAsmMissingGuids
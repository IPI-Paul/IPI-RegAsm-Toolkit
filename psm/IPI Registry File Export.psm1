function Export-RegFile {
    param (
        [Parameter(Mandatory)]
        [PSObject[]]$keys, # Can be strings or PSCustomObjects with CLSID
        [Parameter(Mandatory)]
        [string]$output,
        $logger,
        $log
    )

    if ($keys) {
        $tmp = @()

        foreach ($k in $keys) {
            # Convert to proper registry path
            $reg = Convert-ToRegPath $k

            # Export to temp file
            $t = [IO.Path]::GetTempFileName()
            reg export "$reg" "$t" /y /reg:64 | Out-Null
            $tmp += $t
        }

        # Write Header and Append registry content, excluding the default header line        
        $content = foreach ($f in $tmp) {
            Get-Content $f -Raw
        }
        $content = $content -replace '(?m)^Windows Registry Editor.*\r?\n?', ''
        $content = "Windows Registry Editor Version 5.00`r`n" + ($content -join "`r`n")
        [System.IO.File]::WriteAllLines($output, $content)

        # Clean up temp files
        $tmp | Remove-Item -Force
    } else {
        $logger.Invoke("No registry keys found!")
        & $log "DarkRed" -Bold:$true
    }
}

function Export-RegFileWithClsidsRewrite {
    param (
        [Parameter(Mandatory)]
        [PSObject[]]$keys, # Can be strings or PSCustomObjects with CLSID
        [Parameter(Mandatory)]
        [string]$output, # Output.reg file
        [Parameter(Mandatory)]$Find, # String to find in CodeBase
        [Parameter(Mandatory)]$Relocate, # Replacement string
        [bool]$Undo = $false,
        $logger,
        $log
    )

    if ($keys) {
        $orig   = @()
        $tmpFiles = @()

        # Export all keys to temp files
        foreach ($k in $keys) {   
            if (-not $Undo) {
                $o = [IO.Path]::GetTempFileName()     
                reg export (Convert-ToRegPath $k.CLSID) "$o" /y /reg:64 | Out-Null
                $orig += $o
            }

            $tempFile = [IO.Path]::GetTempFileName()
            reg export (Convert-ToRegPath $k.CLSID) $tempFile /y /reg:64 | Out-Null
            $tmpFiles += $tempFile
        }

        # Write Header and Append original registry content, excluding the default header line
        if (-not $Undo) {
            foreach ($f in $orig) {
                $content = Get-Content $f -Raw
                $contents += $content -replace '(?m)^Windows Registry Editor.*\r?\n?', ''
            }
            $content = "Windows Registry Editor Version 5.00`r`n" + (($contents | Sort-Object -Unique) -join "`r`n")  
            [System.IO.File]::WriteAllLines(($output -replace "\.reg", "-Original.reg"), $content) 

            # Clean up temp files
            $orig | Remove-Item -Force
        }
            
        # Start new .reg file wirh header
        "Windows Registry Editor Version 5.00`r`n" |
            Out-File $output -Encoding ascii
        
        try {
            # Build a HashSet of CLSIDs for fast lookup
            $clsidSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($obj in $keys) { 
                $value = $obj.CLSID.Trim()
                $objMatch = [regex]::Match($value, '{[^}]+}')
                
                if ($objMatch.Success) {
                    $clsidSet.Add($objMatch.Value.Trim()) | Out-Null
                } else {
                    $logger.Invoke("Warning: Invalid CLSID format: $value")
                    & $log "DarkRed" -Bold:$true
                }
            }
        } catch {
            $logger.Invoke((Get-Error($_)))
            & $log "DarkRed" -Bold:$true
        }

        foreach ($file in $tmpFiles) {
            $lines = Get-Content $file
            $currentClsid = $null
            
            try {
                $lines | ForEach-Object {
                    $line = $_
                    
                    # Detect the current CLSID key section
                    $match = [regex]::Match($line, '^\[(.+)\]')
                    if ($match.Success) {
                        $keyPath = $match.Groups[1].Value

                        # Extract CLSID from path if it matches the CLSID registry structure
                        # Example: HKEY_CLASSES_ROOT\CLSID\{ABC-123}\InprocServer32
                        $clsidMatch = [regex]::Match($keyPath, 'CLSID\\({[^}]+})')
                        $typeLibMatch = [regex]::Match($keyPath, 'TypeLib\\({[^}]+})')
                        if ($clsidMatch.Success) {
                            $currentClsid = $clsidMatch.Groups[1].Value.Trim()
                        } elseif ($typeLibMatch.Success) {
                            $currentClsid = $typeLibMatch.Groups[1].Value.Trim()
                        } else {
                            $currentClsid = $null
                        }

                        # Output the section line unchanged
                        $cls = $line
                    }
                    # Only modify CodeBase if this CLSID is in your list
                    elseif ($currentClsid -and $clsidSet.Contains($currentClsid) -and ($line -match '^\s*"CodeBase"\s*=' -or $line -match '^\s*@\s*="([a-zA-Z]:|file:///).*')) {
                        # Extract existing CodeBase value
                        $value = ($line -split '=', 2)[1].Trim().Trim('"')

                        try {
                            # Rewrite the path using Set-Path
                            if (-not $Undo) {
                                $newValue = Set-Path -path $value -find $Find -relocate $Relocate -export $true -logger $logger -log $log
                            } else {
                                $newValue = $value
                            }
                        } catch {
                            $logger.Invoke((Get-Error($_)))
                            & $log "DarkRed" -Bold:$true
                        }
                        # Rebuild the line
                        $found = if ($line -match '^\s*"CodeBase"\s*=') { '"CodeBase"="' } else {'@="'}
                        "$cls`r`n" + $found + $newValue + '"'
                    } else {
                        # Other lines unchanged
                        # $line
                    }
                } | Add-Content $output
            } catch {
                $logger.Invoke((Get-Error($_)))
                & $log "DarkRed" -Bold:$true
            }
        }

        # Clean up temp files
        $tmpFiles | Remove-Item -Force
    } else {
        $logger.Invoke("No registry keys found!")
        & $log "DarkRed" -Bold:$true
    }
}

Export-ModuleMember -Function Export-RegFile, Export-RegFileWithClsidsRewrite
param (
    [Parameter(Mandatory)]
    [string[]]$Dlls,
    [string]$Output,
    [switch]$SaveLog,
    [ValidateSet("Full", "PathOnly", "Diff", "Register", "BackupOnly", "Unregister")]
    [string]$ExportMode = "Full",
    [string]$Find,
    [string]$Replace
)

if ($Dlls -eq "?") {
    Write-Host @"
    Usage:
        -Dlls       Enter ? to display this help or provide DLL Names separated by 
                    semicolon and surrounded in quotes if containing spaces.
                    To register a DLL or backup its registry, enter full path to the DLL.
        -Output     Output folder path surrounded in quotes if containig spaces.
                    If registering a DLL or backing up its registry, enter full path to 
                    the .reg file to save as.
        -SaveLog    0=False 1=True
        -ExportMode Full        - Saves all registry keys found (Default).
                    PathOnly    - Saves only registry keys containing file and folder paths.
                    Diff        - Logic not yet implemented.
                    Register    - Registers the DLL from the full path given, in the registry.
                    Unregister  - Unregisters the DLL from the full path given, in the registry.
                    BackupOnly  - Backs up the registry items relating to the DLL full path entry.
        -Find       Folder path to look for in registry keys.
        -Replace    Folder path to replace found matches with.
"@
} else {
    Import-Module "$PSScriptRoot\config\Config.psm1" -Force
    $Config = Get-ScriptPaths
    $settings = $Config.DefaultSettings

    Import-Module $Config.RtfLogger -Force
    Import-Module $Config.RegAsmEngine -Force
    Import-Module $Config.ContextModels -Force
    Import-Module $Config.RegisterDLL -Force
    Import-Module $Config.UnregisterDLL -Force
    Import-Module $Config.ExtractDllGuid -Force
    # Import-Module $Config.Helpers -Force

    if (-not $Output -and -not (@("Register", "BackupOnly") -match $ExportMode)) { $Output = $settings.outputFolder }
    
    $FileName = ""

    if (-not ([System.IO.Path]::GetFileName($Output) -match "\.reg") -and @("Register", "BackupOnly") -match $ExportMode) {
        $file = if ($Output -match "\.") {
            ($Output | foreach-object {$_ -replace [regex]::Match($_, "\..*"), ".reg"})
        } else { "$Output.reg" }
        $answer = (Read-Host -Prompt "Do you want me to change the Output Path to: $file (n/y)?")
        if ($answer -eq "y") { 
            $Output = $file
        } else {
            Write-Host "Error: Invalid registry file extension." -ForegroundColor Red
            exit
        }
    }

    $FileName   = "$([System.IO.Path]::GetFileNameWithoutExtension($Output)) $ExportMode $([datetime]::Now.ToString('yyyy-MM-dd HHmmss')).reg"    
    $Script:msg = ""
    $logger     = (New-Logger "" -CLI)
    $log        = (Write-Log "" -CLI -SaveLog $SaveLog -FileName $FileName)
    
    $normalisedPath = (
                        (
                            ($Output -replace "%temp%", $env:TEMP) -replace "%appdata%", $env:APPDATA
                        ) -replace "%username%", $env:USERNAME
                    ) -replace "%userprofile", $env:USERPROFILE

    if (@("Register", "BackupOnly") -match $ExportMode) {
        if (-not (Test-Path $Dlls)) {
            $logger.Invoke("DLL not found at $DLLs")
            & $log "DarkRed" -Bold:$true
            exit
        }
        if ([string]::IsNullOrWhiteSpace($Output)) {
            $logger.Invoke("Output folder not found: $Output")
            & $log "DarkRed" -Bold:$true
            exit
        } elseif (-not (Test-Path (Split-Path $Output))){
            $logger.Invoke("Output folder not found: $Output")
            & $log "DarkRed" -Bold:$true
            exit
        }

        if ($ExportMode -eq "BackupOnly") {
            $logger.Invoke("Backing up Registery for $DLLs")
        } else {
            $logger.Invoke("Registering $DLLs")
        }
        & $log "DarkBlue" -Bold:$true

        try {
            $log = (Write-Log "" -CLI -SaveLog $SaveLog -FileName $FileName)

            $context = New-RegAsmContext `
                -DllName $Dlls[0] `
                -OutputPath $normalisedPath `
                -ExportMode "Full"

            Publish-DLL `
                -export ${function:Invoke-RegAsmExport} `
                -context $context `
                -backupOnly ($ExportMode -eq "BackupOnly") `
                -logger $logger `
                -log $log
        } catch {
            $logger.Invoke((Get-Error($_)))
            & $log "DarkRed" -Bold:$true
        }
    } elseif ($ExportMode -eq "Unregister") {
        $FileName = "$([System.IO.Path]::GetFileNameWithoutExtension($Dlls)) $ExportMode $([datetime]::Now.ToString('yyyy-MM-dd HHmmss')).reg"
        $log = (Write-Log "" -CLI -SaveLog $SaveLog -FileName $FileName)
        $context = New-RegAsmContext `
            -DllName $Dlls `
            -OutputPath $normalisedPath `
            -ExportMode "Unregister"

        Unregister-DLL -export ${function:Invoke-RegAsmExport} -context $context -logger $logger -log $log
    } else {
        foreach ($dll in ($DLLs -split ";").Trim()) {
            $FileName = "$([System.IO.Path]::GetFileNameWithoutExtension($dll)) $ExportMode $([datetime]::Now.ToString('yyyy-MM-dd HHmmss')).reg"
            $log = (Write-Log "" -CLI -SaveLog $SaveLog -FileName $FileName)
            $context = New-RegAsmContext `
                -DllName $dll `
                -OutputPath (Join-Path $normalisedPath $FileName) `
                -FindPath $Find `
                -ReplacePath $Replace `
                -ExportMode $ExportMode

            Invoke-RegAsmExport -context $context -logger $logger -log $log
        }
    }
}
function Get-ToolkitConfig {
    $manifestPath = "$PSScriptRoot\RegAsmToolkit.manifest.json"
    if (Test-Path $manifestPath) {
        return Get-Content $manifestPath -Raw | ConvertFrom-Json
    }
    # Fallback defaults if manifest is missing
    return [PSCustomObject]@{
        runtime = @{
            maxThreads = 1
            useRunspaces = $true
        }
    }
}

function Get-DefaultSettings {
    $settingsPath = "$PSScriptRoot\default.settings.json"
    if (Test-Path $settingsPath) {
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    }
    # Fallback defaults if default settings is missing
    $settings = [PSCustomObject]@{
        outputFolder    = "./outputs/exports"
        logFolder       = "./outputs/logs"
        savedFolder     = "./outputs/saved"
    }

    if ($PSScriptRoot) {
        $rootPath   = Get-Item -LiteralPath "$PSScriptRoot"
        $testPath   = "$rootPath$((Split-Path -Parent ([regex]::Match($settings.outputFolder, '[^\.]+'))[0]))"
        while (-not (Test-Path $testPath) -and $rootPath) {
            $rootPath = (Split-Path -Parent $rootPath)
            $testPath = "$rootPath$((Split-Path -Parent ([regex]::Match($settings.outputFolder, '[^\.]+'))[0]))"
        }
        
        $settings.outputFolder  = Get-Item -LiteralPath "$rootPath$(([regex]::Match($settings.outputFolder, '[^\.]+'))[0])"
        $settings.logFolder     = Get-Item -LiteralPath "$rootPath$(([regex]::Match($settings.logFolder, '[^\.]+'))[0])"
        $settings.savedFolder   = Get-Item -LiteralPath "$rootPath$(([regex]::Match($settings.savedFolder, '[^\.]+'))[0])"
    }
    
    return $settings
}

function Get-LiteralPath {
    param ([string]$path)

    (Get-Item -LiteralPath "$PSScriptRoot\$path")
}

function Get-ScriptPaths {
    $manifest           = Get-ToolkitConfig
    $defaultSettings    = Get-DefaultSettings
    $defaultSettings | Add-Member -NotePropertyName "features" -NotePropertyValue $manifest.features

    [PSCustomObject]@{
        DefaultSettings = $defaultSettings
        Runtime         = $manifest.runtime
        IconHelper      = (Get-LiteralPath "..\cs\IPI Windows Icon Helper.cs")
        WatermarkSvc    = (Get-LiteralPath "..\cs\IPI WPF Place Holder.cs")
        OleAut32        = (Get-LiteralPath "..\cs\IPI Get DLL GUIDs.cs")
        ContextModels   = (Get-LiteralPath "..\psm\IPI Context Models.psm1")
        ExtractDllGuid  = (Get-LiteralPath "..\psm\IPI Extract DLL GUIDs.psm1")
        FilterEngine    = (Get-LiteralPath "..\psm\IPI Filter Engine.psm1")
        Helpers         = (Get-LiteralPath "..\psm\IPI Helpers.psm1")
        PathRewrite     = (Get-LiteralPath "..\psm\IPI Path Rewrite.psm1")
        RegAsmEngine    = (Get-LiteralPath "..\psm\IPI RegAsm Engine.psm1")
        RegisterDLL     = (Get-LiteralPath "..\psm\IPI Register DLL and Backup.psm1")
        UnregisterDLL   = (Get-LiteralPath "..\psm\IPI Unregister DLL.psm1")
        RegistryExport  = (Get-LiteralPath "..\psm\IPI Registry File Export.psm1")
        RegistryScanner = (Get-LiteralPath "..\psm\IPI Registry Scanner.psm1")
        RegistryUndo    = (Get-LiteralPath "..\psm\IPI Registry Undo Generator.psm1")
        RtfLogger       = (Get-LiteralPath "..\psm\IPI Rich Text Logger.psm1")
        RunspaceHost    = (Get-LiteralPath "..\psm\IPI Runspace Host.psm1")
        FolderSelect    = (Get-LiteralPath "..\psm\IPI Windows Folder Select.psm1")
        IconPicker      = (Get-LiteralPath "..\psm\IPI Windows Icon Picker - Icons.psm1")
        PlaceHolder     = (Get-LiteralPath "..\psm\IPI WPF Place Holder.psm1")
        MainWindow      = (Get-LiteralPath "..\xaml\IPI RegAsm Toolkit GUI.xaml")
        Downloads       = (New-Object -ComObject Shell.Application).Namespace('shell:Downloads').Self.Path
    }
}

Export-ModuleMember -Function Get-ToolkitConfig, Get-ScriptPaths
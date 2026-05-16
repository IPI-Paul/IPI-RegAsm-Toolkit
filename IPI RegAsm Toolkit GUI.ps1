Add-Type -AssemblyName PresentationFramework

Import-Module "$PSScriptRoot\config\Config.psm1" -Force
$Config = Get-ScriptPaths

Import-Module $Config.RtfLogger -Force
Import-Module $Config.RunspaceHost -Force
Import-Module $Config.RegAsmEngine -Force
Import-Module $Config.PlaceHolder -Force
Import-Module $Config.IconPicker -Force
Import-Module $Config.FolderSelect -Force
Import-Module $Config.ContextModels -Force
Import-Module $Config.RegisterDLL -Force
Import-Module $Config.UnregisterDLL -Force
Import-Module $Config.ExtractDllGuid -Force

$settings = $Config.DefaultSettings

$xaml   = Get-Content $Config.MainWindow -Raw
$window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$xaml)))

$DllBox         = $window.FindName("DllBox")
$OutputBox      = $window.FindName("OutputBox")
$FindBox        = $window.FindName("FindBox")
$ReplaceBox     = $window.FindName("ReplaceBox")
$ModeBox        = $window.FindName("ModeBox")
$StatusLabel    = $window.FindName("StatusLabel")
$LogBox         = $window.FindName("LogBox")
$btnLibrary     = $window.FindName("btnLibrary")
$btnBrowse      = $window.FindName("btnBrowse")
$btnFind        = $window.FindName("btnFind") 
$btnReplace     = $window.FindName("btnReplace")
$RunBox         = $window.FindName("RunBox")
$OutputBox.Text = $settings.outputFolder

function Update-Watermark {
    Set-WpfWatermark -TextBox $DllBox -Text "Enter Dll Names with Extensions separated with a semicolons (;) or use the browse button to locate a DLL to register/unregister."
    if ($settings.Register) {
        Set-WpfWatermark -TextBox $OutputBox -Text "Use the browse button to pick a file SaveAs location and file name for your backup file or enter it here."
    } else {
        Set-WpfWatermark -TextBox $OutputBox -Text "Use the browse button to pick a file SaveAs location or enter it here."
    }
    Set-WpfWatermark -TextBox $FindBox -Text "Specify the folder location currently used in the DLL Entries for library and help files or leave blank."
    Set-WpfWatermark -TextBox $ReplaceBox -Text "Specify a new folder location if you want to replace the current location or leave blank."
}

$DllBox.add_Loaded({
    Update-Watermark
})

$LogBox.Document.Blocks.Clear()

$btnBrowse.Add_Click({
    if ($settings.Register) {
        $Dialog                 = New-Object Microsoft.Win32.SaveFileDialog
        $Dialog.Filter          = "REG (*.reg)|*.reg"
    } else {
        $Dialog                 = Get-SelectDialog
    }
    $Dialog.InitialDirectory    = Get-Item -LiteralPath $settings.outputFolder
    if ($Dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $OutputBox.Text = if ($settings.Register) { $Dialog.FileName } else { Split-Path $Dialog.FileName }
    }
})

$btnFind.Add_Click({
    $Dialog                     = Get-SelectDialog
    $Dialog.InitialDirectory    = Get-Item -LiteralPath $settings.savedFolder
    if ($Dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $FindBox.Text = Split-Path $Dialog.FileName
    }
})

$btnLibrary.Add_Click({
    $Dialog             = New-Object Microsoft.Win32.OpenFileDialog
    $Dialog.Multiselect = $false
    $Dialog.Filter      = "DLL (*.dll)|*.dll"
    if ($Dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $DLLBox.Text    = $Dialog.FileName
        $OutputBox.Text = ""
        $settings | Add-Member -NotePropertyName "Register" -NotePropertyValue $true
        Update-Watermark
    }
})

$btnReplace.Add_Click({
    $Dialog                     = Get-SelectDialog
    $Dialog.InitialDirectory    = Get-Item -LiteralPath $settings.savedFolder
    if ($Dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $ReplaceBox.Text = Split-Path $Dialog.FileName
    }
})

$LogBox.Add_PreviewMouseLeftButtonDown({
    param ($s, $e)

    $pointer = $LogBox.GetPositionFromPoint($e.GetPosition($LogBox), $true)
    if (-not $pointer) { return }

    # Get the inline element at the click
    $inline = $pointer.Parent
    while ($inline -and -not ($inline -is [System.Windows.Documents.Hyperlink])) {
        $inline = $inline.Parent
    }

    if ($inline -and $inline -is [System.Windows.Documents.Hyperlink]) {
        # Open the URI
        Start-Process $inline.NavigateUri.AbsoluteUri
        $e.Handled = $true
    }
})

$RunBox.Add_SelectionChanged({
    if ($this.SelectedIndex -eq 1) {   
        Write-Log -Window $window -Text "Author Repository:" -Color "DarkBlue" -Bold:$true
        Write-Log -Window $window -Text "https://github.com/IPI-Paul/IPI-RegAsm-Toolkit" `
            -Color "DarkBlue"
    }
    elseif ($this.SelectedIndex -eq 2) {
        $LogBox.Document.Blocks.Clear()
        Reset-Status
    }
    elseif (@(3, 4, 5, 6) -match $this.SelectedIndex) {
        if ([string]::IsNullOrWhiteSpace($DllBox.Text)) {
            Write-Log -Window $window -Text "Error: Please provide DLL file names and extensions separated by semicolons if more than one." -Color "DarkRed" -Bold:$true
        }
        elseif ([string]::IsNullOrWhiteSpace($OutputBox.Text)) {
            if (-not (Test-Path $DllBox.Text)) {
                Write-Log -Window $window -Text "Error: Please provide folder path to save exports in." -Color "DarkRed" -Bold:$true
            } else {
                Write-Log -Window $window -Text "Error: Please provide file save as path." -Color "DarkRed" -Bold:$true
            }
        } else {
            # # Example: Running multiple tasks based on manifest limits
            $runspace       = New-Runspace $StatusLabel
            $Timer          = $runspace.Timer
            $Script:jobs    = $runspace.Jobs

            $StatusLabel.Content    = "Status: Processing..."
            $normalisedPath         = (
                                        (
                                            ($OutputBox.Text -replace "%temp%", $env:TEMP) -replace "%appdata%", $env:APPDATA
                                        ) -replace "%username%", $env:USERNAME
                                    ) -replace "%userprofile", $env:USERPROFILE

            foreach ($dll in ($DllBox.Text -split ";").Trim()) {
                $FileName = "$([System.IO.Path]::GetFileNameWithoutExtension($dll)) $($ModeBox.Text) $([datetime]::Now.ToString('yyyy-MM-dd HHmmss')).reg"
                $params = [PSCustomObject]@{
                    Idx             = $this.SelectedIndex
                    DLL             = $dll
                    Output          = (Join-Path $normalisedPath $FileName)
                    Find            = $FindBox.Text
                    Replace         = $ReplaceBox.Text
                    Mode            = $ModeBox.Text
                    Context         = ${function:New-RegAsmContext}
                    Export          = ${function:Invoke-RegAsmExport}
                    Register        = ${function:Publish-DLL}
                    Unregister      = ${function:Unregister-DLL}
                    RegisterPath    = $normalisedPath
                    Logger          = ${function:New-Logger}
                    Log             = {
                                        param ($color, $bold, $italic)
                                        Write-Log -Window $window -Color $color -Bold:$bold -Italic:$italic
                                    }
                }
                
                $Script:jobs.Add((Start-EngineRunspace -script {
                    param ($params)

                    $logger = & $params.Logger
                    $log = $params.Log
                    
                    if ($params.Idx -eq 1) {
                        $logger.Invoke("Author Repository:")
                        & $log "DarkBlue" -Bold:$true
                    } elseif ($params.Idx -eq 4) {
                        $context = & $params.Context `
                            -DllName $params.DLL `
                            -OutputPath $params.Output `
                            -FindPath $params.Find `
                            -ReplacePath $params.Replace `
                            -ExportMode $params.Mode

                        & $params.Export `
                            -context $context `
                            -logger $logger `
                            -log $log
                    } elseif ($params.Idx -eq 6) {
                        $context = & $params.Context `
                            -DllName $params.DLL `
                            -OutputPath $params.RegisterPath `
                            -ExportMode "Unregister"

                        & $params.Unregister `
                            -export $params.Export `
                            -context $context `
                            -logger $logger `
                            -log $log
                    } else {
                        if ($params.Idx -eq 3) {
                            $logger.Invoke("Backing up Registery for $($params.DLL)")
                        } else {
                            $logger.Invoke("Registering $($params.DLL)")
                        }
                        & $log "DarkBlue" -Bold:$true

                        try {
                            $context = & $params.Context `
                                -DllName $params.DLL `
                                -OutputPath $params.RegisterPath `
                                -ExportMode "Full"

                            & $params.Register `
                                -context $context `
                                -export $params.Export `
                                -backupOnly ($params.Idx -eq 3) `
                                -logger $logger `
                                -log $log
                        } catch {
                            $logger.Invoke((Get-Error($_)))
                            & $log "DarkRed" -Bold:$true
                        }
                    }
                } -Arguments @($params)
                ))
            }
            
            $Timer.Start()
        }
    } elseif ($this.SelectedIndex -eq 7) {
        try {
            # Define the range of the entire document
            $range = New-Object System.Windows.Documents.TextRange(
                $LogBox.Document.ContentStart, 
                $LogBox.Document.ContentEnd
            )

            # Extract the text and write it to a file
            $File = (Split-Path -Leaf "$(($DllBox.Text -split ";")[0].Trim() -replace "\.dll", '') $([datetime]::Now.ToString('yyyy-MM-dd HHmmss')).log")
            $range.Text | Out-File (Join-Path $settings.logFolder $File) 
        } catch {
            Write-Log -Window $window -Text "$(Get-Error($_))`n$(Join-Path $settings.logFolder $File)" -Color "DarkRed" -Bold:$true
        }
    } elseif ($this.SelectedIndex -eq 8) {
        $Dialog                     = New-Object Microsoft.Win32.OpenFileDialog
        $Dialog.Multiselect         = $false
        $Dialog.InitialDirectory    = Get-Item -LiteralPath $settings.savedFolder
        $Dialog.Filter              = "JSON (*.json)|*.json"

        if ($Dialog.ShowDialog()) {
            $JsonPath = $Dialog.FileName
        }
        if ($JsonPath) {
            Get-Content $JsonPath -Raw | ConvertFrom-Json | ForEach-Object {
                $DllBox.Text            = $_.DLLs
                $OutputBox.Text         = $_.OutputPath
                $FindBox.Text           = $_.FindPath
                $ReplaceBox.Text        = $_.ReplacePath
                $ModeBox.SelectedIndex  = $_.ExportMode
            }
        }
    } elseif ($this.SelectedIndex -eq 9) {
        if ($DllBox.Text -ne ""){
            $Dialog                     = New-Object Microsoft.Win32.SaveFileDialog
            $Dialog.Filter              = "JSON (*.json)|*.json"
            $Dialog.InitialDirectory    = Get-Item -LiteralPath $settings.savedFolder

            if ($Dialog.ShowDialog()) {
                $JsonPath = $Dialog.FileName
            }
            if ($JsonPath) {
                @{
                    DLLs        = $DllBox.Text
                    OutputPath  = $OutputBox.Text
                    FindPath    = $FindBox.Text
                    ReplacePath = $ReplaceBox.Text
                    ExportMode  = $ModeBox.SelectedIndex
                } | ConvertTo-Json -Compress | Out-File $JsonPath -Force
            }
        } else {
            Write-Log -Window $window -Text "Error: Please populate the DLLs and SaveAs location fields." -Color "DarkRed" -Bold:$true
        }
    }
    $this.SelectedIndex = 0
})

function Reset-Status {
    $StatusLabel.Content = "Status: Idle"
}

$window.Icon    = Get-Shell32Icon 171
$window.Topmost = $true
$window.ShowDialog() | Out-Null

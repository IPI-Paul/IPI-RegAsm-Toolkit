function Get-Colour {
    param (
        $Colour
    )
    return @{
                Black           = "White"
                DarkBlue        = "DarkBlue" 
                DarkGreen       = "DarkGreen" 
                DarkCyan        = "DarkCyan" 
                DarkPurple      = "DarkCyan" 
                DarkRed         = "DarkRed" 
                DarkMagenta     = "DarkMagenta" 
                DarkYellow      = "DarkYellow" 
                Brown      = "DarkYellow" 
                Gray            = "Gray" 
                DarkGray        = "DarkGray" 
                Blue            = "Blue" 
                Green           = "Green" 
                Cyan            = "Cyan" 
                Purple          = "Cyan" 
                Red             = "Red" 
                Magenta         = "Magenta" 
                Yellow          = "Yellow" 
                White           = "Black" 
            }[$Colour]
}

function New-Logger {
    param (
        [switch]$CLI
    )

    if ($CLI) { 
        return {
            param ($msg)
        
            $Script:msg = "[$([datetime]::Now.ToString('HH:mm:ss'))] $msg"
        } 
    }

    $Script:Queue = [hashtable]::Synchronized(@{
        LogQueue = New-Object System.Collections.Concurrent.ConcurrentQueue[string]
    })

    return {
        param ($msg)
        
        $Script:Queue.LogQueue.Enqueue("[$([datetime]::Now.ToString('HH:mm:ss'))] $msg")
    }
}

# Logging Helper
function Write-Log {
    param (
        [string]$Text = "",
        [string]$Color = "Black",
        [switch]$Bold,
        [switch]$Italic,
        [switch]$CLI,
        [switch]$SaveLog,
        [string]$FileName,
        [switch]$Clear # new parameter to handle the safe clear
    )

    if ($CLI) {
        return {
            param (
                $color, 
                [switch]$Bold, 
                [switch]$Italic
                )

            if ($SaveLog -and -not [string]::IsNullOrWhiteSpace($FileName)) {
                Add-Content -Path (Join-Path $settings.logFolder ($FileName -replace "\.reg", ".log")) -Value $msg
            }
            
            if ($Bold) { $msg = "$([char]0x1b)[1m$msg$([char]0x1b)[0m" }
            if ($Italic) { $msg = "$([char]0x1b)[3m$msg$([char]0x1b)[0m" }
            if ($null -eq $color) { $color = "Black" }

            $colour = Get-Colour $color

            (Write-Host "$msg" -ForegroundColor $colour)
        }
    }

    $Window.Dispatcher.Invoke([action]{
        $Paragraph = New-Object System.Windows.Documents.Paragraph
        $Paragraph.Margin = "0"     # Removes extra spacing
        $Paragraph.LineHeight = 12  # Adjust as needed (12-15 works well)

        if ($Script:Queue -and $Text -eq "") {
            $Script:Queue.LogQueue.TryDequeue([ref]$Text)
        }

        if ($Text -ne "") {

        if ($Text -match "https://") {
            # Create Hyperlink
            $hyperlink = New-Object System.Windows.Documents.Hyperlink
            $hyperlink.NavigateUri = [Uri]$Text
            $hyperlink.Inlines.Add($Text)
            $hyperlink.Cursor = [System.Windows.Input.Cursors]::Hand
            $hyperlink.Foreground = [System.Windows.Media.Brushes]::Blue
            $hyperlink.TextDecorations = [System.Windows.TextDecorations]::Underline

            $Paragraph.Inlines.Add($hyperlink)
        } else {
            $Run = New-Object System.Windows.Documents.Run($Text)
            $Run.Foreground = $Color
            if ($Bold) { $Run.FontWeight = "Bold" }
            if ($Italic) { $Run.FontStyle = "Italic" }

            $Paragraph.Inlines.Add($Run)
        }

        $LogBox.Document.Blocks.Add($Paragraph)
        $LogBox.ScrollToEnd()}
    })
}

Export-ModuleMember -Function Get-Colour, New-Logger, Write-Log
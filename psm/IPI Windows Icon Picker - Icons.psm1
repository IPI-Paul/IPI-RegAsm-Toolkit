# Prevent multiple Add-Type calls
if (-not ('IconHelper' -as [type])) {
# Native Icon extraction helper
    Add-Type (Get-Content $Config.IconHelper -Raw)
}

# Required Assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName WindowsBase

function Convert-WpfBitmapToIcon {
    param {
        [System.Windows.Media.Imaging.BitmapSource]$bitmapSource
    }

    # Save WPF bitmap to a memory stream as PNG
    $ms         = New-Object System.IO.MemoryStream
    $encoder    = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($bitmapSource))
    $encoder.Save($ms)

    # Create Ststem.Drawing.Icon from the PNG stream
    $bitmap = [System.Drawing.Bitmap]::FromStream($ms)

    # Convert Bitmap to Icon
    $iconHandle = $bitmap.GetHicon()
    $icon       = [System.Drawing.Icon]::FromHandle($iconHandle)

    return $icon
}

# Get icon as image source
function Get-Shell32Icon {
    param (
        [Parameter(Mandatory)]
        [int]$Index,
        [int]$Size = 32
    )

    $ptr = [IconHelper]::ExtractIcon(
        [IntPtr]::Zero,
        "$env:SystemRoot\System32\shell32.dll",
        $Index
    )

    if ($ptr -eq [IntPtr]::Zero) { return $null }

    $icon = [System.Drawing.Icon]::FromHandle($ptr)

    $bmp = [System.Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon(
        $icon.Handle,
        [System.Windows.Int32Rect]::Empty,
        [System.Windows.Media.Imaging.BitmapSizeOptions]::FromWidthAndHeight($Size, $Size) 
    )

    $bmp.Freeze()
    return $bmp
}

Export-ModuleMember -Function Convert-WpfBitmapToIcon, Get-Shell32Icon
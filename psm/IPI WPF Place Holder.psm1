function Enable-WpfWatermark {
    # Prevent multiple Add-Type calls
    if (-not ('WatermarkService' -as [type])) {
        Add-Type -TypeDefinition (Get-Content $Config.WatermarkSvc -Raw) -ReferencedAssemblies PresentationFramework, PresentationCore, WindowsBase, System.Xaml
    }
}

function Set-WpfWatermark {
    param (
        [Parameter(Mandatory)]
        [System.Windows.Controls.TextBox]$TextBox,

        [Parameter(Mandatory)]
        [string]$Text
    )

    Enable-WpfWatermark
    [WatermarkService]::SetWatermark($TextBox, $Text)
}

Export-ModuleMember -Function Enable-WpfWatermark, Set-WpfWatermark
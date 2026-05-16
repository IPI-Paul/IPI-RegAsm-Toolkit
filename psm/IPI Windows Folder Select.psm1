Add-Type -AssemblyName System.Windows.Forms

function Get-SelectDialog {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.ValidateNames = $false
    $dialog.CheckFileExists = $false
    $dialog.CheckPathExists = $true
    $dialog.FileName = "Select Folder"
    return $dialog
}

Export-ModuleMember -Function Get-SelectDialog
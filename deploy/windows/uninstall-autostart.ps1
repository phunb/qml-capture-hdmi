$ErrorActionPreference = "SilentlyContinue"

Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "HdmiKiosk" -Force
$shortcut = Join-Path ([Environment]::GetFolderPath("Startup")) "HdmiKiosk.lnk"
if (Test-Path $shortcut) {
    Remove-Item $shortcut -Force
}

Write-Host "Đã gỡ autostart HDMI Kiosk."

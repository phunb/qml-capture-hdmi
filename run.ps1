# Chạy HDMI Kiosk sau khi đã cài Qt + MinGW.
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$exe = Join-Path $root "build\hdmi-kiosk.exe"

$env:Path = "C:\Qt\Tools\mingw1310_64\bin;C:\Qt\6.8.3\mingw_64\bin;" + $env:Path

if (-not (Test-Path $exe)) {
    Write-Host "Chua co file build. Chay .\scripts\build.ps1 truoc."
    exit 1
}

Set-Location (Split-Path $exe)
Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe)
Write-Host "Da mo HDMI Kiosk."
Write-Host "Thoat kiosk: Ctrl+Alt+Shift+Q"

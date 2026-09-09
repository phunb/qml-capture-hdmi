param(
    [string]$ExePath = ""
)

$ErrorActionPreference = "Stop"

function Resolve-KioskExe {
    param([string]$Path)

    if ($Path -and (Test-Path $Path)) {
        return (Resolve-Path $Path).Path
    }

    $candidates = @(
        Join-Path $PSScriptRoot "hdmi-kiosk.exe"
        Join-Path $PSScriptRoot "..\..\build\windows\hdmi-kiosk.exe"
        Join-Path $PSScriptRoot "..\..\build\hdmi-kiosk.exe"
        Join-Path $PSScriptRoot "..\..\build\Release\hdmi-kiosk.exe"
        Join-Path $PSScriptRoot "..\..\build\RelWithDebInfo\hdmi-kiosk.exe"
        Join-Path $PSScriptRoot "..\..\out\build\x64-release\hdmi-kiosk.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return (Resolve-Path $candidate).Path
        }
    }

    throw "Không tìm thấy hdmi-kiosk.exe. Chạy: .\install-autostart.ps1 -ExePath 'C:\path\hdmi-kiosk.exe'"
}

$exe = Resolve-KioskExe -Path $ExePath
$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
New-Item -Path $runKey -Force | Out-Null
New-ItemProperty -Path $runKey -Name "HdmiKiosk" -Value "`"$exe`"" -PropertyType String -Force | Out-Null

Write-Host "Đã cài tự chạy HDMI Kiosk:"
Write-Host "  $exe"
Write-Host ""
Write-Host "Nên bật auto-login cho tài khoản kiosk (netplwiz) rồi khởi động lại."
Write-Host "Thoát app khi cần bảo trì: Ctrl+Alt+Shift+Q"

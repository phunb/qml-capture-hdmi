# Copy project sang Raspberry Pi (chạy trên Windows).
# Vi du:
#   .\deploy\raspberrypi\copy-to-pi.ps1 -PiHost 192.168.1.50 -PiUser pi
param(
    [Parameter(Mandatory = $true)]
    [string]$PiHost,
    [string]$PiUser = "pi",
    [string]$RemoteDir = "~/qml-capture-hdmi"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path (Join-Path $root "CMakeLists.txt"))) {
    throw "Khong tim thay CMakeLists.txt tai $root"
}

Write-Host "Copy $root -> ${PiUser}@${PiHost}:$RemoteDir"
Write-Host "(Can OpenSSH client + Pi bat SSH)"

$exclude = @(
    "--exclude", "build",
    "--exclude", "build-pi",
    "--exclude", ".git",
    "--exclude", "*.exe"
)

if (Get-Command rsync -ErrorAction SilentlyContinue) {
    & rsync -avz --delete @exclude "$root/" "${PiUser}@${PiHost}:$RemoteDir/"
} else {
    ssh "${PiUser}@${PiHost}" "mkdir -p $RemoteDir"
    scp -r `
        (Join-Path $root "CMakeLists.txt") `
        (Join-Path $root "src") `
        (Join-Path $root "qml") `
        (Join-Path $root "deploy") `
        "${PiUser}@${PiHost}:$RemoteDir/"
}

Write-Host ""
Write-Host "Tiep theo, SSH vao Pi:"
Write-Host "  ssh ${PiUser}@${PiHost}"
Write-Host "  cd $RemoteDir"
Write-Host "  chmod +x deploy/raspberrypi/*.sh"
Write-Host "  sudo ./deploy/raspberrypi/install-raspberry-pi-kiosk.sh"
Write-Host "  sudo reboot"

# Tải Ubuntu Server 24.04 LTS (ISO kiosk, không Desktop).
$ErrorActionPreference = "Stop"
$url = "https://releases.ubuntu.com/24.04/ubuntu-24.04.4-live-server-amd64.iso"
$destDir = Join-Path ([Environment]::GetFolderPath("Desktop")) "ubuntu-kiosk-iso"
New-Item -ItemType Directory -Force -Path $destDir | Out-Null
$dest = Join-Path $destDir "ubuntu-24.04.4-live-server-amd64.iso"

Write-Host "Tai ISO Ubuntu Server 24.04 LTS"
Write-Host "  $url"
Write-Host "  -> $dest"

if (Test-Path $dest) {
    $size = (Get-Item $dest).Length
    if ($size -gt 2GB) {
        Write-Host "ISO da co ($([math]::Round($size/1GB,2)) GB). Bo qua tai."
        Write-Host $dest
        exit 0
    }
}

$ProgressPreference = "Continue"
Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
Write-Host "Xong:" (Get-Item $dest).FullName
Write-Host "Ghi USB bang Rufus (https://rufus.ie), boot mini-PC, cai Ubuntu Server, roi:"
Write-Host "  sudo ./deploy/linux/install-ubuntu-kiosk.sh"

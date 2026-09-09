# Dong goi HDMI Kiosk Windows offline vao build\windows
# May dich khong can mang, khong can cai Qt.

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $scriptDir
Set-Location $root

$ninjaDir = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\Ninja-build.Ninja_Microsoft.Winget.Source_8wekyb3d8bbwe"
$mingwBin = "C:\Qt\Tools\mingw1310_64\bin"
$qtRoot = "C:\Qt\6.8.3\mingw_64"
$qtBin = Join-Path $qtRoot "bin"
$env:Path = "$mingwBin;$qtBin;C:\Program Files\CMake\bin;$ninjaDir;C:\ProgramData\chocolatey\bin;" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")

$buildDir = Join-Path $root "build"
$outDir = Join-Path $root "build\windows"
$exeSrc = Join-Path $buildDir "hdmi-kiosk.exe"

Write-Host "==> Build Release (khong console)"
cmake -S . -B build -G Ninja `
  -DCMAKE_PREFIX_PATH="$qtRoot" `
  -DCMAKE_BUILD_TYPE=Release `
  -DCMAKE_CXX_COMPILER="$mingwBin\g++.exe" `
  -DHDMI_KIOSK_CONSOLE=OFF
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

cmake --build build --parallel
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not (Test-Path $exeSrc)) {
    Write-Host "Khong thay $exeSrc"
    exit 1
}

Write-Host "==> Tao folder $outDir"
if (Test-Path $outDir) {
    Remove-Item $outDir -Recurse -Force
}
New-Item -ItemType Directory -Path $outDir | Out-Null
Copy-Item $exeSrc (Join-Path $outDir "hdmi-kiosk.exe")

$exeOut = Join-Path $outDir "hdmi-kiosk.exe"
Write-Host "==> windeployqt"
& "$qtBin\windeployqt.exe" --release --compiler-runtime --no-translations --qmldir "$root\qml" --dir $outDir $exeOut
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> Copy FFmpeg / MinGW DLL"
$patterns = @("avcodec*.dll", "avformat*.dll", "avutil*.dll", "avfilter*.dll", "avdevice*.dll",
              "swresample*.dll", "swscale*.dll", "libgcc_s_seh-1.dll", "libstdc++-6.dll",
              "libwinpthread-1.dll")
foreach ($pat in $patterns) {
    Get-ChildItem -Path $qtBin, $mingwBin -Filter $pat -ErrorAction SilentlyContinue |
        ForEach-Object { Copy-Item $_.FullName $outDir -Force }
}

Copy-Item (Join-Path $root "deploy\windows\install-autostart.ps1") $outDir -Force
Copy-Item (Join-Path $root "deploy\windows\uninstall-autostart.ps1") $outDir -Force
Copy-Item (Join-Path $root "deploy\windows\CAI.txt") $outDir -Force

@"
[Paths]
Prefix=.
Plugins=.
Libraries=.
QmlImports=qml
Qml2Imports=qml
"@ | Set-Content -Path (Join-Path $outDir "qt.conf") -Encoding ASCII

Write-Host "==> Bien dich hdmi-kiosk-setup.exe"
$setupSrc = Join-Path $root "deploy\windows\hdmi-kiosk-setup.cpp"
$setupExe = Join-Path $outDir "hdmi-kiosk-setup.exe"
& "$mingwBin\g++.exe" -O2 -s -mwindows -municode -finput-charset=UTF-8 `
    -o $setupExe $setupSrc -lole32 -luuid -lshell32 -lshlwapi -ladvapi32
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Dong goi xong: $outDir"
Write-Host "  Chay thu: $exeOut"
Write-Host "  Cai may khac: copy ca folder nay, chay hdmi-kiosk-setup.exe"
Write-Host "  Thoat kiosk: Ctrl+Alt+Shift+Q"

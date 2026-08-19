$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$env:Path = "C:\Qt\Tools\mingw1310_64\bin;C:\Qt\6.8.3\mingw_64\bin;C:\Program Files\CMake\bin;C:\ProgramData\chocolatey\bin;" + [System.Environment]::GetEnvironmentVariable("Path","Machine")

cmake -S . -B build -G Ninja `
  -DCMAKE_PREFIX_PATH="C:/Qt/6.8.3/mingw_64" `
  -DCMAKE_BUILD_TYPE=Release `
  -DCMAKE_CXX_COMPILER="C:/Qt/Tools/mingw1310_64/bin/g++.exe" `
  -DHDMI_KIOSK_CONSOLE=ON
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

cmake --build build --parallel
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

windeployqt --qmldir qml --compiler-runtime "build\hdmi-kiosk.exe"
Write-Host "Build xong: $root\build\hdmi-kiosk.exe"

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)
docker compose build test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
docker compose run --rm test
exit $LASTEXITCODE

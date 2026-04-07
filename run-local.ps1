$ErrorActionPreference = "Stop"

$rootPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$webPath = Join-Path $rootPath "RPG_Group_web"
$bootstrapCmd = Join-Path $webPath "scripts\bootstrap.cmd"

if (-not (Test-Path $bootstrapCmd)) {
    throw "Bootstrap launcher not found: $bootstrapCmd"
}

Push-Location $webPath
try {
    & $bootstrapCmd
    if ($LASTEXITCODE -ne 0) {
        throw "Web bootstrap failed with exit code $LASTEXITCODE"
    }

    $portLine = docker compose port app 8000 2>$null
    if (-not $portLine) {
        throw "Could not resolve app host port from docker compose."
    }

    $port = ($portLine -split ':')[-1]
    $url = "http://127.0.0.1:$port"

    Write-Host "Opening $url" -ForegroundColor Cyan
    Start-Process $url | Out-Null
}
finally {
    Pop-Location
}

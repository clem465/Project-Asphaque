Param(
    [switch]$InstallApiDeps
)

$ErrorActionPreference = "Stop"

function Step([string]$Message) {
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$rootPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$apiPath = Join-Path $rootPath "Python_log_in\Backend"
$pythonExe = Join-Path $rootPath ".venv\Scripts\python.exe"
$webLauncher = Join-Path $rootPath "run-local.cmd"

if (-not (Test-Path $apiPath)) {
    throw "Python backend folder not found: $apiPath"
}

if (-not (Test-Path $pythonExe)) {
    throw "Python executable not found: $pythonExe. Create the .venv first."
}

if (-not (Test-Path $webLauncher)) {
    throw "Web launcher not found: $webLauncher"
}

if ($InstallApiDeps) {
    Step "Installing Python API dependencies"
    Push-Location $apiPath
    try {
        & $pythonExe -m pip install fastapi uvicorn mysql-connector-python "python-jose[cryptography]"
        if ($LASTEXITCODE -ne 0) {
            throw "Dependency installation failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}

$apiAlreadyRunning = $null -ne (Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue)

if ($apiAlreadyRunning) {
    Write-Host "Python API already listening on port 8000. Skipping API startup." -ForegroundColor Yellow
}
else {
    Step "Starting Python API in a new terminal"

    $apiPathEscaped = $apiPath.Replace("'", "''")
    $pythonExeEscaped = $pythonExe.Replace("'", "''")
    $apiCommand = "Set-Location -LiteralPath '$apiPathEscaped'; & '$pythonExeEscaped' -m uvicorn main:app --reload --host 127.0.0.1 --port 8000"

    Start-Process powershell -ArgumentList @(
        "-NoExit",
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-Command", $apiCommand
    ) | Out-Null
}

Step "Starting Symfony + Docker web stack"

Push-Location $rootPath
try {
    & $webLauncher
    if ($LASTEXITCODE -ne 0) {
        throw "Web launcher failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

Write-Host "`nDone. Python API and web stack should be running." -ForegroundColor Green

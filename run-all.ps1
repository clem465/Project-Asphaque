Param(
    [switch]$InstallApiDeps
)

$ErrorActionPreference = "Stop"

function Step([string]$Message) {
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Get-SystemPythonCommand {
    $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
    if ($pyLauncher) {
        return @($pyLauncher.Source, "-3")
    }

    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) {
        return @($python.Source)
    }

    throw "Python was not found. Install Python or add it to PATH, then run this script again."
}

$rootPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$apiPath = Join-Path $rootPath "Python_log_in\Backend"
$pythonExe = Join-Path $rootPath ".venv\Scripts\python.exe"
$webLauncher = Join-Path $rootPath "run-local.cmd"

if (-not (Test-Path $apiPath)) {
    throw "Python backend folder not found: $apiPath"
}

if (-not (Test-Path $webLauncher)) {
    throw "Web launcher not found: $webLauncher"
}

$venvCreated = $false
if (-not (Test-Path $pythonExe)) {
    Step "Creating Python virtual environment"
    $pythonCommand = Get-SystemPythonCommand
    $pythonArgs = @()
    if ($pythonCommand.Count -gt 1) {
        $pythonArgs = $pythonCommand[1..($pythonCommand.Count - 1)]
    }

    & $pythonCommand[0] @pythonArgs -m venv (Join-Path $rootPath ".venv")
    if ($LASTEXITCODE -ne 0) {
        throw "Virtual environment creation failed with exit code $LASTEXITCODE"
    }
    $venvCreated = $true
}

if ($InstallApiDeps -or $venvCreated) {
    Step "Installing Python API dependencies"
    Push-Location $apiPath
    try {
        & $pythonExe -m pip install --upgrade pip
        if ($LASTEXITCODE -ne 0) {
            throw "pip upgrade failed with exit code $LASTEXITCODE"
        }

        & $pythonExe -m pip install fastapi uvicorn pydantic mysql-connector-python "python-jose[cryptography]"
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

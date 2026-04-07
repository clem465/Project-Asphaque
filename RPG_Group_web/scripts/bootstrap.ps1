Param(
    [switch]$WithMigrations,
    [int]$Port = 8000
)

$ErrorActionPreference = "Stop"

function Step([string]$Message) {
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Run-Or-Throw([string]$Command) {
    Write-Host "   $Command" -ForegroundColor DarkGray
    Invoke-Expression $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed ($LASTEXITCODE): $Command"
    }
}

function Test-PortInUse([int]$CandidatePort) {
    $listeners = Get-NetTCPConnection -LocalPort $CandidatePort -State Listen -ErrorAction SilentlyContinue
    return $null -ne $listeners
}

function Resolve-AppPort([int]$PreferredPort) {
    if (-not (Test-PortInUse -CandidatePort $PreferredPort)) {
        return $PreferredPort
    }

    for ($candidate = $PreferredPort + 1; $candidate -le $PreferredPort + 50; $candidate++) {
        if (-not (Test-PortInUse -CandidatePort $candidate)) {
            return $candidate
        }
    }

    throw "No available host port found in range $PreferredPort-$($PreferredPort + 50)."
}

Step "Checking Docker"
Run-Or-Throw "docker --version"
Run-Or-Throw "docker compose version"

cmd /c "docker info >nul 2>nul"
if ($LASTEXITCODE -ne 0) {
    $dockerDesktop = Join-Path $Env:ProgramFiles "Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dockerDesktop) {
        Write-Host "   Docker daemon is not running. Launching Docker Desktop..." -ForegroundColor Yellow
        Start-Process $dockerDesktop | Out-Null
    }

    throw "Docker daemon is not running yet. Wait for Docker Desktop to be ready, then rerun this script."
}

$resolvedPort = Resolve-AppPort -PreferredPort $Port
$env:APP_PORT = "$resolvedPort"

if ($resolvedPort -ne $Port) {
    Write-Host "   Port $Port is already in use. Using port $resolvedPort instead." -ForegroundColor Yellow
}

Step "Using host port $resolvedPort for Symfony app"

Step "Starting database container"
Run-Or-Throw "docker compose up -d --build database"

Step "Installing PHP dependencies inside container"
Run-Or-Throw "docker compose run --rm -T app composer install --no-interaction --no-scripts"

if ($WithMigrations) {
    Step "Running Doctrine migrations"
    Run-Or-Throw "docker compose run --rm -T app php bin/console doctrine:migrations:migrate --no-interaction"
}

Step "Starting Symfony app container"
Run-Or-Throw "docker compose up -d app"

Step "Checking API routes"
Run-Or-Throw "docker compose exec -T app php bin/console debug:router | findstr /I api_v1"

Write-Host "`nDone. Symfony app should be available at http://127.0.0.1:$resolvedPort" -ForegroundColor Green

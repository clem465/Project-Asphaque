# Docker Workflow (Plug and Play)

This project can run without using your local PHP runtime for dependencies.
All PHP extensions and Composer run inside the project Docker image.

## Quick start (current stable flow)

From workspace root (`PROJET FINAL`):

1. Start Symfony + Docker services:

```powershell
.\run-local.cmd
```

2. Start the Python auth backend (login/register API):

```powershell
cd .\Python_log_in\Backend
..\..\.venv\Scripts\python.exe -m uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

If this is the first run and Python modules are missing:

```powershell
cd .\Python_log_in\Backend
..\..\.venv\Scripts\python.exe -m pip install fastapi uvicorn mysql-connector-python "python-jose[cryptography]"
```

3. Export Godot in Web format and publish it into the Symfony iframe slot:

```powershell
cd .\RPG_Group_web
.\scripts\publish-godot-web.cmd
```

If the command above fails with `GODOT\build\web` not found, publish from `GODOT` root:

```powershell
cd .\RPG_Group_web
.\scripts\publish-godot-web.cmd "..\GODOT"
```

4. Open the website (port shown by bootstrap, usually `8000` or `8001`).

If your Godot export was saved to `GODOT/` root instead of `GODOT/build/web`, publish with:

```powershell
.\scripts\publish-godot-web.cmd "..\GODOT"
```

## One command setup

Prerequisite: Docker Desktop must be running.

By default, the app is exposed on host port `8000`. If that port is busy,
the bootstrap script automatically switches to the next available port.
The Godot sync client is configured to auto-discover the local API in the
`8000-8010` range.

From this folder, run:

```powershell
.\scripts\bootstrap.cmd
```

From workspace root (`PROJET FINAL`), you can also run:

```powershell
.\run-local.cmd
```

This starts the web stack and opens the page automatically.

If you prefer PowerShell directly:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\bootstrap.ps1
```

Force a specific host port:

```powershell
.\scripts\bootstrap.cmd -Port 8010
```

With migrations included:

```powershell
.\scripts\bootstrap.cmd -WithMigrations
```

## 1) Build image + start database

```powershell
docker compose up -d --build database
```

## 2) Install dependencies into project

```powershell
docker compose run --rm -T app composer install --no-interaction --no-scripts
```

`vendor/` is created in this project folder because `./` is bind-mounted into the container.

## 3) Run migrations (once DB schema is ready)

```powershell
docker compose run --rm -T app php bin/console doctrine:migrations:migrate --no-interaction
```

## 4) Start Symfony app

```powershell
# Optional: choose host port for the app container
$env:APP_PORT=8000

docker compose up -d app
```

App URL: http://127.0.0.1:<APP_PORT>

## 5) Verify API routes

```powershell
docker compose exec -T app php bin/console debug:router | findstr /I api_v1
```

## Useful commands

```powershell
# Stop services
docker compose down

# Rebuild PHP image if Dockerfile changed
docker compose build --no-cache app

# Open shell inside container
docker compose exec app sh
```

## Publish Godot build into the page slot

The RPG homepage iframe loads `public/game/index.html`.
To publish the real Godot build into that slot:

1. Export the Godot project as Web into `GODOT/build/web`.
2. Run:

```powershell
.\scripts\publish-godot-web.cmd
```

Optional custom source folder:

```powershell
.\scripts\publish-godot-web.cmd -SourcePath "C:\path\to\godot-web-build"
```

## What is still missing for full plug-and-play

Current status: close to plug-and-play, but not yet true one-command setup.

Missing pieces:

1. Godot Web export is still manual (requires local Godot editor and export action).
2. Python auth backend is still started separately from `run-local.cmd`.
3. MySQL credentials are machine-dependent (the backend now has SQLite fallback for local login, but DB provisioning is not fully standardized).
4. There is not yet a single script that starts Docker + Python API + Godot publish in one fully automated pass.

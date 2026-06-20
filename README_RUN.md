# Run Web + Godot Together (Local)

## Fastest start (one command)

From workspace root (`PROJET FINAL`):

```powershell
.\run-all.cmd
```

This launches:
- Python auth API in a dedicated terminal (`127.0.0.1:8000`)
- Symfony + Docker web stack (`127.0.0.1:8080+`)

If this is the first run and Python dependencies are missing:

```powershell
.\run-all.cmd -InstallApiDeps
```

## Manual start (two terminals)

1. Start the Python auth backend first (keeps API on port 8000):

```powershell
cd .\Python_log_in\Backend
..\..\.venv\Scripts\python.exe -m uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

2. Start Symfony + Docker services from workspace root:

```powershell
.\run-local.cmd
```

3. Export Godot to Web output folder:
   - Source project: `GODOT/`
   - Preferred export destination: `GODOT/build/web/`

4. Publish exported files into Symfony public slot:

```powershell
cd .\RPG_Group_web
.\scripts\publish-godot-web.cmd
```

If your export was generated in `GODOT/` root instead of `GODOT/build/web/`:

```powershell
cd .\RPG_Group_web
.\scripts\publish-godot-web.cmd "..\GODOT"
```

This will:
- run Docker services for Symfony
- auto-resolve host port conflicts
- expose the game page in your browser (usually port `8080` or `8081`)

## JSON error troubleshooting

If a teammate sees `JSON invalide` in the Godot menu, the game is usually calling
the Symfony web app instead of the Python API (for example on `/login`, which
returns HTML).

Use these checks:

- Python API must run on `http://127.0.0.1:8000`
- Web app should run on `http://127.0.0.1:8080` (or next free port)
- If needed, force the API endpoint in URL:

```text
http://127.0.0.1:8080/?api=http://127.0.0.1:8000
```

## What page loads the game?

The game is displayed on the homepage (`/`) inside the dedicated iframe.

## Godot gameplay notes

Current Godot controls include:

- `M`: open/close map
- `I`: open/close inventory
- `C`: open/close stats
- `V`: open/close actions
- `P`: open/close settings
- `R`: use the assigned action item

On Android/iOS or mobile browsers, Godot shows touch controls only on mobile:

- left joystick for movement
- right-side buttons for attack, assigned item, and interaction

The game also includes:

- XP gain when monsters die, with floating XP text on screen
- player level/stat progression saved through the Python API state payload
- in-game settings for master and music volume, saved locally in `user://settings.cfg`

After changing anything inside `GODOT/`, export the Godot project to Web again
and publish it into Symfony:

```powershell
cd .\RPG_Group_web
.\scripts\publish-godot-web.cmd
```

## If you do not export Godot yet

A placeholder page is shown in the iframe at `RPG_Group_web/public/game/index.html`.

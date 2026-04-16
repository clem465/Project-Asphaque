# Run Web + Godot Together (Local)

## Quick start

1. Start Symfony + Docker services from workspace root:

```powershell
.\run-local.cmd
```

2. Start the Python auth backend in a second terminal:

```powershell
cd .\Python_log_in\Backend
..\..\.venv\Scripts\python.exe -m uvicorn main:app --reload --host 127.0.0.1 --port 8000
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
- expose the game page in your browser (usually port `8000` or `8001`)

## What page loads the game?

The game is displayed on the homepage (`/`) inside the dedicated iframe.

## If you do not export Godot yet

A placeholder page is shown in the iframe at `RPG_Group_web/public/game/index.html`.

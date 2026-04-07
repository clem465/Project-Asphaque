# Run Web + Godot Together (Local)

## Quick start

1. Export Godot to Web output folder:
   - Source project: `GODOT/`
   - Export destination: `GODOT/build/web/`

2. Publish exported files into Symfony public slot:

```powershell
cd .\RPG_Group_web
.\scripts\publish-godot-web.cmd
```

3. Start everything from workspace root:

```powershell
cd ..
.\run-local.cmd
```

This will:
- bootstrap Docker services for Symfony
- auto-resolve host port conflicts
- open the website in your browser

## What page loads the game?

The game is displayed on the homepage (`/`) inside the dedicated iframe.

## If you do not export Godot yet

A placeholder page is shown in the iframe at `RPG_Group_web/public/game/index.html`.

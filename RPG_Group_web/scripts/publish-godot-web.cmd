@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0publish-godot-web.ps1" %*
exit /b %ERRORLEVEL%

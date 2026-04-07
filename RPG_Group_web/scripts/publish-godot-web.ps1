Param(
    [string]$SourcePath
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$defaultSource = Join-Path $projectRoot "..\GODOT\build\web"
$resolvedSource = if ([string]::IsNullOrWhiteSpace($SourcePath)) { $defaultSource } else { $SourcePath }
$targetPath = Join-Path $projectRoot "public\game"

if (-not (Test-Path $resolvedSource)) {
    throw "Godot web build folder not found: $resolvedSource"
}

if (-not (Test-Path (Join-Path $resolvedSource "index.html"))) {
    throw "No index.html found in Godot build folder: $resolvedSource"
}

if (-not (Test-Path $targetPath)) {
    New-Item -ItemType Directory -Path $targetPath | Out-Null
}

Get-ChildItem -Path $targetPath -Force | Remove-Item -Recurse -Force
Copy-Item -Path (Join-Path $resolvedSource "*") -Destination $targetPath -Recurse -Force

Write-Host "Godot web build published to $targetPath" -ForegroundColor Green

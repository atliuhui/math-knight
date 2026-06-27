[CmdletBinding()]
param(
    [string]$GodotPath = "",

    [string]$SourceRoot = "",

    [string]$OutputRoot = "",

    [int]$Size = 32
)

$ErrorActionPreference = "Stop"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ResolvedGodotPath = if ($GodotPath) { $GodotPath } else { $env:GODOT_EXE }
if (-not $ResolvedGodotPath) {
    $GodotCommand = Get-Command "godot.console.exe" -ErrorAction SilentlyContinue
    if (-not $GodotCommand) {
        $GodotCommand = Get-Command "godot.exe" -ErrorAction SilentlyContinue
    }
    if (-not $GodotCommand) {
        $GodotCommand = Get-Command "godot" -ErrorAction SilentlyContinue
    }
    if ($GodotCommand) {
        $ResolvedGodotPath = $GodotCommand.Source
    }
}
if (-not $ResolvedGodotPath) {
    $ScoopGodot = Join-Path $env:USERPROFILE "scoop\apps\godot\current\godot.console.exe"
    if (Test-Path $ScoopGodot) {
        $ResolvedGodotPath = $ScoopGodot
    }
}

$ResolvedSourceRoot = if ($SourceRoot) { $SourceRoot } else { Join-Path $ProjectRoot "resources\icons" }
$ResolvedOutputRoot = if ($OutputRoot) { $OutputRoot } else { Join-Path $ProjectRoot "assets\icons" }

if (-not $ResolvedGodotPath) {
    throw "Godot executable path is required. Pass -GodotPath, set GODOT_EXE, or add Godot to PATH."
}

if (-not (Test-Path $ResolvedGodotPath)) {
    throw "Godot executable not found: $ResolvedGodotPath."
}

if (-not (Test-Path $ResolvedSourceRoot)) {
    throw "SVG source icon directory not found: $ResolvedSourceRoot."
}

$sourceFiles = Get-ChildItem -Path $ResolvedSourceRoot -Filter "*.svg" -File
if ($sourceFiles.Count -eq 0) {
    throw "No SVG icon files found in $ResolvedSourceRoot."
}

New-Item -ItemType Directory -Force -Path $ResolvedOutputRoot | Out-Null

function ConvertTo-GodotPath([string]$Path) {
    return $Path.Replace("\", "/").Replace('"', '\"')
}

$sourcePath = ConvertTo-GodotPath $ResolvedSourceRoot
$outputPath = ConvertTo-GodotPath $ResolvedOutputRoot
$scriptPath = Join-Path $ProjectRoot "tools\export_icons.gd"
if (-not (Test-Path $scriptPath)) {
    throw "Godot icon export script not found: $scriptPath."
}

$process = Start-Process -FilePath $ResolvedGodotPath -ArgumentList @(
    "--headless",
    "--script",
    $scriptPath,
    "--",
    "source-root=$sourcePath",
    "output-root=$outputPath",
    "size=$Size"
) -Wait -PassThru -NoNewWindow
if ($process.ExitCode -ne 0) {
    throw "Godot SVG icon export failed with exit code $($process.ExitCode)."
}

Write-Host "Icon export complete. Outputs are under $ResolvedOutputRoot"

[CmdletBinding()]
param(
    [string]$GodotPath = "",

    [string]$ProjectPath = "",

    [int]$BossHp = 5,

    [string[]]$GodotArguments = @(),

    [switch]$Wait
)

$ErrorActionPreference = "Stop"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ResolvedProjectPath = if ($ProjectPath) { (Resolve-Path $ProjectPath).Path } else { $ProjectRoot }
$ResolvedGodotPath = if ($GodotPath) { $GodotPath } else { $env:GODOT_EXE }

if (-not $ResolvedGodotPath) {
    $GodotCommand = Get-Command "godot.exe" -ErrorAction SilentlyContinue
    if (-not $GodotCommand) {
        $GodotCommand = Get-Command "godot.console.exe" -ErrorAction SilentlyContinue
    }
    if (-not $GodotCommand) {
        $GodotCommand = Get-Command "godot" -ErrorAction SilentlyContinue
    }
    if ($GodotCommand) {
        $ResolvedGodotPath = $GodotCommand.Source
    }
}

if (-not $ResolvedGodotPath) {
    $ScoopGodot = Join-Path $env:USERPROFILE "scoop\apps\godot\current\godot.exe"
    if (Test-Path $ScoopGodot) {
        $ResolvedGodotPath = $ScoopGodot
    }
}

if (-not $ResolvedGodotPath) {
    $ScoopGodotConsole = Join-Path $env:USERPROFILE "scoop\apps\godot\current\godot.console.exe"
    if (Test-Path $ScoopGodotConsole) {
        $ResolvedGodotPath = $ScoopGodotConsole
    }
}

if (-not $ResolvedGodotPath) {
    throw "Godot executable path is required. Pass -GodotPath, set GODOT_EXE, or add Godot to PATH."
}

if (-not (Test-Path $ResolvedGodotPath)) {
    throw "Godot executable not found: $ResolvedGodotPath."
}

$arguments = @($GodotArguments) + @("--path", $ResolvedProjectPath)
$env:MATH_WAR_BOSS_HP = [string]$BossHp
Write-Host "Starting Godot: $ResolvedGodotPath"
Write-Host "Project path: $ResolvedProjectPath"
Write-Host "MATH_WAR_BOSS_HP: $env:MATH_WAR_BOSS_HP"

if ($Wait) {
    $process = Start-Process -FilePath $ResolvedGodotPath -ArgumentList $arguments -PassThru -Wait
    if ($process.ExitCode -ne 0) {
        throw "Godot exited with code $($process.ExitCode)."
    }
} else {
    Start-Process -FilePath $ResolvedGodotPath -ArgumentList $arguments | Out-Null
}

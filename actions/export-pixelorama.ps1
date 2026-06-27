[CmdletBinding()]
param(
    [string]$PixeloramaPath = "",

    [string]$GodotPath = "",

    [string]$SourceRoot = "",

    [string]$OutputRoot = "",

    [int]$Scale = 4
)

$ErrorActionPreference = "Stop"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ResolvedPixeloramaPath = if ($PixeloramaPath) { $PixeloramaPath } else { $env:PIXELORAMA_EXE }
if (-not $ResolvedPixeloramaPath) {
    $PixeloramaCommand = Get-Command "Pixelorama.exe" -ErrorAction SilentlyContinue
    if (-not $PixeloramaCommand) {
        $PixeloramaCommand = Get-Command "Pixelorama" -ErrorAction SilentlyContinue
    }
    if ($PixeloramaCommand) {
        $ResolvedPixeloramaPath = $PixeloramaCommand.Source
    }
}
if (-not $ResolvedPixeloramaPath -and $env:LOCALAPPDATA) {
    $WingetPackageRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    if (Test-Path $WingetPackageRoot) {
        $WingetPixelorama = Get-ChildItem -Path $WingetPackageRoot -Recurse -Filter "Pixelorama.exe" -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -like "*OramaInteractive.Pixelorama*" } |
            Select-Object -First 1
        if ($WingetPixelorama) {
            $ResolvedPixeloramaPath = $WingetPixelorama.FullName
        }
    }
}

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

$ResolvedSourceRoot = if ($SourceRoot) { $SourceRoot } else { Join-Path $ProjectRoot "resources\pixelorama" }
$ResolvedOutputRoot = if ($OutputRoot) { $OutputRoot } else { Join-Path $ProjectRoot "assets\sprites" }

if (-not $ResolvedPixeloramaPath) {
    throw "Pixelorama executable path is required. Pass -PixeloramaPath, set PIXELORAMA_EXE, or add Pixelorama.exe to PATH."
}

if (-not (Test-Path $ResolvedPixeloramaPath)) {
    throw "Pixelorama executable not found: $ResolvedPixeloramaPath."
}

if ($ResolvedGodotPath -and -not (Test-Path $ResolvedGodotPath)) {
    throw "Godot executable not found: $ResolvedGodotPath."
}

if (-not (Test-Path $ResolvedSourceRoot)) {
    throw "Pixelorama source directory not found: $ResolvedSourceRoot."
}

$sourceFiles = Get-ChildItem -Path $ResolvedSourceRoot -Filter "*.pxo" -File
if ($sourceFiles.Count -eq 0) {
    throw "No Pixelorama .pxo files found in $ResolvedSourceRoot. Create or save Pixelorama source files there first."
}

New-Item -ItemType Directory -Force -Path $ResolvedOutputRoot | Out-Null

function ConvertTo-GodotPath([string]$Path) {
    return $Path.Replace("\", "/").Replace('"', '\"')
}

function Invoke-QuietProcess {
    param(
        [Parameter(Mandatory)] [string]$FilePath,
        [Parameter(Mandatory)] [string[]]$Arguments,
        [Parameter(Mandatory)] [string]$Label,
        [switch]$NoNewWindow
    )

    $stdoutLog = [System.IO.Path]::GetTempFileName()
    $stderrLog = [System.IO.Path]::GetTempFileName()
    try {
        $startArgs = @{
            FilePath               = $FilePath
            ArgumentList           = $Arguments
            Wait                   = $true
            PassThru               = $true
            RedirectStandardOutput = $stdoutLog
            RedirectStandardError  = $stderrLog
        }
        if ($NoNewWindow) { $startArgs.NoNewWindow = $true }
        $proc = Start-Process @startArgs
        return [pscustomobject]@{
            ExitCode  = $proc.ExitCode
            StdoutLog = $stdoutLog
            StderrLog = $stderrLog
            Label     = $Label
        }
    } catch {
        Remove-Item -LiteralPath $stdoutLog, $stderrLog -ErrorAction SilentlyContinue
        throw
    }
}

function Write-ProcessLogs([pscustomobject]$Result) {
    foreach ($entry in @(
        @{ Path = $Result.StdoutLog; Stream = 'stdout' },
        @{ Path = $Result.StderrLog; Stream = 'stderr' }
    )) {
        if (Test-Path $entry.Path) {
            $content = Get-Content -LiteralPath $entry.Path -Raw
            if ($content -and $content.Trim()) {
                Write-Host "--- $($Result.Label) $($entry.Stream) ---"
                Write-Host $content
            }
        }
    }
}

function Remove-ProcessLogs([pscustomobject]$Result) {
    Remove-Item -LiteralPath $Result.StdoutLog, $Result.StderrLog -ErrorAction SilentlyContinue
}

function Export-PxoWithGodot([System.IO.FileInfo]$Source, [string]$OutputPath, [int]$Scale) {
    if (-not $ResolvedGodotPath) {
        throw "Pixelorama did not create $OutputPath, and no Godot executable was found for fallback export. Pass -GodotPath or set GODOT_EXE."
    }

    $scriptPath = Join-Path $ProjectRoot "tools\export_pxo.gd"
    if (-not (Test-Path $scriptPath)) {
        throw "Godot Pixelorama export script not found: $scriptPath."
    }
    $sourcePath = ConvertTo-GodotPath $Source.FullName
    $targetPath = ConvertTo-GodotPath $OutputPath
    $result = Invoke-QuietProcess -FilePath $ResolvedGodotPath -Arguments @(
        "--headless",
        "--script",
        $scriptPath,
        "--",
        "source=$sourcePath",
        "target=$targetPath",
        "scale=$Scale"
    ) -Label "Godot ($($Source.Name))" -NoNewWindow
    try {
        if ($result.ExitCode -ne 0) {
            Write-ProcessLogs $result
            throw "Godot fallback export failed for $($Source.Name) with exit code $($result.ExitCode)."
        }
    } finally {
        Remove-ProcessLogs $result
    }
}

foreach ($source in $sourceFiles) {
    $outputPath = Join-Path $ResolvedOutputRoot ($source.BaseName + ".png")
    Write-Host "Exporting $($source.Name) -> $outputPath"
    $arguments = @(
        "--headless"
        "--quit-after"
        "120"
        "--"
        $source.FullName
        "--export"
        "--scale"
        "$Scale"
        "--output"
        $outputPath
    )
    $result = Invoke-QuietProcess -FilePath $ResolvedPixeloramaPath -Arguments $arguments -Label "Pixelorama ($($source.Name))"
    try {
        if (-not (Test-Path $outputPath)) {
            Write-Warning "Pixelorama CLI did not create $outputPath. Falling back to Godot-based .pxo export."
            Write-ProcessLogs $result
            Export-PxoWithGodot -Source $source -OutputPath $outputPath -Scale $Scale
        }
    } finally {
        Remove-ProcessLogs $result
    }
}

Write-Host "Pixelorama export complete. Outputs are under $ResolvedOutputRoot"

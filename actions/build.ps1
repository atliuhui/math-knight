[CmdletBinding()]
param(
    [ValidateSet("All", "HTML5", "Windows")]
    [string]$Target = "All",

    [string]$GodotPath = "",

    [string]$TemplateVersion = "4.3.stable",

    [string]$TemplateRoot = ""
)

$ErrorActionPreference = "Stop"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$DistRoot = Join-Path $ProjectRoot "dist"

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
if (-not $ResolvedGodotPath -and $env:USERPROFILE) {
    $ScoopGodot = Join-Path $env:USERPROFILE "scoop\apps\godot\current\godot.console.exe"
    if (Test-Path $ScoopGodot) {
        $ResolvedGodotPath = $ScoopGodot
    }
}

if (-not $ResolvedGodotPath) {
    throw "Godot executable path is required. Pass -GodotPath, set GODOT_EXE, or add godot to PATH."
}

if (-not (Test-Path $ResolvedGodotPath)) {
    throw "Godot executable not found: $ResolvedGodotPath."
}

if (-not (Test-Path (Join-Path $ProjectRoot "export_presets.cfg"))) {
    throw "Missing export_presets.cfg. Open the project in Godot or restore the checked-in export presets."
}

$TemplateCandidates = New-Object System.Collections.Generic.List[string]
function Add-TemplateCandidate {
    param([string]$Path)

    if ($Path -and -not $TemplateCandidates.Contains($Path)) {
        $TemplateCandidates.Add($Path)
    }
}

if ($TemplateRoot) {
    if ((Split-Path $TemplateRoot -Leaf) -eq $TemplateVersion) {
        Add-TemplateCandidate $TemplateRoot
    } else {
        Add-TemplateCandidate (Join-Path $TemplateRoot $TemplateVersion)
    }
}

if ($env:APPDATA) {
    Add-TemplateCandidate (Join-Path $env:APPDATA "Godot\export_templates\$TemplateVersion")
}

$GodotDir = Split-Path $ResolvedGodotPath -Parent
Add-TemplateCandidate (Join-Path $GodotDir "editor_data\export_templates\$TemplateVersion")

$GodotInstallRoot = Split-Path $GodotDir -Parent
Add-TemplateCandidate (Join-Path $GodotInstallRoot "current\editor_data\export_templates\$TemplateVersion")

# Scoop layout: shim lives in <scoopRoot>\shims, the real install is in
# <scoopRoot>\apps\godot\current and templates are persisted to
# <scoopRoot>\persist\godot. Probe both regardless of whether the resolved
# Godot binary was discovered through the shim.
$ScoopRoots = New-Object System.Collections.Generic.List[string]
if ($env:SCOOP)        { $ScoopRoots.Add($env:SCOOP) | Out-Null }
if ($env:SCOOP_GLOBAL) { $ScoopRoots.Add($env:SCOOP_GLOBAL) | Out-Null }
if ($env:USERPROFILE)  { $ScoopRoots.Add((Join-Path $env:USERPROFILE "scoop")) | Out-Null }
if ($GodotInstallRoot -and (Split-Path $GodotInstallRoot -Leaf) -eq "shims") {
    $ScoopRoots.Add((Split-Path $GodotInstallRoot -Parent)) | Out-Null
}
foreach ($scoopRoot in ($ScoopRoots | Select-Object -Unique)) {
    Add-TemplateCandidate (Join-Path $scoopRoot "apps\godot\current\editor_data\export_templates\$TemplateVersion")
    Add-TemplateCandidate (Join-Path $scoopRoot "persist\godot\editor_data\export_templates\$TemplateVersion")
}

$targets = @(
    @{
        Name = "HTML5"
        Preset = "Web"
        Output = Join-Path $DistRoot "web\index.html"
        RequiredTemplates = @("web_debug.zip", "web_release.zip")
    },
    @{
        Name = "Windows"
        Preset = "Windows Desktop"
        Output = Join-Path $DistRoot "win\index.exe"
        RequiredTemplates = @("windows_debug_x86_64.exe", "windows_release_x86_64.exe")
    }
)

foreach ($item in $targets) {
    $name = $item.Name
    $preset = $item.Preset
    $outputPath = $item.Output

    if ($Target -ne "All" -and $Target -ne $name) {
        continue
    }

    $resolvedTemplateRoot = $null
    foreach ($candidate in $TemplateCandidates) {
        $missingForCandidate = @()
        foreach ($template in $item.RequiredTemplates) {
            $templatePath = Join-Path $candidate $template
            if (-not (Test-Path $templatePath)) {
                $missingForCandidate += $templatePath
            }
        }
        if ($missingForCandidate.Count -eq 0) {
            $resolvedTemplateRoot = $candidate
            break
        }
    }

    if (-not $resolvedTemplateRoot) {
        $searchedList = ($TemplateCandidates | ForEach-Object { "- $_" }) -join [Environment]::NewLine
        $requiredList = ($item.RequiredTemplates | ForEach-Object { "- $_" }) -join [Environment]::NewLine
        throw "Missing Godot export templates for $name. Install Godot $TemplateVersion export templates, then retry. Searched template directories:$([Environment]::NewLine)$searchedList$([Environment]::NewLine)Required files:$([Environment]::NewLine)$requiredList"
    }

    $outputDir = Split-Path $outputPath -Parent
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

    Write-Host "Building $name -> $outputPath"
    $arguments = @(
        "--path"
        "`"$ProjectRoot`""
        "--headless"
        "--export-release"
        "`"$preset`""
        "`"$outputPath`""
    )
    $process = Start-Process -FilePath $ResolvedGodotPath -ArgumentList $arguments -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        $exitCode = $process.ExitCode
        throw "Godot export failed for $name with exit code $exitCode."
    }
    if (-not (Test-Path $outputPath)) {
        throw "Godot export failed for $name. Expected output was not created: $outputPath"
    }
}

Write-Host "Build complete. Outputs are under $DistRoot"

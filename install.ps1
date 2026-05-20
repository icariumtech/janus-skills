#Requires -Version 5.1
<#
.SYNOPSIS
    JANUS Skills installer for Windows / Claude Code

.DESCRIPTION
    Copies skill directories and schema resources into the Claude Code user profile.
    Mirrors the behaviour of install.sh on Linux/macOS.

    Skills go to:   %USERPROFILE%\.claude\skills\          (--Global)
                    <path>\.claude\skills\                  (--Project <path>)
    Resources go to: %USERPROFILE%\.claude\janus-skills\resources\   (always)

    Note: uses Copy-Item, not symlinks. Re-run after pulling repo updates.

.PARAMETER Global
    Install skills to the global Claude user profile (~\.claude\skills\).

.PARAMETER Project
    Install skills into a specific project directory's .claude\skills\.

.PARAMETER McpConfig
    Also inject the JanusGM MCP server block into the target settings.json.
    Prompts for your homelab server IP address.

.EXAMPLE
    .\install.ps1 -Global
    .\install.ps1 -Global -McpConfig
    .\install.ps1 -Project C:\Users\you\my-campaign
    .\install.ps1 -Project C:\Users\you\my-campaign -McpConfig
#>

[CmdletBinding()]
param(
    [switch]$Global,
    [string]$Project,
    [switch]$McpConfig
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------
function Write-Header($msg) { Write-Host "`n$msg" -ForegroundColor Cyan }
function Write-Ok($msg)     { Write-Host "  $msg" -ForegroundColor Green }
function Write-Err($msg)    { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

# --------------------------------------------------------------------------
# Validate flags
# --------------------------------------------------------------------------
if ($Global -and $Project) {
    Write-Err "-Global and -Project are mutually exclusive — choose one."
}
if (-not $Global -and -not $Project) {
    Write-Host "Usage: .\install.ps1 [-Global] [-Project <path>] [-McpConfig]"
    Write-Host ""
    Write-Host "  -Global           Install skills to %USERPROFILE%\.claude\skills\"
    Write-Host "  -Project <path>   Install skills to <path>\.claude\skills\"
    Write-Host "  -McpConfig        Also inject JanusGM MCP server config into settings.json"
    exit 1
}

if ($Project -and -not (Test-Path $Project -PathType Container)) {
    Write-Err "Project path does not exist or is not a directory: $Project"
}

# --------------------------------------------------------------------------
# Resolve paths
# --------------------------------------------------------------------------
$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if ($Global) {
    $SkillsDir = Join-Path $env:USERPROFILE ".claude\skills"
} else {
    $ProjectResolved = (Resolve-Path $Project).Path
    $SkillsDir = Join-Path $ProjectResolved ".claude\skills"
}

$ResourcesDir = Join-Path $env:USERPROFILE ".claude\janus-skills\resources"

Write-Header "JANUS Skills Installer"
Write-Host "  Repo             : $RepoDir"
Write-Host "  Skills target    : $SkillsDir"
Write-Host "  Resources target : $ResourcesDir"

# --------------------------------------------------------------------------
# Create destination directories
# --------------------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $SkillsDir  | Out-Null
New-Item -ItemType Directory -Force -Path $ResourcesDir | Out-Null

# --------------------------------------------------------------------------
# Copy resource files (resources\schema-*.md)
# --------------------------------------------------------------------------
Write-Header "Installing resources..."
$ResourceSrc = Join-Path $RepoDir "resources"
$ResourceFiles = Get-ChildItem -Path $ResourceSrc -Filter "*.md" -File -ErrorAction SilentlyContinue

if ($ResourceFiles.Count -eq 0) {
    Write-Host "  NOTE: No .md files found in resources\ — skipping."
} else {
    foreach ($f in $ResourceFiles) {
        $dest = Join-Path $ResourcesDir $f.Name
        Copy-Item -Path $f.FullName -Destination $dest -Force
        Write-Ok "$($f.Name) -> $ResourcesDir"
    }
}

# --------------------------------------------------------------------------
# Copy skill directories (skills\janus-*\)
# --------------------------------------------------------------------------
Write-Header "Installing skills..."
$SkillsSrc = Join-Path $RepoDir "skills"
$SkillDirs = Get-ChildItem -Path $SkillsSrc -Directory -Filter "janus-*" -ErrorAction SilentlyContinue

if ($SkillDirs.Count -eq 0) {
    Write-Host "  NOTE: No janus-* directories found in skills\ — skipping."
} else {
    foreach ($dir in $SkillDirs) {
        $dest = Join-Path $SkillsDir $dir.Name
        # Remove existing copy so Copy-Item doesn't nest inside it
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        Copy-Item -Path $dir.FullName -Destination $dest -Recurse -Force
        Write-Ok "$($dir.Name) -> $SkillsDir"
    }
}

# --------------------------------------------------------------------------
# Optional: MCP config injection (-McpConfig)
# --------------------------------------------------------------------------
if ($McpConfig) {
    Write-Header "Configuring MCP server..."

    # Require python (for JSON merge — keeps parity with install.sh)
    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) { $python = Get-Command python3 -ErrorAction SilentlyContinue }
    if (-not $python) {
        Write-Err "Python not found on PATH. Install Python 3 or add it to PATH, then re-run with -McpConfig."
    }

    # Prompt for homelab IP
    $HomelabIp = ""
    while (-not $HomelabIp) {
        $HomelabIp = Read-Host "  Homelab server IP (e.g. 192.168.1.42)"
        if (-not $HomelabIp) { Write-Host "  IP address cannot be blank." -ForegroundColor Yellow }
    }

    # Determine target settings.json
    if ($Global) {
        $SettingsFile = Join-Path $env:USERPROFILE ".claude\settings.json"
    } else {
        $SettingsFile = Join-Path $ProjectResolved ".claude\settings.json"
    }

    $SettingsDir = Split-Path $SettingsFile
    New-Item -ItemType Directory -Force -Path $SettingsDir | Out-Null

    $TemplatePath = Join-Path $RepoDir "mcp-config-template.json"

    # Python script for atomic JSON merge (identical logic to install.sh)
    $PyScript = @"
import sys, json, os, tempfile

settings_path = sys.argv[1]
template_path = sys.argv[2]
homelab_ip    = sys.argv[3]

existing = {}
if os.path.exists(settings_path):
    with open(settings_path, 'r') as fh:
        existing = json.load(fh)

if 'mcpServers' not in existing or not isinstance(existing['mcpServers'], dict):
    existing['mcpServers'] = {}

with open(template_path, 'r') as fh:
    template = json.load(fh)

entry = template['mcpServers']['JanusGM']
entry['url'] = entry['url'].replace('HOMELAB_IP', homelab_ip)
existing['mcpServers']['JanusGM'] = entry

settings_dir = os.path.dirname(settings_path) or '.'
tmp_fd, tmp_path = tempfile.mkstemp(dir=settings_dir, prefix='.settings_tmp_')
try:
    with os.fdopen(tmp_fd, 'w') as fh:
        json.dump(existing, fh, indent=2)
        fh.write('\n')
    os.replace(tmp_path, settings_path)
except Exception:
    try: os.unlink(tmp_path)
    except OSError: pass
    raise

print('MCP config written to', settings_path)
"@

    $TempPy = [System.IO.Path]::GetTempFileName() + ".py"
    try {
        Set-Content -Path $TempPy -Value $PyScript -Encoding UTF8
        & $python.Source $TempPy $SettingsFile $TemplatePath $HomelabIp
    } finally {
        Remove-Item $TempPy -ErrorAction SilentlyContinue
    }
}

# --------------------------------------------------------------------------
# Done
# --------------------------------------------------------------------------
Write-Header "Done."
Write-Ok "$($SkillDirs.Count) skill(s) + $($ResourceFiles.Count) resource(s) installed."
if ($McpConfig) {
    Write-Ok "MCP config merged into settings.json (server: JanusGM)"
}
Write-Host ""
Write-Host "  Restart Claude Code for the /janus-* skills to appear." -ForegroundColor Yellow
Write-Host ""

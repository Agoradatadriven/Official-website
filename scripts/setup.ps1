# =============================================================================
#  Agora Data Driven - one-time machine setup (Windows / PowerShell)
#
#  For a BRAND-NEW laptop. Run once after `git clone`:
#      powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1
#
#  It installs everything needed and launches the site:
#    1. Node.js LTS      (via winget, if missing)
#    2. Google Cloud CLI (via winget, if missing)
#    3. GitHub CLI       (via winget, if missing)
#    4. Signs you in to Google Cloud + GitHub  -- opens a BROWSER, no passwords
#    5. Configures git to push to GitHub over HTTPS using your gh token
#    6. Selects the GCP project + region and enables the required APIs
#    7. Installs project dependencies (npm ci)
#    8. Starts the dev server (http://localhost:4321)
#
#  NOTE: Node project - the local dependency environment is node_modules/
#  (created by npm). There is no Python "venv".
# =============================================================================

$ErrorActionPreference = 'Stop'

# --- Project config ----------------------------------------------------------
$ProjectId = 'agora-data-driven'
$Account   = 'info@agoradatadriven.com'
$Region    = 'australia-southeast1'
# -----------------------------------------------------------------------------

# Always operate from the repo root, no matter where this was invoked from.
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

function Have([string]$cmd) { return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function Step([string]$msg) { Write-Host "`n==> $msg" -ForegroundColor Green }
function Info([string]$msg) { Write-Host "   $msg" }
function Warn([string]$msg) { Write-Host "   $msg" -ForegroundColor Yellow }

# Run a native command quietly and return its captured stdout (trimmed),
# without letting stderr abort the script under ErrorActionPreference=Stop.
function Get-Quiet([scriptblock]$Block) {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { return (& $Block 2>$null | Out-String).Trim() }
  finally { $ErrorActionPreference = $prev }
}

# Run a native command quietly and return its exit code (0 = success).
function Get-ExitCode([scriptblock]$Block) {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { & $Block *> $null; return $LASTEXITCODE }
  finally { $ErrorActionPreference = $prev }
}

# Reload PATH from the registry and append the dirs where winget drops these
# tools, so they're usable in THIS window without opening a new shell.
function Refresh-Path {
  $machine = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
  $user    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
  $extra = @(
    "$env:ProgramFiles\nodejs",
    "$env:ProgramFiles\GitHub CLI",
    "$env:LOCALAPPDATA\Google\Cloud SDK\google-cloud-sdk\bin",
    "${env:ProgramFiles(x86)}\Google\Cloud SDK\google-cloud-sdk\bin"
  ) -join ';'
  $env:Path = "$machine;$user;$extra"
}

# Install a winget package only if its command is missing; refresh PATH after.
function Ensure-Tool([string]$cmd, [string]$wingetId, [string]$label) {
  if (Have $cmd) { Info "$label already installed."; return $true }
  Info "Installing $label (a UAC prompt may appear - click Yes)..."
  # Pipe to Out-Host so winget's output is shown but does NOT leak into this
  # function's return value (otherwise the boolean guard below misbehaves).
  winget install --id $wingetId -e --accept-source-agreements --accept-package-agreements | Out-Host
  Refresh-Path
  if (Have $cmd) { Info "Installed $label."; return $true }
  Warn "$label was installed but is not on PATH in this window yet."
  return $false
}

if (-not (Test-Path '.\package.json')) {
  Write-Host "ERROR: could not find package.json at $RepoRoot." -ForegroundColor Red
  exit 1
}
if (-not (Have winget)) {
  Write-Host "ERROR: 'winget' not found. Install 'App Installer' from the Microsoft Store, then re-run." -ForegroundColor Red
  exit 1
}

# --- 1-3. Tooling ------------------------------------------------------------
Step "Checking required tools (Node.js, gcloud, GitHub CLI)"
$okNode   = Ensure-Tool 'node'   'OpenJS.NodeJS.LTS' 'Node.js LTS'
$okGcloud = Ensure-Tool 'gcloud' 'Google.CloudSDK'   'Google Cloud CLI'
$okGh     = Ensure-Tool 'gh'     'GitHub.cli'        'GitHub CLI'

if (-not ($okNode -and $okGcloud -and $okGh)) {
  Warn "A tool was just installed but is not on PATH in this window yet."
  Warn "Close this window, open a NEW PowerShell, and re-run setup.ps1 - it skips whatever is already done."
  exit 1
}
Info "Node $(node -v) | npm $(npm -v)"

# --- 4a. Google Cloud sign-in (browser, idempotent) -------------------------
Step "Google Cloud sign-in"
$active = Get-Quiet { gcloud auth list --filter=status:ACTIVE --format="value(account)" }
if ($active -ne $Account) {
  Info "Opening your browser to sign in to Google Cloud as $Account..."
  gcloud auth login $Account
} else {
  Info "Already signed in to Google Cloud as $active."
}
gcloud config set project $ProjectId | Out-Null
gcloud config set run/region $Region | Out-Null

# --- 4b. GitHub sign-in (browser, idempotent) + git credential helper -------
Step "GitHub sign-in"
if ((Get-ExitCode { gh auth status }) -ne 0) {
  Info "Opening your browser to sign in to GitHub..."
  gh auth login --web --git-protocol https
} else {
  Info "Already signed in to GitHub."
}
# Make `git push` over HTTPS use your gh token (no password prompts). Idempotent.
gh auth setup-git

# --- 6. Enable GCP APIs ------------------------------------------------------
Step "Enabling required GCP APIs"
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com

# --- 7. Dependencies ---------------------------------------------------------
Step "Installing project dependencies (npm ci)"
npm ci

# --- 8. Launch ---------------------------------------------------------------
Step "Setup complete - starting the dev server"
Info "Node:   $(node -v)"
Info "gcloud: project=$ProjectId region=$Region"
Info "From now on, just run:  powershell -ExecutionPolicy Bypass -File .\scripts\startday.ps1"
Info "Press Ctrl+C to stop the server."
Write-Host ""
npm run dev

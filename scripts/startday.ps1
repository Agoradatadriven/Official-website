# =============================================================================
#  Agora Data Driven - start your work day (Windows / PowerShell)
#
#      powershell -ExecutionPolicy Bypass -File .\scripts\startday.ps1
#
#  Run this each day, AFTER setup.ps1 has been run once. It:
#    1. Makes sure your Google Cloud + GitHub logins are ready
#       (opens a BROWSER link if needed - never a password prompt)
#    2. Pulls the latest main
#    3. Installs any new dependencies (npm ci, only if the lockfile changed)
#    4. Starts the dev server (http://localhost:4321)
# =============================================================================

$ErrorActionPreference = 'Stop'

$ProjectId = 'agora-data-driven'
$Account   = 'info@agoradatadriven.com'
$Region    = 'australia-southeast1'

# Always operate from the repo root, no matter where this was invoked from.
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

function Have([string]$cmd) { return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function Step([string]$msg) { Write-Host "`n==> $msg" -ForegroundColor Green }
function Info([string]$msg) { Write-Host "   $msg" }

function Get-Quiet([scriptblock]$Block) {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { return (& $Block 2>$null | Out-String).Trim() }
  finally { $ErrorActionPreference = $prev }
}
function Get-ExitCode([scriptblock]$Block) {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { & $Block *> $null; return $LASTEXITCODE }
  finally { $ErrorActionPreference = $prev }
}

# The tools must already exist (installed by setup.ps1).
$missing = @('node', 'gcloud', 'gh', 'git') | Where-Object { -not (Have $_) }
if ($missing) {
  Write-Host "ERROR: missing tool(s): $($missing -join ', '). Run scripts\setup.ps1 first." -ForegroundColor Red
  exit 1
}

# --- 1. Logins (browser, idempotent) ----------------------------------------
Step "Checking Google Cloud sign-in"
$active = Get-Quiet { gcloud auth list --filter=status:ACTIVE --format="value(account)" }
if ($active -ne $Account) {
  Info "Opening your browser to sign in to Google Cloud as $Account..."
  gcloud auth login $Account
  gcloud config set project $ProjectId | Out-Null
  gcloud config set run/region $Region | Out-Null
} else {
  Info "Signed in to Google Cloud as $active."
}

Step "Checking GitHub sign-in"
if ((Get-ExitCode { gh auth status }) -ne 0) {
  Info "Opening your browser to sign in to GitHub..."
  gh auth login --web --git-protocol https
} else {
  Info "Signed in to GitHub."
}
# Keep git's HTTPS credential helper pointed at your gh token (idempotent;
# guards against config drift so `git push` never prompts for a password).
gh auth setup-git

# --- 2. Latest code ----------------------------------------------------------
Step "Pulling the latest main"
git pull --ff-only
if ($LASTEXITCODE -ne 0) { Info "git pull skipped or failed - resolve manually if needed." }

# --- 3. Dependencies (only if the lockfile changed) -------------------------
Step "Checking dependencies"
$needInstall = $false
if (-not (Test-Path '.\node_modules')) {
  $needInstall = $true
} else {
  $lock  = Get-Item '.\package-lock.json' -ErrorAction SilentlyContinue
  $stamp = Get-Item '.\node_modules\.package-lock.json' -ErrorAction SilentlyContinue
  if ($lock -and (-not $stamp -or $lock.LastWriteTime -gt $stamp.LastWriteTime)) { $needInstall = $true }
}
if ($needInstall) { Info "Installing (npm ci)..."; npm ci } else { Info "Dependencies up to date." }

# --- 4. Launch ---------------------------------------------------------------
Step "Starting the dev server (Ctrl+C to stop)"
npm run dev

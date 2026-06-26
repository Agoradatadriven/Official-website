#!/usr/bin/env bash
# =============================================================================
#  Agora Data Driven - one-time machine setup (macOS / Linux)
#
#  For a BRAND-NEW machine. Run once after `git clone`:
#      bash ./scripts/setup.sh
#
#  It installs everything needed and launches the site:
#    1. Node.js LTS, Google Cloud CLI, GitHub CLI (if missing)
#    2. Signs you in to Google Cloud + GitHub  -- opens a BROWSER, no passwords
#    3. Configures git to push to GitHub over HTTPS using your gh token
#    4. Selects the GCP project + region and enables the required APIs
#    5. Installs dependencies (npm ci) and starts the dev server
#
#  NOTE: Node project - the local dependency environment is node_modules/
#  (created by npm). There is no Python "venv".
# =============================================================================
set -uo pipefail

# --- Project config ----------------------------------------------------------
PROJECT_ID="agora-data-driven"
ACCOUNT="info@agoradatadriven.com"
REGION="australia-southeast1"
# -----------------------------------------------------------------------------

# Always operate from the repo root, no matter where this was invoked from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

have() { command -v "$1" >/dev/null 2>&1; }
step() { printf '\n==> %s\n' "$1"; }
info() { printf '   %s\n' "$1"; }
die()  { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

[ -f ./package.json ] || die "could not find package.json at $REPO_ROOT."

# --- 1. Tooling --------------------------------------------------------------
step "Checking required tools (Node.js, gcloud, GitHub CLI)"

install_node() {
  have node && { info "Node.js already installed: $(node -v)"; return; }
  info "Installing Node.js..."
  if   have brew;    then brew install node
  elif have apt-get; then curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt-get install -y nodejs
  elif have dnf;     then sudo dnf install -y nodejs
  else die "could not auto-install Node. Install Node.js >= 22 from https://nodejs.org and re-run."
  fi
}

install_gcloud() {
  have gcloud && { info "gcloud already installed."; return; }
  info "Installing Google Cloud CLI (Google's official installer)..."
  if have brew; then
    brew install --cask google-cloud-sdk
  else
    curl -fsSL https://sdk.cloud.google.com | bash
    # Put gcloud on PATH for the rest of THIS script (no re-exec, no loop).
    [ -f "$HOME/google-cloud-sdk/path.bash.inc" ] && . "$HOME/google-cloud-sdk/path.bash.inc"
  fi
}

install_gh() {
  have gh && { info "GitHub CLI already installed."; return; }
  info "Installing GitHub CLI..."
  if   have brew; then brew install gh
  elif have dnf;  then sudo dnf install -y gh
  elif have apt-get; then
    sudo mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt-get update && sudo apt-get install -y gh
  else die "could not auto-install gh. Install it from https://cli.github.com and re-run."
  fi
}

install_node
install_gcloud
install_gh

have node   || die "Node.js is still not on PATH. Open a new terminal and re-run setup.sh."
have gcloud || die "gcloud is still not on PATH. Open a new terminal and re-run setup.sh."
have gh     || die "gh is still not on PATH. Open a new terminal and re-run setup.sh."
info "Node $(node -v) | npm $(npm -v)"

# --- 2a. Google Cloud sign-in (browser, idempotent) -------------------------
step "Google Cloud sign-in"
ACTIVE_ACCT="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null)"
if [ "$ACTIVE_ACCT" != "$ACCOUNT" ]; then
  info "Opening your browser to sign in to Google Cloud as $ACCOUNT..."
  gcloud auth login "$ACCOUNT" || die "Google Cloud sign-in did not complete."
else
  info "Already signed in to Google Cloud as $ACCOUNT."
fi
gcloud config set project "$PROJECT_ID" >/dev/null
gcloud config set run/region "$REGION" >/dev/null

# --- 2b. GitHub sign-in (browser, idempotent) + git credential helper -------
step "GitHub sign-in"
if ! gh auth status >/dev/null 2>&1; then
  info "Opening your browser to sign in to GitHub..."
  gh auth login --web --git-protocol https || die "GitHub sign-in did not complete."
else
  info "Already signed in to GitHub."
fi
gh auth setup-git || die "failed to configure git to use your GitHub token."

# --- 3. Enable GCP APIs ------------------------------------------------------
step "Enabling required GCP APIs"
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com \
  || die "failed to enable required GCP APIs (check billing/permissions)."

# --- 4. Dependencies + launch ------------------------------------------------
step "Installing project dependencies (npm ci)"
npm ci || die "npm ci failed."

step "Setup complete - starting the dev server"
info "From now on, just run:  bash ./scripts/startday.sh"
info "Press Ctrl+C to stop the server."
echo ""
npm run dev

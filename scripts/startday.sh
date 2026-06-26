#!/usr/bin/env bash
# =============================================================================
#  Agora Data Driven - start your work day (macOS / Linux)
#
#      bash ./scripts/startday.sh
#
#  Run this each day, AFTER setup.sh has been run once. It makes sure your
#  Google Cloud + GitHub logins are ready (opens a BROWSER link, never a
#  password prompt), pulls the latest main, installs any new dependencies,
#  and starts the dev server (http://localhost:4321).
# =============================================================================
set -uo pipefail

PROJECT_ID="agora-data-driven"
ACCOUNT="info@agoradatadriven.com"
REGION="australia-southeast1"

# Always operate from the repo root, no matter where this was invoked from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

have() { command -v "$1" >/dev/null 2>&1; }
step() { printf '\n==> %s\n' "$1"; }
info() { printf '   %s\n' "$1"; }

# The tools must already exist (installed by setup.sh).
for t in node gcloud gh git; do
  have "$t" || { printf 'ERROR: missing tool: %s. Run scripts/setup.sh first.\n' "$t" >&2; exit 1; }
done

# --- 1. Logins (browser, idempotent) ----------------------------------------
step "Checking Google Cloud sign-in"
ACTIVE_ACCT="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null)"
if [ "$ACTIVE_ACCT" != "$ACCOUNT" ]; then
  info "Opening your browser to sign in to Google Cloud as $ACCOUNT..."
  gcloud auth login "$ACCOUNT"
  gcloud config set project "$PROJECT_ID" >/dev/null
  gcloud config set run/region "$REGION" >/dev/null
else
  info "Signed in to Google Cloud as $ACCOUNT."
fi

step "Checking GitHub sign-in"
if ! gh auth status >/dev/null 2>&1; then
  info "Opening your browser to sign in to GitHub..."
  gh auth login --web --git-protocol https
else
  info "Signed in to GitHub."
fi
# Keep git's HTTPS credential helper pointed at your gh token (idempotent;
# guards against config drift so `git push` never prompts for a password).
gh auth setup-git

# --- 2. Latest code ----------------------------------------------------------
step "Pulling the latest main"
git pull --ff-only || info "git pull skipped or failed - resolve manually if needed."

# --- 3. Dependencies (only if the lockfile changed) -------------------------
step "Checking dependencies"
if [ ! -d node_modules ] || [ package-lock.json -nt node_modules/.package-lock.json ]; then
  info "Installing (npm ci)..."
  npm ci
else
  info "Dependencies up to date."
fi

# --- 4. Launch ---------------------------------------------------------------
step "Starting the dev server (Ctrl+C to stop)"
npm run dev

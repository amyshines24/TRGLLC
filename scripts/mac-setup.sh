#!/usr/bin/env bash
#
# mac-setup.sh — one-shot local dev environment setup for macOS.
#
# Installs Homebrew (if missing), the CLI tools Claude Code leans on, and the
# formatters/validators this repo uses. Safe to re-run: every step is a no-op
# when the tool is already present.
#
# Usage:
#   bash scripts/mac-setup.sh            # core + repo tooling
#   bash scripts/mac-setup.sh --extras   # also install the optional nice-to-haves
#
set -euo pipefail

EXTRAS=0
[[ "${1:-}" == "--extras" ]] && EXTRAS=1

say() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------- Homebrew ---
if ! have brew; then
  say "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Apple Silicon puts brew in /opt/homebrew; Intel in /usr/local.
  BREW_PREFIX="/opt/homebrew"
  [[ -d "$BREW_PREFIX" ]] || BREW_PREFIX="/usr/local"
  eval "$("$BREW_PREFIX/bin/brew" shellenv)"
  if ! grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
    echo "eval \"\$($BREW_PREFIX/bin/brew shellenv)\"" >> "$HOME/.zprofile"
  fi
else
  say "Homebrew already installed"
fi

# ------------------------------------------------------------ Core packages ---
# These are the ones that pay for themselves in every Claude Code session:
#   git       version control
#   node      runtime for npx-based tooling (prettier, serve, lighthouse)
#   ripgrep   fast content search — what Grep is built on
#   fd        fast file search, sane defaults, respects .gitignore
#   jq        JSON on the command line
#   gh        GitHub CLI: PRs, issues, CI status without leaving the terminal
#   tree      quick directory overviews
CORE=(git node ripgrep fd jq gh tree)

say "Installing core CLI tools"
for pkg in "${CORE[@]}"; do
  if brew list --formula "$pkg" >/dev/null 2>&1; then
    echo "  ok   $pkg"
  else
    echo "  ->   installing $pkg"
    brew install "$pkg"
  fi
done

# ------------------------------------------------------------ Claude Code ----
if have claude; then
  say "Claude Code already installed ($(claude --version 2>/dev/null || echo 'version unknown'))"
else
  say "Installing Claude Code"
  curl -fsSL https://claude.ai/install.sh | bash
fi

# --------------------------------------------------------- Repo tooling ------
# This repo is plain HTML/CSS with no build step, so the tooling is deliberately
# thin: a formatter, an HTML validator, and a static server. All run via npx so
# nothing is pinned into a package.json the site does not otherwise need.
say "Warming npx cache for repo tooling (prettier, htmlhint, serve)"
for tool in prettier htmlhint serve; do
  npx --yes "$tool" --version >/dev/null 2>&1 && echo "  ok   $tool" || echo "  warn $tool unavailable (check network)"
done

# ------------------------------------------------------------------ Extras ----
if [[ $EXTRAS -eq 1 ]]; then
  # bat        cat with syntax highlighting and line numbers
  # eza        modern ls
  # git-delta  much better git diffs
  # httpie     friendlier curl for poking at APIs
  # imagemagick resize/optimize site images
  # gnu-sed    GNU sed as gsed; macOS sed's BSD flags differ from every example online
  # starship   fast, informative shell prompt
  EXTRA_PKGS=(bat eza git-delta httpie imagemagick gnu-sed starship)
  say "Installing extras"
  for pkg in "${EXTRA_PKGS[@]}"; do
    if brew list --formula "$pkg" >/dev/null 2>&1; then
      echo "  ok   $pkg"
    else
      echo "  ->   installing $pkg"
      brew install "$pkg"
    fi
  done
fi

# ------------------------------------------------------------------- Done ----
say "Done. Next steps:"
cat <<'EONEXT'
  1. gh auth login                 # authenticate the GitHub CLI
  2. cd into this repo, run: claude
  3. Inside Claude Code run /terminal-setup   (enables shift+enter for newlines)
  4. Inside Claude Code run /permissions      (review the repo allowlist)

  Serve the site locally:   npx serve .       # or: python3 -m http.server 8000
  Format:                   npx prettier --write "**/*.{html,css,md}"
  Lint HTML:                npx htmlhint index.html
EONEXT

# Mac terminal setup for working on this repo with Claude Code

Everything below is run from **Terminal.app** (or iTerm2 / Ghostty) on your Mac.
Run `bash scripts/mac-setup.sh` to do the install steps automatically, or work
through them by hand using this document.

There are three separate layers, and they do different jobs:

| Layer | What it is | Why it helps |
| --- | --- | --- |
| **CLI tools** | `rg`, `fd`, `jq`, `gh`, `prettier`… | Claude Code shells out to these. Faster, better-shaped output means fewer wasted turns. |
| **Project config** | `CLAUDE.md`, `.claude/settings.json` | Tells Claude the conventions and pre-approves safe commands so you stop clicking "allow". |
| **MCP servers** | `claude mcp add …` | Gives Claude tools it does not otherwise have — a real browser, an issue tracker, a database. |

---

## 1. Homebrew

The package manager everything else installs through. A fresh Mac does not have
it — `brew: command not found` on a new machine is normal, not a broken install.

**Step 1 — Xcode Command Line Tools.** Homebrew needs these (git, clang, make).
Skip this and Homebrew's installer fails partway through, in a confusing spot.

```bash
xcode-select --install
```

A system dialog opens; let it finish (a few minutes, ~1.5 GB). If it prints
`command line tools are already installed`, you are done with this step.

**Step 2 — install Homebrew.** This asks for your Mac login password (it needs
`sudo` to create `/opt/homebrew`). Typing it shows nothing on screen — that is
normal, not a frozen terminal.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**Step 3 — put `brew` on your PATH.** On Apple Silicon the installer does *not*
do this for you. It prints the two lines under "Next steps" and almost everyone
scrolls past them, which is why `brew: command not found` is so common
immediately after a successful install.

Check which chip you have:

```bash
uname -m     # arm64 = Apple Silicon,  x86_64 = Intel
```

Apple Silicon (`arm64`):

```bash
echo >> ~/.zprofile
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

Intel (`x86_64`) — Homebrew installs to `/usr/local`, which is already on PATH,
so this is usually unnecessary:

```bash
echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/usr/local/bin/brew shellenv)"
```

Verify:

```bash
brew --version    # e.g. Homebrew 4.x.x
which brew        # /opt/homebrew/bin/brew  (or /usr/local/bin/brew)
```

### If `brew` still is not found

Work through these in order:

| Symptom | Cause | Fix |
| --- | --- | --- |
| `brew: command not found`, but `/opt/homebrew/bin/brew --version` works | PATH not set | Redo step 3, then open a **new** terminal window. |
| Worked in one window, not another | `~/.zprofile` only loads in new login shells | Open a new terminal tab, or run `source ~/.zprofile`. |
| You use bash, not zsh | Wrote to the wrong file | Append the same `eval` line to `~/.bash_profile` instead. Check with `echo $SHELL`. |
| Installer errored on `git` or `clang` | Missing Command Line Tools | Run step 1, then re-run step 2. |
| `Permission denied` / sudo failures | Account is not an administrator | Homebrew requires an admin account. Use one, or see the "untar anywhere" install at <https://docs.brew.sh/Installation>. |

### You can skip Homebrew entirely if you want

Homebrew is a convenience, not a requirement. Claude Code installs without it:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

macOS already ships `git`, `curl`, `python3`, `find`, and `grep`. You can be
productive today with just those and add `ripgrep`/`fd`/`jq`/`gh` later — those
are speed upgrades over the built-ins, not prerequisites. Serve the site with
`python3 -m http.server 8000`, which needs nothing installed at all.

---

## 2. Core CLI tools

```bash
brew install git node ripgrep fd jq gh tree
```

| Tool | Command | What it buys you |
| --- | --- | --- |
| **git** | `git` | Homebrew's git is newer than the Xcode one. |
| **Node** | `node`, `npx` | Runtime for `prettier`, `serve`, `lighthouse`, and most MCP servers. |
| **ripgrep** | `rg` | Content search across the whole drive in milliseconds; respects `.gitignore`. This is what makes "find every place X is used" cheap. |
| **fd** | `fd` | Same idea for filenames. `fd styles` beats `find . -name "*styles*"`. |
| **jq** | `jq` | Slice JSON — API responses, `package.json`, CI output. |
| **GitHub CLI** | `gh` | PRs, issues, CI logs, releases from the terminal. Run `gh auth login` once. |
| **tree** | `tree -L 2` | Cheap directory overview when orienting in an unfamiliar folder. |

Optional but genuinely nice — `bash scripts/mac-setup.sh --extras` installs these:

```bash
brew install bat eza git-delta httpie imagemagick gnu-sed starship
```

`git-delta` in particular makes diffs far easier to read:

```bash
git config --global core.pager delta
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
```

**A note on macOS's built-in tools:** macOS ships BSD `sed`, `awk`, and `date`,
whose flags differ from the GNU versions every StackOverflow answer assumes.
Installing `gnu-sed` gives you `gsed`, which behaves the way the examples expect.

---

## 3. Claude Code itself

Native installer (recommended — no Node dependency, self-updating):

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

Or via npm if you prefer to manage it there:

```bash
npm install -g @anthropic-ai/claude-code
```

Then, from the project folder:

```bash
cd ~/path/to/TRGLLC
claude
```

Two commands to run once inside the session:

- `/terminal-setup` — binds **shift+enter** for multi-line input.
- `/permissions` — shows what is pre-approved; add anything you find yourself
  approving over and over.

Other things worth knowing:

| Command | Effect |
| --- | --- |
| `claude "fix the nav on mobile"` | One-shot: start with a prompt already loaded. |
| `claude -c` | Continue the most recent conversation in this directory. |
| `claude -r` | Pick an older conversation to resume. |
| `/add-dir ../other-repo` | Grant access to a second folder mid-session. |
| `/clear` | Wipe context between unrelated tasks — keeps answers sharp and cheap. |
| `/init` | Generate a starter `CLAUDE.md` for a repo that lacks one. |
| `#` at the start of a message | Save that line into `CLAUDE.md` as a standing instruction. |
| `Esc` | Interrupt mid-run. `Esc Esc` rewinds to an earlier point in the conversation. |
| `claude mcp list` | Show connected MCP servers. |

---

## 4. Project configuration — the highest-leverage part

Installing CLI tools helps at the margin. **Configuration is what actually
changes how well the sessions go**, because it removes the two biggest time
sinks: re-explaining the project, and approving the same command repeatedly.

### `CLAUDE.md`

Lives at the repo root and is loaded into context automatically at the start of
every session. This repo has one — keep it current. Good content is the stuff a
new contributor would ask on day one: how to run it, what the conventions are,
what not to touch. Keep it short; a bloated `CLAUDE.md` costs context on every
single turn.

You can also keep a personal one at `~/.claude/CLAUDE.md` that applies to every
project on your machine.

### `.claude/settings.json`

Checked into the repo, shared with anyone who clones it. The `permissions.allow`
list pre-approves commands so you are not clicking through prompts all day. This
repo's config allows read-only git, `rg`/`fd`/`ls`, prettier, and the local
server — and explicitly denies destructive things like `rm -rf` and
`git push --force`.

Use `.claude/settings.local.json` (gitignored) for anything personal.

### A note on `--dangerously-skip-permissions`

It exists, it skips every prompt, and you should not use it on a machine that has
your real files, credentials, and SSH keys on it. A well-tuned allowlist gets you
95% of the convenience with none of the risk. If you truly want a no-prompts
mode, run it inside a container or a VM, not on your working drive.

---

## 5. MCP servers — extra capabilities

MCP servers plug new tools into Claude Code. Add only what you will actually use;
each one consumes context in every session.

Most useful for a static marketing site like this one:

```bash
# Drive a real Chrome browser: screenshots, console errors, responsive checks
claude mcp add chrome-devtools -- npx -y chrome-devtools-mcp@latest

# Cross-browser automation and end-to-end testing
claude mcp add playwright -- npx -y @playwright/mcp@latest
```

Others worth knowing about when the work calls for it:

- **GitHub** — issues, PRs, reviews from inside a session. (`gh` covers most of
  this already, so add the MCP server only if you want richer PR review tooling.)
- **Filesystem** — access to folders outside the project. Usually unnecessary:
  `/add-dir` already does this, scoped to the session.
- **Postgres / SQLite** — schema-aware querying, if a project grows a database.

Manage them with `claude mcp list`, `claude mcp get <name>`, `claude mcp remove <name>`.

---

## 6. Working efficiently on the local drive

Habits that matter more than any tool:

1. **Start Claude in the project folder, not your home directory.** Scope is
   context; launching from `~` makes every search slower and vaguer.
2. **`/clear` between unrelated tasks.** Context carried from a finished task is
   pure cost, and stale detail actively degrades answers.
3. **Be specific about files.** "The nav breakpoint in `css/styles.css`" beats
   "the mobile menu" and skips an entire search round-trip.
4. **Let it verify its own work.** Ask for the site to be served and screenshotted
   after a CSS change rather than accepting the change on faith.
5. **Use plan mode (`shift+tab` twice) for anything non-trivial.** Reviewing a
   plan costs a minute; reviewing a wrong 300-line diff costs an hour.
6. **Commit early and often.** Small commits mean a bad change is one `git revert`
   away rather than an archaeology project.

---

## 7. Commands for this repo specifically

Static site, no build step:

```bash
# Serve locally at http://localhost:3000
npx serve .

# …or with no Node at all
python3 -m http.server 8000

# Format HTML/CSS/Markdown
npx prettier --write "**/*.{html,css,md}"

# Lint the HTML
npx htmlhint index.html

# Performance / SEO / accessibility audit (server must be running)
npx lighthouse http://localhost:3000 --view
```

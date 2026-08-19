# TruLine Engineering Group

Website for **TruLine Engineering Group** — the civil engineering and land
surveying sister company of TruLine Restoration Group.

## Services
- Civil engineering: site development, stormwater/drainage, water resources, transportation
- Land surveying: boundary, ALTA/NSPS, topographic, construction layout
- Environmental: SWPPP, erosion & sedimentation control, consulting
- Restoration support: engineered repair plans, permitting, sealed construction plan sets

## Structure
- `index.html` — single-page site
- `css/styles.css` — styles
- `docs/mac-dev-setup.md` — local development environment setup (macOS)
- `scripts/mac-setup.sh` — installs that environment

## Local development
```bash
bash scripts/mac-setup.sh   # one-time: Homebrew, CLI tools, Claude Code
npx serve .                 # serve at http://localhost:3000
```
See [docs/mac-dev-setup.md](docs/mac-dev-setup.md) for the full walkthrough.

Static site, no build step. Open `index.html` in a browser, or serve with any
static host (GitHub Pages, Netlify, etc.).

> Note: PE stamps, signatures, and license documents are intentionally **not**
> stored in this repository.

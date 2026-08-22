# TruLine Engineering Group — website

Static marketing site. No build step, no framework, no package.json.

## Layout
- `index.html` — the entire single-page site
- `css/styles.css` — all styles
- `docs/mac-dev-setup.md` — local dev environment setup
- `scripts/mac-setup.sh` — installs that environment on macOS

## Running it
```bash
npx serve .              # http://localhost:3000
python3 -m http.server 8000   # no-Node alternative
```

## Checks before committing
```bash
npx prettier --write "**/*.{html,css,md}"
npx htmlhint index.html
```

## Conventions
- Two-space indentation in HTML and CSS.
- Semantic HTML: real `<section>`, `<nav>`, `<header>` elements with `id`s that
  match the in-page anchor links in the nav.
- The nav anchors (`#services`, `#about`, `#team`, `#restoration`, `#contact`)
  must always resolve to a section on the page.
- Brand colors live as literal hex values in `css/styles.css` — accent blue is
  `#2f7fe0`, light accent `#7db5f0`, near-black `#111`.
- Inline SVG for the logo; do not replace it with an image file.
- Keep it dependency-free. If a change seems to need a build step or a JS
  framework, raise it rather than introducing one.

## Do not commit
PE stamps, signatures, seals, or license documents. These are deliberately kept
out of this repository.

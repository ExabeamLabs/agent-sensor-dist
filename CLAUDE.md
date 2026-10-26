# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`agent-sensor-dist` is a **public distribution repo** for the `agent-sensor` binary. It contains no source code. The application is built in the private repo at `https://github.com/Exabeam/agent-sensor`. This repo holds:

- Pre-built binaries (local `bin/` staging only — never committed, attached as GitHub Release assets)
- End-user documentation in `docs/`
- A `Makefile` that drives the full release workflow via the `gh` CLI

## Release workflow

Prerequisites: `gh` CLI installed and authenticated (`gh auth login`).

```sh
# Full release (verify binaries → tag → create GitHub Release)
make release VERSION=1.2.3

# Step by step
make verify     VERSION=1.2.3   # Check all three binaries exist in bin/
make tag        VERSION=1.2.3   # Create + push git tag v1.2.3
make gh-release VERSION=1.2.3   # Create GitHub Release and upload assets
```

Before running `make release`:
1. Build in the private repo (`cargo build --release --target <triple>`) for all three targets.
2. Copy binaries into `bin/` with the naming convention below.
3. Update `docs/changelog.md` with release notes (this file is used as the GitHub Release body).
4. Bump the version string in the private repo (e.g. `Cargo.toml`) so `agent-sensor --version` matches the tag — 1.0.5 shipped reporting `1.0.4`.

### Windows signing

`make gh-release` creates the release as a **draft**, then triggers `.github/workflows/sign-windows-exe.yml` with `--field tag=$(TAG)`. The workflow downloads the draft's `.exe`, signs it with DigiCert KeyLocker (`smctl` / `signtool`), verifies the signature and timestamp, replaces the asset, and only then publishes the release. If any step fails the release stays a draft — never publish it by hand to get around a signing failure; fix the cause and re-run the workflow (`gh workflow run sign-windows-exe.yml --field tag=vX.Y.Z`). Watch progress with `gh run watch --repo ExabeamLabs/agent-sensor-dist`.

After a release is published, update the version-specific places listed under "Website" below.

## Binary naming convention

Binaries must be placed in `bin/` with these exact names before releasing:

```
bin/agent-sensor-v{VERSION}-x86_64-apple-darwin         # macOS Intel
bin/agent-sensor-v{VERSION}-aarch64-apple-darwin        # macOS Apple Silicon
bin/agent-sensor-v{VERSION}-x86_64-pc-windows-gnu.exe   # Windows
```

`bin/` is gitignored — binaries live only as GitHub Release assets.

## Docs

`docs/` contains three files: `installation.md`, `usage.md`, `changelog.md`. The source of truth for CLI flags and subcommands is `src/main.rs` in the private repo (clap definitions). When updating `usage.md`, cross-check against the clap `Cli` struct and `Commands` enum there.

Each `docs/*.md` file has a hand-maintained `docs/*.html` twin that GitHub Pages serves — update both.

`docs/changelog.md` doubles as the GitHub Release notes body — `make gh-release` passes it via `--notes-file`. Keep the most recent release at the top; move `## Unreleased` entries under a versioned heading before releasing.

## Website

GitHub Pages serves the repo root (`CNAME` → agentsensor.exabeam.com): `index.html` is the landing page and `docs/*.html` are the docs. Preview locally before pushing:

```sh
make serve            # http://localhost:4000
```

Version-specific places to update on every release:

- `index.html` — download buttons (`Download vX.Y.Z` and their URLs) and the `VERSION=` install snippets
- `docs/installation.md` / `.html` — `VERSION=` examples
- `docs/changelog.html` — "current latest release is vX.Y.Z"
- `Formula/agent-sensor.rb` — `version` and both macOS `sha256` values
- `sitemap.xml` — `lastmod` for changed pages

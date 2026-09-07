.DEFAULT_GOAL := help

# VERSION must be supplied on the command line, e.g. make release VERSION=1.2.3
VERSION ?= $(error VERSION is required. Usage: make release VERSION=1.2.3)

TAG     := v$(VERSION)
BIN_DIR := bin

MACOS_INTEL := $(BIN_DIR)/agent-sensor-$(TAG)-x86_64-apple-darwin
MACOS_ARM   := $(BIN_DIR)/agent-sensor-$(TAG)-aarch64-apple-darwin
WINDOWS     := $(BIN_DIR)/agent-sensor-$(TAG)-x86_64-pc-windows-gnu.exe

BINS := $(MACOS_INTEL) $(MACOS_ARM) $(WINDOWS)

# ── Targets ──────────────────────────────────────────────────────────────────

.PHONY: help verify tag gh-release publish release

help:
	@echo ""
	@echo "  agent-sensor-dist release workflow"
	@echo ""
	@echo "  Targets:"
	@echo "    make verify      VERSION=x.y.z   Check that all three binaries exist in bin/"
	@echo "    make tag         VERSION=x.y.z   Create and push the git tag"
	@echo "    make gh-release  VERSION=x.y.z   Create DRAFT release and upload binaries"
	@echo "    make release     VERSION=x.y.z   Full flow: verify → tag → gh-release"
	@echo "    make publish     VERSION=x.y.z   Manually un-draft a release (escape hatch)"
	@echo ""
	@echo "  Before running 'make release':"
	@echo "    1. Build binaries in the private repo and copy them to bin/ with the"
	@echo "       naming convention above."
	@echo "    2. Update docs/changelog.md with release notes."
	@echo ""
	@echo "  The release is created as a DRAFT. CI then signs the Windows .exe"
	@echo "  (DigiCert KeyLocker) and publishes the release. A signing failure"
	@echo "  leaves the release unpublished — that is intentional."
	@echo ""

verify:
	@echo "==> Checking prerequisites..."
	@command -v gh >/dev/null 2>&1 || { echo "ERROR: 'gh' (GitHub CLI) is not installed. See https://cli.github.com"; exit 1; }
	@gh auth status >/dev/null 2>&1 || { echo "ERROR: Not authenticated with gh. Run: gh auth login"; exit 1; }
	@echo "==> Verifying binaries for $(TAG)..."
	@for f in $(BINS); do \
		if [ ! -f "$$f" ]; then \
			echo "ERROR: Missing binary: $$f"; \
			exit 1; \
		fi; \
		echo "  OK  $$f"; \
	done
	@echo "==> All binaries present."

tag:
	@echo "==> Tagging $(TAG)..."
	@git diff --quiet && git diff --cached --quiet || { echo "ERROR: Working tree has uncommitted changes. Commit or stash first."; exit 1; }
	@git tag -a $(TAG) -m "Release $(TAG)"
	@git push origin $(TAG)
	@echo "==> Tag $(TAG) pushed."

# Created as a DRAFT on purpose. Draft assets are not publicly downloadable, so the unsigned
# Windows .exe is never reachable by a customer. The sign-windows-exe workflow signs it, replaces
# the asset, and publishes the release. See .github/workflows/sign-windows-exe.yml.
gh-release:
	@echo "==> Creating draft GitHub Release $(TAG)..."
	@gh release create $(TAG) $(BINS) \
		--title "$(TAG)" \
		--notes-file docs/changelog.md \
		--draft
	@echo "==> Draft release $(TAG) created. CI is now signing the Windows binary."
	@echo "    Watch:   gh run watch --repo ExabeamLabs/agent-sensor-dist"
	@echo "    Release: https://github.com/ExabeamLabs/agent-sensor-dist/releases/tag/$(TAG)"

# Escape hatch only. The signing workflow publishes the release itself; use this when a release was
# left as a draft for a reason unrelated to signing. Do NOT use it to work around a signing failure
# — that publishes an unsigned .exe.
publish:
	@echo "==> Publishing $(TAG) manually..."
	@gh release edit $(TAG) --draft=false
	@echo "==> Release $(TAG) published."

release: verify tag gh-release
	@echo ""
	@echo "==> Draft release $(TAG) created and handed off to CI for signing."

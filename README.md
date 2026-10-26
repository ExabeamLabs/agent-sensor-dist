# agent-sensor

**Endpoint Collector for Agent Behavior Analytics (ABA)** — unified event capture from AI agents running on enterprise endpoints.

```
Claude Code ──────┐
Codex CLI ────────┤
Gemini CLI ───────├─→ agent-sensor ─→ Exabeam SecOps platform
Antigravity ──────┤
OpenClaw gateway ─┘   (WebSocket)
```

Captures session lifecycle, user prompts, tool invocations, token usage, and agent costs — all normalized to Exabeam CIM for SIEM threat detection and investigation.

Binaries are published as [GitHub Releases](https://github.com/ExabeamLabs/agent-sensor-dist/releases) — no build toolchain required to install.

---

## What's New in 1.0.5

- **OpenClaw support** — `--auto-config` detects a local OpenClaw install and streams live agent activity from its gateway over WebSocket. The gateway token stays in OpenClaw's own config. See [Installation → OpenClaw](docs/installation.md#openclaw).
- **Antigravity source** — tails Antigravity transcripts under `~/.gemini`.
- **Content capture is opt-in** — prompts and responses are redacted by default; `--capture-content` forwards the text. Secrets and personal data are always removed, and detection always sees the full text.
- **`decrypt-events`** — read back event logs written with local encryption, which now covers the dead-letter queue too.
- **Signed Windows binary** — the Windows `.exe` is Authenticode-signed by Exabeam.

See the [Changelog](docs/changelog.md) for details and known issues.

---

## Capabilities

| Area | What agent-sensor does |
|------|------------------------|
| **Sources** | Claude Code, Codex CLI, and Gemini CLI through hooks on a local hook server (port `4982`); Claude Code transcripts; Antigravity transcripts; the OpenClaw gateway over WebSocket. Sources are detected automatically — `agent-sensor detect-sources` lists them. |
| **Detection** | Prompt-injection scanning on every prompt (`has_injection`, `injection_patterns`, `triggered_rules`, `max_severity`), applied before redaction. |
| **Privacy** | Prompt and response text replaced with `[REDACTED:*]` by default. Built-in patterns strip AWS keys, bearer tokens, JWTs, API keys, passwords, emails, and IPs even when content capture is on. |
| **Sinks** | Local JSONL (default, rotating), SQLite, webhook (e.g. an Exabeam cloud collector), and Chroma. Every event goes to every configured sink. |
| **Reliability** | Webhook retries with backoff; undeliverable events go to a dead-letter queue (`dlq.jsonl`) for `replay-dlq`. |
| **Encryption at rest** | `--enable-local-encryption` encrypts the JSONL log and the dead-letter queue (SQLite is not encrypted). |
| **Schema** | Events follow the open Observra schema (`observra:1.1`). |

---

## Supported Platforms

| Platform | Architecture |
|----------|-------------|
| macOS 11+ | x86_64 (Intel) |
| macOS 11+ | aarch64 (Apple Silicon) |
| Windows 10 (1803+) / 11 | x86_64 |

---

## Quick Install

### macOS (Homebrew)

```sh
brew tap ExabeamLabs/agent-sensor https://github.com/ExabeamLabs/agent-sensor-dist
brew trust exabeamlabs/agent-sensor     # Homebrew 7+ won't load third-party formulae until trusted
brew install agent-sensor
```

Upgrading later: `brew upgrade agent-sensor`. The Homebrew formula currently installs **1.0.4**; use the manual install below for 1.0.5.

### macOS (Apple Silicon)

```sh
VERSION=1.0.5
sudo curl -fsSL https://github.com/ExabeamLabs/agent-sensor-dist/releases/download/v${VERSION}/agent-sensor-v${VERSION}-aarch64-apple-darwin \
  -o /usr/local/bin/agent-sensor
sudo chmod +x /usr/local/bin/agent-sensor
```

### macOS (Intel)

```sh
VERSION=1.0.5
sudo curl -fsSL https://github.com/ExabeamLabs/agent-sensor-dist/releases/download/v${VERSION}/agent-sensor-v${VERSION}-x86_64-apple-darwin \
  -o /usr/local/bin/agent-sensor
sudo chmod +x /usr/local/bin/agent-sensor
```

### Windows (x86_64)

Download `agent-sensor-v{VERSION}-x86_64-pc-windows-gnu.exe` from the [Releases page](https://github.com/ExabeamLabs/agent-sensor-dist/releases), rename it to `agent-sensor.exe`, and add it to your `PATH`. Confirm the Exabeam signature:

```powershell
Get-AuthenticodeSignature .\agent-sensor.exe | Format-List Status, SignerCertificate   # Status: Valid
```

> **Note:** 1.0.5 binaries report `1.0.4` from `agent-sensor --version`. This is a known issue; the binary is 1.0.5 if its SHA-256 matches the release asset.

---

## First-Time Setup

```sh
cd ~                                   # --auto-config also writes project-level hooks in the current directory
agent-sensor --auto-config --dry-run   # preview every change
agent-sensor --auto-config             # install hooks, connect OpenClaw if found, write ~/.agent-sensor/config.toml
agent-sensor install-service           # run in the background (launchd on macOS, scheduled task on Windows)
```

Add `--capture-content` to `--auto-config` to forward prompt and response text instead of redacting it. To send events to Exabeam, add a webhook sink — see [Installation → Configure Sinks](docs/installation.md#configure-sinks).

---

## Documentation

- [Installation](docs/installation.md) — install, configure sinks, OpenClaw, troubleshooting
- [Usage](docs/usage.md) — CLI reference, configuration reference, event format
- [Changelog](docs/changelog.md) — release notes and known issues

# agent-sensor

**Endpoint Collector for Agent Behavior Analytics (ABA)** — unified event capture from AI CLI tools running on enterprise endpoints.

```
Claude Code ─┐
Codex CLI ───├─→ agent-sensor ─→ Exabeam SecOps platform
Gemini CLI ──┘
```

Captures session lifecycle, user prompts, tool invocations, token usage, and agent costs — all normalized to Exabeam CIM for SIEM threat detection and investigation.

Binaries are published as [GitHub Releases](https://github.com/ExabeamLabs/agent-sensor-dist/releases) — no build toolchain required to install.

---

## Supported Platforms

| Platform | Architecture |
|----------|-------------|
| macOS | x86_64 (Intel) |
| macOS | aarch64 (Apple Silicon) |
| Windows | x86_64 |

---

## Quick Install

### macOS (Homebrew)

```sh
brew tap ExabeamLabs/agent-sensor https://github.com/ExabeamLabs/agent-sensor-dist
brew install agent-sensor
```

Upgrading later: `brew upgrade agent-sensor`.

### macOS (Apple Silicon)

```sh
VERSION=1.0.0
curl -fsSL https://github.com/ExabeamLabs/agent-sensor-dist/releases/download/v${VERSION}/agent-sensor-v${VERSION}-aarch64-apple-darwin \
  -o /usr/local/bin/agent-sensor
chmod +x /usr/local/bin/agent-sensor
```

### macOS (Intel)

```sh
VERSION=1.0.0
curl -fsSL https://github.com/ExabeamLabs/agent-sensor-dist/releases/download/v${VERSION}/agent-sensor-v${VERSION}-x86_64-apple-darwin \
  -o /usr/local/bin/agent-sensor
chmod +x /usr/local/bin/agent-sensor
```

### Windows (x86_64)

Download `agent-sensor-v{VERSION}-x86_64-pc-windows-gnu.exe` from the [Releases page](https://github.com/ExabeamLabs/agent-sensor-dist/releases) and add it to your `PATH`.

---

## Documentation

- [Installation](docs/installation.md)
- [Usage](docs/usage.md)
- [Changelog](docs/changelog.md)

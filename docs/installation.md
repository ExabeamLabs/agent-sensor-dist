# Installation — agent-sensor

## Prerequisites

- **macOS**: 11.0 (Big Sur) or later (x86_64 and Apple Silicon)
- **Windows**: Windows 10 (1803+) or Windows 11 (x86_64)
- **Disk**: ~100 MB
- **Network**: Port 4982 (hook server) must be available locally
- **Runtime Dependency**:
  - **curl**: present by default on macOS and Windows 10 (1803+) / Windows 11. Verify: `curl --version` (Windows: `curl.exe --version`).

---

## Download

Download the binary for your platform from the [Releases page](https://github.com/ExabeamLabs/agent-sensor-dist/releases).

| Platform | Binary filename |
|----------|----------------|
| macOS Apple Silicon (M1/M2/M3) | `agent-sensor-v{VERSION}-aarch64-apple-darwin` |
| macOS Intel | `agent-sensor-v{VERSION}-x86_64-apple-darwin` |
| Windows x86_64 | `agent-sensor-v{VERSION}-x86_64-pc-windows-gnu.exe` |

---

### macOS (Homebrew)

```sh
brew tap ExabeamLabs/agent-sensor https://github.com/ExabeamLabs/agent-sensor-dist
brew trust exabeamlabs/agent-sensor
brew install agent-sensor
```

Homebrew 7 refuses to load formulae from a third-party tap until you trust it — without `brew trust`, `brew install` fails with *Refusing to load formula … from untrusted tap*. The formula currently installs **1.0.4**; use the manual install below for 1.0.5.

This repo isn't named `homebrew-*`, so it can't be tapped with the short `brew tap ExabeamLabs/agent-sensor-dist` form — the full URL above is required. Homebrew auto-detects Intel vs. Apple Silicon and installs the matching binary.

Upgrade with `brew upgrade agent-sensor`. Uninstall with `brew uninstall agent-sensor` (this only removes the binary — see [Uninstall](#uninstall) below for removing config/hooks).

### macOS (manual)

Replace `VERSION` with the release you want (e.g. `1.0.5`).

**Apple Silicon (M1/M2/M3):**

```sh
VERSION=1.0.5
sudo curl -fsSL https://github.com/ExabeamLabs/agent-sensor-dist/releases/download/v${VERSION}/agent-sensor-v${VERSION}-aarch64-apple-darwin \
  -o /usr/local/bin/agent-sensor
sudo chmod +x /usr/local/bin/agent-sensor
```

**Intel:**

```sh
VERSION=1.0.5
sudo curl -fsSL https://github.com/ExabeamLabs/agent-sensor-dist/releases/download/v${VERSION}/agent-sensor-v${VERSION}-x86_64-apple-darwin \
  -o /usr/local/bin/agent-sensor
sudo chmod +x /usr/local/bin/agent-sensor
```

Always confirm the download is a real binary and not a saved error page:

```sh
file /usr/local/bin/agent-sensor
# Expected: Mach-O 64-bit executable arm64   (Apple Silicon)
# Expected: Mach-O 64-bit executable x86_64  (Intel)
# If you see "ASCII text" — the download failed; retry the curl command.

agent-sensor --version
```

---

### Windows

1. Download `agent-sensor-v{VERSION}-x86_64-pc-windows-gnu.exe` from the [Releases page](https://github.com/ExabeamLabs/agent-sensor-dist/releases).
2. Rename it to `agent-sensor.exe`.
3. Move it to a directory on your `PATH` (e.g. `C:\Program Files\agent-sensor\`).

Verify in PowerShell:

```powershell
agent-sensor --version
```

From 1.0.5 the Windows binary is Authenticode-signed by Exabeam (DigiCert). Confirm the signature before running it:

```powershell
Get-AuthenticodeSignature .\agent-sensor.exe | Format-List Status, SignerCertificate
# Status should be "Valid"; the signer is CN="EXABEAM, LLC" (issued by DigiCert)
```

---

## Configuration

> [!IMPORTANT]
> **`--auto-config` is required.** You must run `--auto-config` to install hooks for agent CLI
> and install agent-sensor default configuration. Update agent-sensor configurations before starting
> the agent-sensor. You must restart agent-sensor after running `--auto-config` or 
> updating `~/.agent-sensor/config.toml`.

```sh
# Preview every change without applying
agent-sensor --auto-config --dry-run

# Apply
agent-sensor --auto-config
```

> [!NOTE]
> Run `--auto-config` from your home directory (`cd ~` first). Besides the user-level hooks, it also
> registers project-level hooks in the **current directory** (`./.claude/settings.json`,
> `./.codex/hooks.json`, `./.gemini/settings.json`). Run inside a code repository, these show up as
> untracked files.

This installs hooks for Claude Code, Codex CLI, and Gemini CLI at `~/.claude`, `~/.codex`, and `~/.gemini`, sets `features.hooks = true` in `~/.codex/config.toml`, generates the hook server secret `~/.agent-sensor/hook.secret`, and creates the default config file at `~/.agent-sensor/config.toml`. Restart the agent-sensor and any running Claude Code, Codex, or Gemini sessions to pick up the new hook configurations.

By default, prompts and model output are replaced with `[REDACTED:*]` before events leave the host. To forward the text, add `--capture-content` the first time you run `--auto-config`. It has no effect if `config.toml` already exists; in that case set `censor_request = false` and `censor_response = false` in the config yourself. Injection scanning and detection rules see the full text either way.

### OpenClaw

If OpenClaw is installed (`~/.openclaw/openclaw.json` exists), `--auto-config` adds an `[openclaw]` block to `~/.agent-sensor/config.toml`. The agent-sensor connects to the OpenClaw gateway over WebSocket and forwards live agent activity through the same sinks as the CLI hooks.

```toml
[openclaw]
enabled = true
host  = "<gateway host from openclaw.json>"
port  = <gateway port from openclaw.json>
```

The gateway auth token is **not** copied into `config.toml`. The agent-sensor reads `gateway.auth.token` from `~/.openclaw/openclaw.json` when it starts. **Restart the agent-sensor after rotating the OpenClaw gateway token** — until you do, it keeps reconnecting with the old token and the gateway rejects it. Set `token_file` (or `token`) in `[openclaw]` only to use a different credential than OpenClaw's own.

If OpenClaw is installed after you ran `--auto-config`, the existing `config.toml` is not overwritten. Add the `[openclaw]` block by hand, or move the config aside and re-run `--auto-config`.

Confirm the source is detected:

```sh
agent-sensor detect-sources
# {"all":[...,"openclaw-ws"],"available":[...,"openclaw-ws"]}
```

### Configure Sinks

A **JSONL** sink is configured automatically with `--auto-config`. The JSONL sink stores the agent telemetry in a local file.

Configure a **webhook** sink in `~/.agent-sensor/config.toml` to forward the agent telemetry to an Exabeam SIEM using the following steps.
1. The admin creates an Exabeam webhook cloud-collector with `Format=Raw` once.
2. Obtain the Exabeam webhook collector `url` and `token` securely.
3. Save the webhook token at `{HOME}/.agent-sensor/webhook.token`.
4. Update the webhook sink url.

```toml
[sources]

[[sinks]]
kind = "jsonl"
path = "{HOME}/.agent-sensor/events.jsonl"
rotation_size_mb = 100
max_rotated_files = 5

# Add to forward events to Exabeam or another SIEM:
[[sinks]]
kind = "webhook"
url = "{EXABEAM_WEBHOOK}"
token_file = "{HOME}/.agent-sensor/webhook.token"
```

Restart agent-sensor after every change to `~/.agent-sensor/config.toml`.

---

## Install as a Background Service

### macOS (launchd)

```sh
agent-sensor install-service
```

### Windows (scheduled task — no admin required)

```powershell
agent-sensor install-service
```

On Windows, `install-service` registers an ONLOGON scheduled task that runs as you — no administrator rights needed. The older `--use-scheduled-task` flag is still accepted but does nothing. `--use-windows-service` installs a Windows Service instead; it needs administrator rights and runs as LocalSystem, which usually cannot see your agent CLIs' files, so avoid it unless you have a specific reason.

---

## Verify Installation

```sh
# Check version
agent-sensor --version

# Check service status
agent-sensor status
# Service com.agent-sensor.forwarder: running
# Current version: 1.0.4

# Send a test event (the hook server requires the secret that --auto-config generated)
curl -X POST http://127.0.0.1:4982/claude \
  -H "Content-Type: application/json" \
  -H "X-Agent-Sensor-Token: $(cat ~/.agent-sensor/hook.secret)" \
  -d '{"hook_event_name":"SessionStart","session_id":"agent-sensor-install-test","source":"startup","cwd":"/tmp"}'

# Confirm it was received and recorded
agent-sensor metrics | grep agent_sensor_hook_events_received_total   # claude_code counter is non-zero
grep agent-sensor-install-test ~/.agent-sensor/events.jsonl            # one session_start event
```

---

## Upgrading

Repeat the download and install steps with the new version. The new binary replaces the old one at the same path. If the service is running, uninstall agent-sensor before saving the new binary.

```sh
# macOS

# Uninstall service before upgrade
agent-sensor uninstall-service

# After upgrade, start the service
agent-sensor install-service
```

```powershell
# Windows

# Uninstall service before upgrade
agent-sensor uninstall-service

# After upgrade, start the service
agent-sensor install-service
```

---

## Restarting

The agent-sensor needs to be restarted after any configuration changes to the hook configs or agent-sensor config.

```sh
# macOS
agent-sensor uninstall-service && agent-sensor install-service
```

```powershell
# Windows
agent-sensor uninstall-service
agent-sensor install-service
```

---

## Uninstall

### macOS

```sh
agent-sensor uninstall-service   # Remove launchd service (if installed)
sudo rm /usr/local/bin/agent-sensor   # Remove binary
rm -rf ~/.agent-sensor/               # Remove config and logs (optional)
```

To also remove the CLI hook registrations, delete only agent-sensor's hook entries and wrapper scripts. **Do not delete `~/.claude`, `~/.codex`, or `~/.gemini`** — they hold each CLI's own settings, history, and projects.

```sh
F='.hooks |= (with_entries(.value |= (map(.hooks |= map(select(.command | test("claude-watch-hook|codex-hook|gemini-hook") | not))) | map(select(.hooks | length > 0)))) | with_entries(select(.value | length > 0))) | if .hooks == {} then del(.hooks) else . end'
for f in ~/.claude/settings.json ~/.codex/hooks.json ~/.gemini/settings.json; do
  [ -f "$f" ] && cp "$f" "$f.bak" && jq "$F" "$f.bak" > "$f"
done
rm -f ~/.claude/hooks/claude-watch-hook.sh ~/.codex/hooks/codex-hook.sh ~/.gemini/hooks/gemini-hook.sh
```

Each edited file is backed up to `*.bak` first. `jq` ships with macOS 15 and later (otherwise `brew install jq`). Also remove project-level copies (`.claude/settings.json`, `.codex/hooks.json`, `.gemini/settings.json`) in any directory where you ran `--auto-config`, and, if you use no other Codex hooks, the `features.hooks = true` line in `~/.codex/config.toml`.

### Windows

```powershell
agent-sensor uninstall-service   # Remove scheduled task (if installed)
# Then delete agent-sensor.exe from its directory on your PATH
```

---

## Troubleshooting

### Binary fails to run (`exec format error` or similar)

This usually means the downloaded file is an HTML error page rather than a real binary.

```sh
file ./agent-sensor
# Real binary:      "Mach-O 64-bit executable"
# Saved error page: "ASCII text" or "HTML document text"
```

Fix: delete the file and re-download.

### Port already in use

```
error: cannot bind hook server to 127.0.0.1:4982: Address already in use (os error 48)
```

```sh
lsof -i :4982                       # Find what is using the port
agent-sensor --hook-port 4992       # Or start on a different port
```

### No events appearing

1. Verify the agent-sensor is running: `lsof -i :4982`
2. Check hooks are installed: `grep claude-watch-hook ~/.claude/settings.json` (should print one line per hooked event)
3. Send a test event manually (see [Verify Installation](#verify-installation) above)

### No OpenClaw events

The agent-sensor log (`~/.agent-sensor/forwarder.log`) reports why the gateway connection failed:

- `No OpenClaw token` — `~/.openclaw/openclaw.json` has no `gateway.auth.token`, and no `token`/`token_file` is set in `[openclaw]`.
- `OpenClaw WS connect failed` — the gateway is not running, or `host`/`port` in `[openclaw]` don't match it.
- `OpenClaw connect rejected` (`AUTH_TOKEN_MISMATCH`) — the gateway refused the token. If the gateway token was rotated, restart the agent-sensor.

If the token is missing at startup, the OpenClaw source is not started at all (`source not started`); add the token and restart the agent-sensor.

### macOS Gatekeeper blocks the binary

macOS may show a security warning the first time you run an unsigned binary. Right-click the binary in Finder, choose **Open**, and confirm when prompted — or run:

```sh
xattr -dr com.apple.quarantine /usr/local/bin/agent-sensor
```

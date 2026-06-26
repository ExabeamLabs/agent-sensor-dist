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

### macOS

Replace `VERSION` with the release you want (e.g. `1.0.4`).

**Apple Silicon (M1/M2/M3):**

```sh
VERSION=1.0.4
sudo curl -fsSL https://github.com/ExabeamLabs/agent-sensor-dist/releases/download/v${VERSION}/agent-sensor-v${VERSION}-aarch64-apple-darwin \
  -o /usr/local/bin/agent-sensor
sudo chmod +x /usr/local/bin/agent-sensor
```

**Intel:**

```sh
VERSION=1.0.4
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

This installs hooks for Claude Code, Codex CLI, and Gemini CLI at `~/.claude`, `~/.codex`, and `~/.gemini`. Restart the agent-sensor to pick up the new hook configurations.

The default config file is `~/.agent-sensor/config.toml`. It is created automatically by `--auto-config` if it does not already exist. Example:

```toml
[sources]

[[sinks]]
kind = "jsonl"
path = "/Users/YOU/.agent-sensor/events.jsonl"
rotation_size_mb = 100
max_rotated_files = 5

# Uncomment to forward events to Exabeam or another SIEM:
# [[sinks]]
# kind = "webhook"
# url = "https://your-collector.example.com/agent-sensor"
# token_file = "Users/YOU/.agent-sensor/webhook.token"
```

To forward telemetry to a SIEM, add a `webhook` sink with the endpoint URL and token file path.

---

## Install as a Background Service

### macOS (launchd)

```sh
agent-sensor install-service
```

### Windows (scheduled task — no admin required)

```powershell
agent-sensor install-service --use-scheduled-task
```

---

## Verify Installation

```sh
# Check version
agent-sensor --version

# Check service status
agent-sensor status
# Service com.agent-sensor.forwarder: running
# Current version: 1.0.4

# Send a test event to the hook server
curl -X POST http://127.0.0.1:4982/claude \
  -H "Content-Type: application/json" \
  -d '{"hook":"SessionStart","sessionId":"test"}'

# Confirm the event was received (counter should be non-zero)
agent-sensor metrics | grep agent_sensor_hook_events_received_total
```

---

## Upgrading

Repeat the download and install steps with the new version. The new binary replaces the old one at the same path. If the service is running, reinstall it so the service manifest points to the new binary:

```sh
# macOS
agent-sensor uninstall-service && agent-sensor install-service
```

```powershell
# Windows
agent-sensor uninstall-service
agent-sensor install-service --use-scheduled-task
```

---

## Uninstall

### macOS

```sh
agent-sensor uninstall-service   # Remove launchd service (if installed)
sudo rm /usr/local/bin/agent-sensor   # Remove binary
rm -rf ~/.agent-sensor/               # Remove config and logs (optional)
```

To also remove the CLI hook registrations:

```sh
rm -rf ~/.claude ~/.codex ~/.gemini
```

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
Error: Address already in use (os error 48)
```

```sh
lsof -i :4982                       # Find what is using the port
agent-sensor --hook-port 4992       # Or start on a different port
```

### No events appearing

1. Verify the agent-sensor is running: `lsof -i :4982`
2. Check hooks are installed: `grep hook-server ~/.claude/settings.json`
3. Send a test event manually (see [Verify Installation](#verify-installation) above)

### macOS Gatekeeper blocks the binary

See the [Gatekeeper](#gatekeeper-macos-security) section above.

# Usage — agent-sensor

`agent-sensor` is an endpoint collector for Agent Behavior Analytics. It captures events from AI CLI tools (Claude Code, Codex CLI, Gemini CLI), Antigravity, and the OpenClaw gateway, and forwards them — normalized to Exabeam CIM — to a local JSONL audit log and/or a SIEM webhook.

---

## Synopsis

```
agent-sensor [OPTIONS] [SUBCOMMAND]
```

Running `agent-sensor` without a subcommand is equivalent to `agent-sensor run`.

---

## Global Options

| Flag | Default | Description |
|------|---------|-------------|
| `-c, --config <PATH>` | `~/.agent-sensor/config.toml` | Path to config file |
| `--log-level <LEVEL>` | `info` | Log verbosity: `error`, `warn`, `info`, `debug`, `trace` |
| `--hook-port <PORT>` | `4982` | Port for the hook server. All three CLI paths (`/claude`, `/codex`, `/gemini`) are served on this port. `--auto-config` bakes this port into the hook wrappers. Passing `0` is meant to request an OS-assigned port, but in 1.0.5 it still binds `4982` — pass an explicit free port instead. |
| `--port-range <MIN-MAX>` | _(none)_ | Constrain all hook port binds to this range, e.g. `10000-11000`. Ephemeral ports outside the range exit with code 3; explicit ports outside the range exit with code 78. |
| `--auto-config` | — | Install hooks for Claude Code, Codex CLI, and Gemini CLI, and write a default `config.toml` (never overwrites an existing one). Adds an `[openclaw]` block when `~/.openclaw/openclaw.json` exists. |
| `--capture-content` | — | With `--auto-config`: forward prompt and response text instead of `[REDACTED:*]`. Writes `censor_request`/`censor_response = false` into the generated config; no effect if `config.toml` already exists. |
| `--dry-run` | — | Preview changes for `--auto-config` or `--enable-local-encryption` without modifying any files. |
| `--enable-local-encryption` | — | Encrypt the JSONL sink and the DLQ at rest. Requires the env var named by `[encryption] key_env_var` (default `AGENT_SENSOR_KEY`). The SQLite sink is **not** encrypted. |
| `--project-dir <PATH>` | `~/.agent-sensor` | Project directory for registry lookup (useful when running multiple instances). |

> **Security note:** Never pass bearer tokens as CLI flags — they appear in `ps aux`.
> Use `--token-file <path>` or the `AGENT_SENSOR_WEBHOOK_TOKEN` env var instead.

---

## Subcommands

### `run` _(default)_

Start the agent-sensor. Listens for hooks from AI CLIs and tails Claude Code transcripts. Runs until terminated (SIGINT / SIGTERM on macOS; Ctrl+C on Windows). On macOS, SIGHUP triggers a clean in-place restart.

```sh
agent-sensor run
agent-sensor --hook-port 4982 run
```

On startup, the bound port is printed in a machine-readable line:

```
hook-port: 4982 (paths: /claude /codex /gemini)
```

---

### `version`

Print the binary version and exit.

```sh
agent-sensor version
```

---

### `check-config [PATH]`

Validate a config file. Exits `0` if valid, `78` if malformed or missing.

```sh
agent-sensor check-config
agent-sensor check-config /path/to/custom-config.toml
```

---

### `inspect-cursors`

Dump the current source read cursor state as JSON. Useful for debugging missed or duplicated events.

```sh
agent-sensor inspect-cursors
```

---

### `install-service`

Install `agent-sensor` as a background service.

- **macOS**: launchd plist (user space, no admin required)
- **Windows**: ONLOGON scheduled task (no admin required)

```sh
# macOS
agent-sensor install-service

# Windows — scheduled task (no admin required)
agent-sensor install-service
```

| Flag | Description |
|------|-------------|
| `--use-windows-service` | Windows only: install a Windows Service (SCM) instead of the default ONLOGON scheduled task. Requires administrator rights and runs as LocalSystem, which usually cannot read your agent CLIs' files — avoid unless you have a specific reason. Ignored on macOS. |
| `--use-scheduled-task` | Deprecated no-op — the scheduled task is now the Windows default. Still accepted so existing deployment scripts keep working. |
| `--hook-port <PORT>` | Port to embed in the service manifest. Default port is 4982 |
| `--port-range <MIN-MAX>` | Port range constraint to embed in the service manifest. |
| `--project-dir <PATH>` | Sets `AGENT_SENSOR_PROJECT_DIR` in the service environment. |

---

### `uninstall-service`

Remove the background service installed by `install-service`.

```sh
agent-sensor uninstall-service   # macOS, Windows
```

---

### `status`

Print whether the background service is running, stopped, or not installed.

```sh
agent-sensor status
```

---

### `metrics`

Fetch and print current agent-sensor metrics in Prometheus text format. The agent-sensor must be running.

```sh
agent-sensor metrics
```

---

### `replay-dlq`

Re-inject events from the dead-letter queue (`~/.agent-sensor/dlq.jsonl`) through their original sink. Use this to recover events that failed to deliver (e.g. the webhook was temporarily unreachable).

```sh
# Replay all DLQ events
agent-sensor replay-dlq

# Preview without sending
agent-sensor replay-dlq --dry-run

# Replay only events for a specific sink
agent-sensor replay-dlq --sink my-webhook
```

| Flag | Description |
|------|-------------|
| `--sink <NAME>` | Only replay entries for this sink name. Omit to replay all. |
| `--dry-run` | List what would be replayed without sending. |

---

### `detect-sources`

Print available and all known source slugs as JSON. Used by the installer wizard.

```sh
agent-sensor detect-sources
# {"all":["claude-code-cli","claude-desktop","antigravity","openclaw-ws"],"available":[...]}
```

---

### `decrypt-events <PATH>`

Decrypt a file written with `--enable-local-encryption` and print it to stdout. `replay-dlq` decrypts automatically.

```sh
agent-sensor decrypt-events ~/.agent-sensor/events.jsonl > events.decrypted.jsonl
```

---

### `update`

Check for or apply a pending update (requires `[update] enabled = true` in config).

```sh
agent-sensor update            # Check and apply
agent-sensor update --check    # Poll GitHub for a new release and update state file (does not apply)
agent-sensor update --rollback # Restore the previous binary from .prev
```

---

## Common Workflows

### First-time setup

```sh
# Install hooks for all supported agent CLIs and write default config
agent-sensor --auto-config

# Start the agent-sensor on the default port 
agent-sensor install-service
```

### Preview hook installation without applying

```sh
agent-sensor --auto-config --dry-run
```

### Forward events to Exabeam

Edit `~/.agent-sensor/config.toml`:

```toml
[[sinks]]
kind = "webhook"
url = "https://your-exabeam-collector.example.com/agent-sensor"
token_file = "/Users/you/.agent-sensor/webhook.token"   # absolute path — ~ is not expanded
```

Save the webhook bearer token:

```sh
echo -n "YOUR_TOKEN" > ~/.agent-sensor/webhook.token
chmod 600 ~/.agent-sensor/webhook.token
```

Restart the agent-sensor for the new config to take effect.

### Validate config before restarting

```sh
agent-sensor check-config && agent-sensor uninstall-service && agent-sensor install-service
```

### Inspect captured events

```sh
# Raw JSONL
cat ~/.agent-sensor/events.jsonl

# Check the agent_sensor_hook_events_received_total metrics                                                                               
agent-sensor metrics | grep agent_sensor_hook_events_received_total 

# Filter by source
jq 'select(.framework=="claude_code")' ~/.agent-sensor/events.jsonl
jq 'select(.framework=="openclaw")' ~/.agent-sensor/events.jsonl

# Session starts only
jq 'select(.type=="session_start") | {ts, session, framework}' ~/.agent-sensor/events.jsonl

# Prompts flagged for injection
jq 'select(.has_injection==true)
    | {ts, session, injection_patterns, triggered_rules, max_severity}' ~/.agent-sensor/events.jsonl
```

If local encryption is enabled, decrypt first: `agent-sensor decrypt-events ~/.agent-sensor/events.jsonl | jq …`.

### Event format

Each line of the JSONL sink is one event, schema `observra:1.1`. Common top-level fields:

| Field | Description |
|-------|-------------|
| `ts` | Event timestamp (RFC 3339, UTC) |
| `type` | `session_start`, `session_end`, `user`, `turn`, `turn_duration`, `tool_start`, `tool_end`, `tool_error`, `agent_end`, `forwarder_started` |
| `session` | Short session identifier. The full identifier is in `data.session_key`. |
| `framework` / `agent` | Source, e.g. `claude_code`, `openclaw`, or `agent_sensor` for the agent-sensor's own events |
| `text` | Prompt or response text — `[REDACTED:*]` unless content capture is on |
| `has_injection`, `injection_patterns`, `triggered_rules`, `max_severity` | Detection results, present when a rule fired |
| `host`, `user`, `os`, `arch`, `forwarder`, `schema` | Endpoint and agent-sensor metadata |
| `data` | Source-specific detail, e.g. `action`, `session_key`, `vendor` |

> **Note:** For OpenClaw, `session` is the first 8 characters of a key such as `agent:main:main`, so different sessions of the same agent share a `session` value. Use `data.session_key` to tell OpenClaw sessions apart.

---

## Configuration Reference

`~/.agent-sensor/config.toml` is generated by `--auto-config` and never overwritten afterwards. The TOML loader does **not** expand `~` — use absolute paths. Restart the agent-sensor after every change, and run `agent-sensor check-config` first (it does not catch every runtime error: a webhook sink without a token, for example, passes `check-config` but exits with code 78 on start).

### `[sources]`

Sources are detected automatically — `[sources]` takes no keys. Run `agent-sensor detect-sources` to see what was found.

| Source slug | Detected when |
|-------------|---------------|
| `claude-code-cli` | Claude Code is installed |
| `claude-desktop` | Claude Desktop is installed |
| `antigravity` | `~/.gemini/antigravity-cli` exists |
| `openclaw-ws` | `[openclaw]` is configured (see below) |

Codex CLI and Gemini CLI events arrive through the hook server (`/codex`, `/gemini`) rather than a source.

### `[[sinks]]`

Each `[[sinks]]` table is one destination. Every event is sent to every sink.

| Key | Applies to | Description |
|-----|-----------|-------------|
| `kind` | all | `jsonl`, `sqlite`, `webhook`, or `chroma` |
| `name` | all | Sink name, used by `replay-dlq --sink <NAME>` and in logs |
| `channel_capacity` | all | In-memory queue size for the sink |
| `path` | `jsonl`, `sqlite` | Absolute file path |
| `rotation_size_mb`, `max_rotated_files` | `jsonl` | Rotation (defaults `100` and `5`) |
| `url` | `webhook`, `chroma` | Destination URL |
| `token_file` | `webhook` | File containing the bearer token (or set `AGENT_SENSOR_WEBHOOK_TOKEN`). Required. |
| `max_attempts`, `base_delay_ms`, `max_delay_ms` | `webhook` | Retry policy (defaults `6`, `1000`, `30000`). After the last attempt, the event is written to `dlq.jsonl`. |
| `chroma_collection` | `chroma` | Collection name (created if missing) |
| `chroma_api_version` | `chroma` | Chroma HTTP API version. **Set `"v2"` for Chroma 1.x** — the default fails with HTTP 405 and those events are not saved to the DLQ. |

**JSONL** (default):

```toml
[[sinks]]
kind = "jsonl"
path = "/Users/you/.agent-sensor/events.jsonl"
rotation_size_mb = 100
max_rotated_files = 5
```

**SQLite** — one row per event in table `events` (WAL mode). Not encrypted by `--enable-local-encryption`. In 1.0.5 the `prompt` column is not populated; read prompt text from the JSONL sink.

```toml
[[sinks]]
kind = "sqlite"
name = "local-db"
path = "/Users/you/.agent-sensor/events.db"
```

**Webhook** — see [Forward events to Exabeam](#forward-events-to-exabeam).

**Chroma** — each event is stored as a document in a Chroma collection, for semantic search over agent activity.

```toml
[[sinks]]
kind = "chroma"
name = "chroma"
url = "http://localhost:8000"
chroma_collection = "agent_sensor_events"
chroma_api_version = "v2"
```

### `[redaction]`

Prompt and response text is replaced with `[REDACTED:*]` before events leave the host. Redaction runs **after** detection, so injection scanning and SIEM rules see the full text either way. Built-in patterns (AWS keys, bearer tokens, JWTs, API keys, passwords, emails, IPs) are always removed.

| Key | Default | Description |
|-----|---------|-------------|
| `censor_request` | `true` | Redact prompt text. `--auto-config --capture-content` writes `false`. |
| `censor_response` | `true` | Redact model output. `--auto-config --capture-content` writes `false`. |
| `max_request_chars` | `256` | Maximum prompt excerpt length when not censored (`0` = unlimited) |
| `max_response_chars` | `256` | Maximum response excerpt length when not censored (`0` = unlimited) |

### `[encryption]`

| Key | Default | Description |
|-----|---------|-------------|
| `enabled` | `false` | Encrypt the JSONL sink and `dlq.jsonl` at rest (same as `--enable-local-encryption`) |
| `key_env_var` | `AGENT_SENSOR_KEY` | Environment variable holding the key |

Read encrypted files with `agent-sensor decrypt-events <PATH>`.

### `[openclaw]`

| Key | Description |
|-----|-------------|
| `enabled` | `true` to connect to the OpenClaw gateway |
| `host`, `port` | Gateway address, taken from `~/.openclaw/openclaw.json` by `--auto-config` |
| `token_file` / `token` | Optional. Overrides the gateway token read from `~/.openclaw/openclaw.json` (`gateway.auth.token`). |

The token is read when the agent-sensor starts — restart it after rotating the gateway token. See [Installation → OpenClaw](installation.md#openclaw).

### `[dedup]`

Agent CLIs can fire both global and project-level hooks for one action. Dedup drops a payload already seen within the window. Enabled by default; distinct tool calls (unique `tool_use_id`) are never merged.

```toml
[dedup]
enabled = true
window_ms = 2000
```

### `[reconcile]`

Off by default. When enabled, a long-running agent-sensor periodically detects agent CLIs installed after setup and installs their hooks (user scope only; already-configured CLIs are skipped).

```toml
[reconcile]
enabled = true
interval_secs = 300
```

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Runtime error |
| `3` | Hook port unavailable (bind failed or outside `--port-range`) |
| `78` | Configuration error (malformed config or port outside explicit range) |

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `RUST_LOG` | Log filter, e.g. `RUST_LOG=debug` |
| `AGENT_SENSOR_KEY` | Encryption key for `--enable-local-encryption` (name configurable via `[encryption] key_env_var`) |
| `AGENT_SENSOR_WEBHOOK_TOKEN` | Bearer token for webhook sink (alternative to `token_file` in config) |
| `AGENT_SENSOR_PROJECT_DIR` | Project directory (same as `--project-dir` flag) |

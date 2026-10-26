# Changelog

All notable changes to `agent-sensor` are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## Unreleased

---

## [1.0.5] — 2026-09-16

### Added
- **OpenClaw support.** `--auto-config` detects a local OpenClaw install (`~/.openclaw/openclaw.json`) and adds an `[openclaw]` block to the generated `config.toml`. The agent-sensor connects to the OpenClaw gateway over WebSocket and streams live agent activity through the same pipeline and sinks as the CLI hooks. The gateway auth token is read from OpenClaw's own config, so no copy of the secret is written to `config.toml`. See [Installation → OpenClaw](installation.md#openclaw).
- **Antigravity source.** Tails Antigravity transcripts under `~/.gemini` (source slug `antigravity`).
- `--capture-content` flag. Prompts and model output are censored (`[REDACTED:*]`) by default before events leave the host; `--capture-content` writes `censor_request = false` / `censor_response = false` into the generated config so the text is forwarded. Injection scanning and detection rules see the full text either way.
- `decrypt-events` subcommand to read back a file written with `--enable-local-encryption`. `replay-dlq` decrypts automatically.

### Changed
- `--enable-local-encryption` covers the JSONL sink and the dead-letter queue. The SQLite sink is **not** encrypted at rest.

### Security
- The Windows binary is now Authenticode-signed (DigiCert). Releases are created as drafts and are only published after the Windows `.exe` has been signed and verified, so an unsigned Windows binary is never publicly downloadable.

### Known issues
- `agent-sensor --version` and `agent-sensor status` report `1.0.4` on the 1.0.5 binaries. Verify the version you installed by its SHA-256 against the release assets.
- `replay-dlq` fails with ``missing field `triggered_rules``` for dead-letter entries whose event triggered no detection rule, so those events cannot be replayed.
- OpenClaw: the `session` field holds only the first 8 characters of the session key (e.g. `agent:ma`), so sessions of the same agent share a value. Use `data.session_key`.
- OpenClaw: a rotated gateway token is not picked up until the agent-sensor is restarted.
- Chroma sink: with Chroma 1.x, set `chroma_api_version = "v2"`. Otherwise writes fail with HTTP 405 and those events are not saved to the dead-letter queue.

---

## [1.0.4] — 2026-06-26

### Added
- Initial public release.

# Homebrew formula for agent-sensor (https://agentsensor.exabeam.com)
#
# This repo is not named `homebrew-*`, so it can't be tapped with the short
# `brew tap ExabeamLabs/agent-sensor-dist` syntax. Tap it with the full URL:
#
#   brew tap ExabeamLabs/agent-sensor https://github.com/ExabeamLabs/agent-sensor-dist
#   brew install agent-sensor
#
# To bump this formula for a new release: update `version`, then replace both
# `sha256` values with the output of:
#   shasum -a 256 agent-sensor-v<VERSION>-aarch64-apple-darwin agent-sensor-v<VERSION>-x86_64-apple-darwin

class AgentSensor < Formula
  desc "Endpoint collector for Agent Behavior Analytics (ABA) — captures AI CLI telemetry"
  homepage "https://agentsensor.exabeam.com"
  version "1.0.4"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/ExabeamLabs/agent-sensor-dist/releases/download/v#{version}/agent-sensor-v#{version}-aarch64-apple-darwin"
      sha256 "d488a6a569d61690c6f68347b4d361021c3d11ca4b6111f19cb0f21dc3efb920"
    else
      url "https://github.com/ExabeamLabs/agent-sensor-dist/releases/download/v#{version}/agent-sensor-v#{version}-x86_64-apple-darwin"
      sha256 "a7b5c87bf59c7ca3c48e75cf13090530bbd25af2dd42552407dd9e61e7477bf7"
    end
  end

  livecheck do
    url :stable
    strategy :github_latest
  end

  def install
    # The release asset is a bare Mach-O binary (no archive), downloaded
    # into the staging dir under its original release filename.
    downloaded = Dir["agent-sensor-v*"].first
    odie "could not find downloaded agent-sensor binary in staging dir" unless downloaded
    bin.install downloaded => "agent-sensor"
  end

  def caveats
    <<~EOS
      agent-sensor is installed but not yet configured or running.

      Install CLI hooks (Claude Code, Codex CLI, Gemini CLI) and generate
      the default config:
        agent-sensor --auto-config

      Register it as a background launchd service:
        agent-sensor install-service

      Docs: https://agentsensor.exabeam.com/docs/installation.html
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/agent-sensor --version")
  end
end

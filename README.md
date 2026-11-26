# OpenUsage

> [!NOTE]
> This is a maintained `v0.7` fork of [robinebers/openusage](https://github.com/robinebers/openusage), branched from `v0.7.16` before the `v0.8.0` rewrite. It preserves the `v0.7` UI, local credential discovery, local spend/token estimates, and local HTTP API while backporting provider fixes (such as Antigravity's updated Cloud Code quota endpoints and Argon weekly quota). Releases are ad-hoc signed Apple Silicon (`arm64`) builds with Sparkle auto-updates and iCloud sync disabled.

Track your AI coding subscriptions from the macOS menu bar — native Swift edition.

OpenUsage shows how much of your AI coding plans you've used: session and weekly limits, credits, and spend, all in one popover. Pin your most important metrics straight into the menu bar.

<p align="center">
  <img src="assets/screenshot.jpg?v=20260706" alt="OpenUsage menu bar tracker showing Claude and Codex session, weekly, and spend usage" width="900">
</p>

## Installation

**Homebrew:**

```sh
brew install --cask manojkarthick/tap/openusage
```

For beta releases, install `manojkarthick/tap/openusage@beta` instead. It gets every beta and every stable release. The two casks conflict, so uninstall one before installing the other.

If you already have an older `OpenUsage.app` in `/Applications`, pass `--force` to replace it. The cask also clears the macOS quarantine attribute automatically and links the `openusage` CLI to `/opt/homebrew/bin/openusage`.

**Direct download:** grab the latest `arm64` DMG from the [releases page](https://github.com/manojkarthick/openusage/releases/latest), drag `OpenUsage.app` to `/Applications`, and clear the quarantine flag since builds are ad-hoc signed:

```sh
xattr -dr com.apple.quarantine /Applications/OpenUsage.app
```

Requires macOS 15 (Sequoia) or later on Apple Silicon (`arm64`). Updates are delivered via Homebrew (`brew upgrade --cask openusage`) rather than Sparkle.

## Supported Providers

- **[Antigravity](docs/providers/antigravity.md)** — shared Gemini and Claude pool quotas (5-hour and weekly) plus Gemini 4 Argon weekly quota
- **[Claude](docs/providers/claude.md)** — session, weekly, model-specific limits, extra usage, local daily spend
- **[Codex](docs/providers/codex.md)** — session, weekly, credits, local daily spend
- **[Copilot](docs/providers/copilot.md)** — AI credits, extra usage, organization billing, chat and completions
- **[Cursor](docs/providers/cursor.md)** — credits, total usage, Grok Bot, Cursor Models, Other Models, requests, on-demand, per-day spend
- **[Devin](docs/providers/devin.md)** — weekly and daily quota, extra usage balance
- **[Grok](docs/providers/grok.md)** — weekly shared pool, pay-as-you-go, local daily spend
- **[Ollama](docs/providers/ollama.md)** — Ollama Cloud monthly credits (or session and weekly limits on legacy plans), purchased credits
- **[OpenCode](docs/providers/opencode.md)** — Go session/weekly/monthly caps, Zen spend, local daily spend
- **[OpenRouter](docs/providers/openrouter.md)** — credit balance, daily/weekly/monthly spend (API key)
- **[Z.ai](docs/providers/zai.md)** — session, weekly, web-search quotas (GLM Coding Plan, API key)

Most providers read the credentials already on your machine (keychain, auth files, app state) — no extra login. OpenRouter and Z.ai are the exceptions: they have no local credential to reuse, so you supply an API key (see [OpenRouter setup](docs/providers/openrouter.md) or [Z.ai setup](docs/providers/zai.md)). Credentials are used only for the corresponding provider requests. OpenUsage's separate anonymous summaries and public pricing downloads are documented under [Privacy & usage data](docs/privacy.md).

## Features

- **Menu bar pins.** Pin metrics to the menu bar (up to 2 per provider); render as compact text or mini bars. The strip hides metrics with no data instead of showing placeholders.
- **Dashboard popover.** Provider-grouped meters with live reset countdowns and pace indicators. Click usage or reset values to flip their display everywhere; right-click a row to hide or star it, refresh its provider, or open Customize.
- **Global shortcut.** Toggle the popover from anywhere — record any combo in Settings.
- **Customize.** Turn providers and metrics on or off, choose which rows stay Always Visible or On Demand, and drag-reorder both.
- **Stale-while-revalidate.** Cached values display instantly at launch; refresh runs every 5 minutes.
- **[One-shot CLI](docs/cli.md).** Agents can read stable limit JSON through the same five-minute cache with `openusage`, or bypass freshness with `openusage --force`; the menu-bar app does not need to be running.
- **[Local HTTP API](docs/local-http-api.md).** Other apps can read machine-friendly limits from `127.0.0.1:6736/v1/limits`; the legacy `/v1/usage` UI contract remains supported. It is loopback-only and never serves credentials; note that browser pages can read it too — see the [privacy note](docs/local-http-api.md#cors-and-privacy).
- **[Proxy support](docs/proxy.md).** Route provider requests through SOCKS5 or HTTP(S) via `~/.openusage/config.json`.
- **Native settings.** Launch at login, global shortcut, icon style, theme, density, 12/24-hour time — see [Settings](docs/settings.md).



## Documentation

Behavior docs live in [docs/](docs/README.md): the [dashboard](docs/dashboard.md), [menu bar pins](docs/menu-bar.md), [settings](docs/settings.md), [refresh & caching](docs/refreshing.md), the [CLI](docs/cli.md), the [local HTTP API](docs/local-http-api.md), the [proxy](docs/proxy.md), and one page per provider.

For working on the code, see the developer docs: [architecture](docs/architecture.md), [adding a provider](docs/adding-a-provider.md), and [debugging & capturing logs](docs/debugging.md).

## Requirements

- macOS 15 (Sequoia) or later
- Apple Silicon (`arm64`)

The Today / Yesterday / Last 30 Days spend tiles are computed natively from local CLI logs (Claude,
Codex, and Grok) or Cursor's usage export — no Node.js or other runtime needed. Dollars are estimated
with [dynamically refreshed model pricing](docs/pricing.md).



## Building

```sh
swift build            # debug build
swift test             # run the test suite
./script/build_and_run.sh   # build and launch the dev app from dist/ (no install)
```



## Architecture

SwiftPM package, SwiftUI content hosted in an AppKit-owned `NSStatusItem` + custom key-capable `NSPanel`, Swift 6 strict concurrency. The app and CLI share one module: providers implement a small `ProviderRuntime` protocol (auth store → usage client → mapper → `ProviderSnapshot`), and both surfaces read the same normalized data — see the [architecture overview](docs/architecture.md) for how the pieces fit together and [AGENTS.md](AGENTS.md) for engineering conventions.

## Releasing

Run the **Release** workflow ([.github/workflows/release.yml](.github/workflows/release.yml)) from the Actions tab or with `gh workflow run release.yml -f channel=stable` (or `beta`). It releases the tip of `v0.7`:

- picks the next version: `0.7.x` for stable, `0.7.x-beta.N` for beta. The fork stays on `0.7.x`.
- writes the changelog with [git-cliff](https://git-cliff.org) ([cliff.toml](cliff.toml)) and commits it to `CHANGELOG.md`,
- tags the release and publishes the GitHub Release (betas as pre-releases),
- runs `swift test`, builds the `arm64` ad-hoc signed DMG via [script/release.sh](script/release.sh), and attaches it,
- bumps the casks in `manojkarthick/homebrew-tap`: stable bumps `openusage` and `openusage@beta`, beta bumps only `openusage@beta`.

PRs into `v0.7` are squash-merged, so the PR title (a Conventional Commit such as `fix(cursor): …`) becomes the changelog entry. The only secret is `HOMEBREW_TAP_TOKEN`, a fine-grained PAT with Contents read/write on `manojkarthick/homebrew-tap`.

## License

[MIT](LICENSE)

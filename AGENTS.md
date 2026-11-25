# AGENTS.md

OpenUsage is a SwiftPM-based SwiftUI menu-bar app for macOS that shows AI provider usage widgets (Claude, Codex, Cursor, Grok, Devin, and more).

This file documents the engineering conventions for the project. Read it before contributing.

## Agent Instructions

AGENTS.md is the source of truth for agent instructions in this repository. CLAUDE.md files may only point to the nearest AGENTS.md file with `@AGENTS.md`; do not add guidance, duplicate instructions, or project rules to CLAUDE.md.

> **Repository note:** This is the native Swift edition of OpenUsage. In this fork, active development happens on the `v0.7` branch; `main` mirrors upstream. (NOT the legacy Tauri version which now sits in the `tauri-legacy` branch)

## Releases

In this fork, `v0.7` is the active development line. Releases are cut by running `.github/workflows/release.yml` (manual dispatch, `stable` or `beta`): it picks the next version, writes the changelog with git-cliff (`cliff.toml`) and commits it to `CHANGELOG.md`, tags, publishes the GitHub Release, builds and attaches an ad-hoc signed arm64 DMG, and bumps the Homebrew cask in `manojkarthick/homebrew-tap`. There's no Sparkle feed. See the release-swift skill.

### Guardrails (do not break)
- Versions stay `0.7.x` for good — upstream's `0.8` is a fundamental redesign, and the fork's numbering marks it as branched from the old line. Never reuse a `0.6.x` number (the original edition's tags, frozen on `tauri-legacy`) and never move to `0.8`, whose upstream tags already exist on this fork's remote.
- **Never increase the version number on your own initiative — always ask for explicit approval first.** Never run the Release workflow or push a tag without explicit sign-off.
- PRs into `v0.7` are squash-merged with the PR title, which must be a Conventional Commit; git-cliff groups the changelog by its type.
- Beta releases use `-beta.N` tags and stay GitHub pre-releases. Stable releases use plain tags and become GitHub "Latest". Both update the Homebrew cask.
- Never leave a release in Draft, and never ship blank notes: the Release workflow verifies the published release (not a draft, DMG attached, notes present) after every cut.

## Architecture

- SwiftPM executable target; SwiftUI content hosted in an AppKit-owned `NSStatusItem` + custom key-capable `NSPanel`.
- Swift 6 with strict concurrency.
- Providers implement the small `ProviderRuntime` protocol: an auth store reads credentials already on the user's machine, a usage client calls the provider's API, and a mapper normalizes the response into `MetricLine` values. The UI renders those normalized values.
- See `docs/` for behavior docs and the developer docs (architecture overview, adding a provider).

## Providers

Conventions for the per-provider modules under `Sources/OpenUsage/Providers/<Name>/`.

- **Structure:** one folder per provider with an auth store (reads credentials already on the user's machine), a usage client (calls the provider API), and a mapper (normalizes to `MetricLine`), conforming to `ProviderRuntime` — `refresh()` plus `hasLocalCredentials()`, the local-only credential probe used by the welcome screen's detection (`FirstLaunchSetup`) and by new-provider detection on the first launch after the provider ships (`NewProviderSeeder`); mirror the same local credential sources and usability filters that `refresh()` starts with, reusing the auth-store loaders instead of adding a second credential-reading path. See `docs/adding-a-provider.md` and `docs/provider-enablement.md`.
- **Model pricing:** all spend imputation (Claude, Codex, Cursor, Grok) prices through the shared engine in `Sources/OpenUsage/Pricing/` (see `docs/pricing.md`). Cursor-native model rates and alias rules live in `Sources/OpenUsage/Resources/pricing_supplement.json` — sync new or changed models from [Cursor models & pricing](https://cursor.com/docs/models-and-pricing.md) (update `updated_at`, pricing entries, and `alias_rules` for CSV model slugs); merging to `main` publishes it to gh-pages, so installed apps pick it up without a release. The bundled LiteLLM/models.dev snapshots regenerate with `script/update_pricing_snapshots.sh` (a release-time chore).
- **Default order:** Claude, Codex, Cursor first (the established providers, in that order), then every other provider alphabetically by display name (Antigravity, Devin, Grok, …). The order is the array order in `AppContainer`, which seeds `LayoutStore`'s default provider order (and `resetToDefault`). A new provider slots into the alphabetical tail.
- **Metric placement defaults:** when adding or changing a metric, confirm its four defaults with the owner before choosing — never pick silently:
  1. enabled on/off (`DefaultLayout.metricIDs`),
  2. Always Visible vs. On Demand — above the fold vs. behind the per-provider caret (`DefaultLayout.expandedMetricIDs`). Note: a provider always keeps at least one Always Visible row — the dashboard promotes all metrics when every one is marked On Demand, so a fully On Demand provider isn't possible; leave one metric Always Visible for the caret to appear,
  3. pinned to the menu bar (`DefaultLayout.pinnedMetricIDs`),
  4. order (within a provider, the `widgetDescriptors` declaration order).

## Running / Testing Changes

- There is no hot reload. The app is a long-lived menu-bar process, so **every code change requires a full rebuild and restart of the running app** to take effect — kill the running instance, rebuild, and relaunch before testing.

## Pull Requests

Every PR description must follow this structure so reviewers can skim it quickly:

- **TL;DR** — open with a one- or two-sentence plain-English summary of the change.
- **What was happening** — plain-English bullet points describing the prior behavior, bug, or gap that motivated the change.
- **What this changes** — bullet points describing what the PR actually changes.
- **Heads-up** (optional) — noteworthy things a reviewer or future maintainer should consider (risks, follow-ups, trade-offs).
- **Tests** (optional) — how the change was verified.
- **Screenshots** (optional in general, but **required for any PR that makes a visual change**) — images of the affected UI after the change.

## Documentation

- Logic changes must update any docs in `docs/` that describe the affected behavior.
- Keep docs simple, less-technical, and easy to skim; exclude visual design details.

## Code Conventions

- Add a regression test when fixing a bug, where it fits.
- Keep files under ~500 LOC; split or refactor as needed.
- No new dependencies without justification.
- When adding a provider, follow the conventions in "## Providers".

## Error Handling

Always fail loudly into error logging (log file) and show friendly errors to the user. Do not add silent fallbacks that hide real problems. Only validate at system boundaries (user input, external APIs); trust internal code and framework guarantees.

## UI

- Use title case for any hardcoded copy used as a title.
- Match the existing design language; OpenUsage has a specific look and feel.
- Only add tooltips (`hoverTooltip`) when explicitly asked to. Don't add them proactively to new controls.

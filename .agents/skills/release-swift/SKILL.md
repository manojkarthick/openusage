---
name: release-swift
description: Ship a release of this OpenUsage fork (Swift menu-bar app) by dispatching the Release workflow — stable or beta — then confirm the GitHub Release and Homebrew cask. Use to ship a beta or a stable release, preview the next changelog, or debug a failed release run.
---

# Release Swift

This fork releases from the `v0.7` branch of `manojkarthick/openusage` through one manually dispatched workflow. Nothing is tagged, uploaded, or pushed to the tap by hand.

| File | Role |
|---|---|
| `.github/workflows/release.yml` | Dispatch (`channel`: `stable` or `beta`): version → changelog → tag + GitHub Release → DMG → Homebrew cask |
| `.github/workflows/build-dmg.yml` | Called by it: `swift test`, `script/release.sh`, upload DMG, verify the release |
| `cliff.toml` | git-cliff changelog config (sections, PR links, `by @author`, full commit list) |

The tag IS the version: `v0.7.20-beta.1` becomes `CFBundleShortVersionString = 0.7.20-beta.1`, and `CFBundleVersion` is the git commit count. There are no version files to bump.

## Versioning

Always `0.7.x` — the fork never moves to `0.8` (upstream's redesign, whose tags exist on the remote). The workflow picks the version from tags:

- **Stable:** next patch after the last stable tag (`v0.7.19` → `v0.7.20`). Notes span last stable → this one, rolling up the whole beta series. Marked GitHub "Latest".
- **Beta:** `-beta.N` on that next patch (`v0.7.20-beta.1`, then `-beta.2`, …). Notes span the previous beta (or last stable for the first beta). Marked a pre-release.

Betas update only the `openusage@beta` cask. Stables update both `openusage` and `openusage@beta`, so beta users move to each stable too.

## Cutting a release

1. Preview the changelog locally (no install needed):
   ```sh
   GITHUB_TOKEN=$(gh auth token) uvx git-cliff v0.7.19..origin/v0.7 --tag v0.7.20 --ignore-tags beta
   ```
   For a beta, start the range at the last beta (if any) and drop `--ignore-tags beta`.
2. Show the owner the version and preview. **Wait for explicit approval.** Fix wording by editing the PR titles' commits before releasing — or edit the GitHub Release notes and `CHANGELOG.md` afterwards.
3. Dispatch and watch:
   ```sh
   gh workflow run release.yml -R manojkarthick/openusage -f channel=stable   # or beta
   gh run watch -R manojkarthick/openusage $(gh run list -R manojkarthick/openusage -w Release -L 1 --json databaseId -q '.[0].databaseId')
   ```

The run commits `docs: changelog for v<version>` to `v0.7`, tags it, publishes the GitHub Release with the notes, builds and attaches `OpenUsage-<version>.dmg`, verifies the release (not a draft, correct pre-release flag, DMG attached, notes non-empty), and pushes the `version`/`sha256` bump to `Casks/openusage@beta.rb` (and, for stable, `Casks/openusage.rb`) in `manojkarthick/homebrew-tap`.

## When a run fails

- **`prepare` failed before pushing:** nothing was published; fix and dispatch again. "No commits since …" means there's nothing to release.
- **`build` or verify failed:** the tag and release already exist. Re-run the failed jobs (`gh run rerun <id> --failed`); the upload uses `--clobber`, so it's safe. Don't dispatch again — that would cut the next version.
- **`homebrew` failed:** check the `HOMEBREW_TAP_TOKEN` secret (fine-grained PAT, Contents read/write on `manojkarthick/homebrew-tap`) and re-run the failed job.
- Never leave a release in Draft or with blank notes.

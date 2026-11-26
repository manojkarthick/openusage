# Porting Fixes from Upstream

This fork branches from [robinebers/openusage](https://github.com/robinebers/openusage) at `v0.7.16` (on branch `v0.7`) to preserve the `v0.7` UI, local credential discovery, local spend/token estimates, and local HTTP API. Upstream `v0.8.0+` rewrote account management and the dashboard, so most upstream provider fixes need to be adapted rather than merged directly.

## 1. Fetch upstream changes

Add the `upstream` remote if it is not already configured, then fetch:

```sh
git remote add upstream https://github.com/robinebers/openusage.git  # once
git fetch upstream --tags
```

Inspect upstream commits since `v0.7.16` (or filter to a specific provider):

```sh
git log --oneline v0.7.16..upstream/main -- Sources/OpenUsage/Providers/
git log --oneline v0.7.16..upstream/main -- Sources/OpenUsage/Providers/Antigravity/
```

Inspect a candidate commit in full before porting:

```sh
git show <sha>
```

## 2. Key differences between `v0.7` and upstream `v0.8+`

Keep these architectural differences in mind when translating a patch:

- **Credentials & discovery:** `v0.8+` removed local credential discovery (`*AuthStore`, Keychain readers, local DBs, language server discovery) in favor of browser OAuth / account sign-in (`AccountStore`). Keep `v0.7`'s auth and discovery code intact; port only the API request headers, URLs, payloads, and response parsing.
- **Error handling:** `v0.8+` throws unified `ProviderError` cases (`.signInExpired`, `.unavailable`, `.failed`). `v0.7` uses per-provider error types and outcome enums (for example `CloudCodeOutcome` and `AntigravityError`). Map new HTTP status handling onto the existing `v0.7` enums.
- **Metrics & tests:** `MetricLine.progress` in `v0.7` has an extra associated value compared to `v0.8+`, so test helpers pattern-matching `.progress(...)` need 7 fields instead of 6.
- **UI & layout:** Skip `v0.8+` dashboard, menu-bar, and account-unification commits (`Priority` / `All Usage` tabs).

## 3. Apply and verify the fix

For small, self-contained mapper or client fixes, you can start with a non-committing cherry-pick to inspect conflicts, or apply the diff directly:

```sh
git cherry-pick --no-commit <sha>
```

After adapting the code and unit tests:

1. Run the full test suite:
   ```sh
   swift test
   ```
2. Optional local smoke test against your real settings (without overwriting `/Applications/OpenUsage.app`):
   ```sh
   BUNDLE_ID=com.robinebers.openusage ./script/build_and_run.sh
   ```
3. Commit with a Conventional Commit message referencing the upstream PR/commit (e.g., `Port of upstream robinebers/openusage#1641`) and add an entry to the table at the bottom of this file.

## 4. Cut a release and update the Homebrew cask

1. Merge the port to `v0.7` (squash; the PR title must be a Conventional Commit such as `fix(antigravity): …`).
2. Run the **Release** workflow and follow it:
   ```sh
   gh workflow run release.yml --repo manojkarthick/openusage -f channel=stable
   gh run watch --repo manojkarthick/openusage
   ```
   It picks the next `0.7.x`, writes the changelog, tags, publishes the GitHub Release with the DMG, and bumps the casks in `manojkarthick/homebrew-tap` (`openusage` and `openusage@beta` for stable, only `openusage@beta` for beta).
3. Upgrade on any Mac:
   ```sh
   brew update && brew upgrade --cask openusage
   ```

## Backported upstream fixes

| Fork version | Upstream PR / commit | Summary |
| --- | --- | --- |
| `v0.7.17` | `#1641` (`ee98159`), `#1676` (`e1ffa57`) | Antigravity: use `antigravity/hub/2.24.0` User-Agent, prefer `daily-cloudcode-pa` for quota summaries, and preserve sub-1% session usage |

# Privacy & Usage Data

OpenUsage sends **no analytics, no usage telemetry, and no crash reports**, and it keeps no analytics or
install ID. Your usage numbers are read and shown on your Mac; the only network calls it makes are listed
below.

## Credentials stored on this Mac

OpenUsage primarily reads credentials that provider tools already keep on your Mac. When it writes a
user-supplied API key or saves a refreshed credential, the file is replaced atomically and restricted to
your macOS account (owner read and write only). Antigravity's short-lived refreshed-token cache is tied
to the current Keychain login using a one-way fingerprint; the refresh credential itself is not copied.
The cache is never used after logout, an account change, or while Keychain access is unavailable.

Claude Desktop access is strictly read-only. OpenUsage may ask macOS for permission to use the
`Claude Safe Storage` Keychain item so it can decrypt Desktop's current access token. It never uses
Desktop's rotating refresh token and never modifies Desktop's config, cookies, or Keychain data.


## Network requests

- **Provider APIs** — the same usage calls the vendor's own tools would make, using credentials already
  on your Mac.
- **Model price lists** — public [model price lists](pricing.md) about once an hour (from
  `raw.githubusercontent.com`, `models.dev`, and this project's GitHub Pages). These are plain downloads
  of public data and carry no usage, log, or account information.
- **Update checks** — none. This fork's builds don't check for new versions; see [Updates](updates.md).
- **iCloud Sync** — only if you turn it on (see below).

The spend tiles are computed from local CLI logs entirely on your Mac; no log data ever leaves it.

## Data stored on this Mac

To avoid re-reading unchanged Claude, Codex, and pi logs after every relaunch, OpenUsage keeps their
parsed usage events in `~/Library/Application Support/OpenUsage/log-scan-cache/`. These records contain
the usage metadata needed for local totals, including any per-event cost already recorded by a provider,
but not raw JSONL lines or conversation text. They are private to your macOS account and are never sent
to a provider or iCloud. Old source-file records are dropped as the scan window advances, and
identity caches that have not been used for 35 days are removed. OpenUsage's pricing engine runs after
the cache is read, so its computed aggregates and totals are not persisted in this cache.

## Data left by older builds

Builds from before telemetry was removed stored an anonymous install ID, queued analytics events, and
crash reports on your Mac. OpenUsage deletes them at launch:

- the `<bundle id>.telemetry` preferences,
- `~/Library/Application Support/<bundle id>/phc_*/` (the analytics library's storage),
- `~/Library/Caches/com.plausiblelabs.crashreporter.data/<bundle id>/` (crash reports),
- the analytics library's version keys in the app's own preferences.

`<bundle id>` is `com.robinebers.openusage`.

## iCloud Sync

If you explicitly turn on [iCloud Sync](icloud-sync.md), OpenUsage writes normalized daily tokens,
spend, and model totals to its private iCloud container so your own Macs can show one combined summary.
Credentials, account limits, provider responses, and raw logs are never written there. iCloud Sync
defaults off and uses your own iCloud account.

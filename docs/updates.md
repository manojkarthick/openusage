# Updates

This fork's builds don't update themselves. The app contains [Sparkle](https://sparkle-project.org),
the standard Mac update framework, but release builds ship without an update feed, so it never checks
for or downloads anything. There's no **Check for Updates…** menu item and no **Updates** section in
Settings.

## Getting a new version

- **Homebrew:** `brew upgrade --cask openusage` (or `openusage@beta` on the beta channel).
- **Direct download:** get the latest DMG from the fork's
  [GitHub releases](https://github.com/manojkarthick/openusage/releases/latest) and replace the app in
  Applications. Builds are ad-hoc signed, so clear the quarantine flag as described in the
  [README](../README.md#installation).

Your settings carry over; see [Settings § Version](settings.md#version).

## If a feed is added later

Sparkle only starts when the app's `Info.plist` has an `SUFeedURL` (see `UpdaterController`). With one,
the app checks hourly, shows an **Update Available** banner at the top of the popover, and shows the
**Updates** section in Settings (Check Automatically, Beta Updates, Check for Updates…).

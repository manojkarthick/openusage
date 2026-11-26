# Updates

Release builds update themselves in place with [Sparkle](https://sparkle-project.org) from this fork's
appcast feed (`https://manojkarthick.github.io/openusage/appcast.xml`). Every update archive is signed
with an EdDSA key baked into the app bundle (`SUPublicEDKey`), and Sparkle strips the quarantine flag
before relaunching so ad-hoc signed updates install cleanly.

## How it works

- **Background checks:** Sparkle checks the feed hourly when **Check Automatically** is on. If a newer
  version is available, an **Update Available** banner appears at the top of the popover instead of
  stealing focus. Clicking **Install Update** opens Sparkle's release notes and install prompt in front;
  closing the banner snoozes it until the next scheduled check.
- **Manual checks:** open **Settings → Updates** and click **Check for Updates…**.
- **Channels:** **Beta Updates** is off by default (stable `0.7.x` releases only). Turning it on adds
  `0.7.x-beta.N` pre-releases (`<sparkle:channel>beta</sparkle:channel>`) while continuing to receive
  stable releases — when the stable release ships, beta users move onto it automatically.
- **Local developer builds:** `swift run` and `./script/build_and_run.sh` ship no `SUFeedURL`, so the
  updater stays dormant and the **Updates** section stays hidden.

## Other ways to install or update

- **Homebrew:** `brew install --cask manojkarthick/tap/openusage` (or `openusage@beta`). Both casks
  mark `auto_updates true`, so once installed Sparkle handles updates in place; you can still force a
  Homebrew upgrade with `brew upgrade --cask --greedy openusage`.
- **Direct download:** get the latest DMG from the fork's
  [GitHub releases](https://github.com/manojkarthick/openusage/releases/latest) and replace the app in
  Applications. Builds are ad-hoc signed, so clear the quarantine flag on first install as described in
  the [README](../README.md#installation).

Your settings carry over across updates; see [Settings § Version](settings.md#version).

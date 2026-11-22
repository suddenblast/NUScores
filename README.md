# NU Scores

A personal iPhone app for live Northwestern women's field hockey and lacrosse scores, in the style of Apple Sports. Scores show on the Home screen, the lock screen and the Dynamic Island through a Live Activity.

It's a one-person app, installed through Xcode. It isn't on the App Store.

## What it does

- **Home screen:** Live, Upcoming and Recent games, newest first. Green and red dots mark wins and losses.
- **Game detail:** score, score by period, and a goal list with game times.
- **Live Activity:** lock screen and Dynamic Island, with the score, quarter, clock and last goal.
- **Alerts:** goals, quarter starts and the final, delivered through the Live Activity (push is still being set up).

## How it works

```
NCAA.com live feed  ->  Cloudflare Worker  ->  this app
```

- A separate Cloudflare Worker polls the game feed during games, works out what happened (goal, new quarter, final) and serves the current games as JSON.
- This app reads that JSON. The Worker is in a different project (`nu-score-recorder`) and isn't part of this repo.
- Regular-season lacrosse uses a different source (StatBroadcast), which isn't supported yet.

## Setup

You need a Mac with Xcode 27 and an iPhone running iOS 17.2 or later. Live Activity push also needs a paid Apple Developer account.

1. Open `NUScores.xcodeproj` in Xcode.
2. Copy `Config.swift.example` to `NUScores/Config.swift` and fill in your Worker URL and admin key. `Config.swift` is git-ignored, so the key stays off GitHub.
3. In Signing & Capabilities, choose your team and set a unique bundle ID for both the app and the widget. The widget's ID must start with the app's ID.
4. Run the **NUScores** scheme (not the widget scheme).

In debug builds, the **Demo** button on the home screen replays a recorded game through the Live Activity, which is useful for testing without a live game.

## Status

| Piece | State |
|---|---|
| Home and game detail screens | Working, with real data |
| Live Activity (lock screen and Dynamic Island) | Working from the app (demo) |
| Push updates when the app is closed | Waiting on Apple Developer enrollment |
| Upcoming games and schedule | Not built |
| Lacrosse source (StatBroadcast) | Not built; permission requested |

## Known limits

- The feed updates about once a minute, so alerts run a minute or more behind real play. The final can take two to three minutes.
- Quarter starts are announced once the clock is actually running, because the feed changes the quarter label during breaks.
- Check NCAA.com's terms of service before relying on this beyond personal use.

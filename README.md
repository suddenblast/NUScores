# NU Scores

A personal iPhone app for live Northwestern women's field hockey and lacrosse scores, in the style of Apple Sports. Scores show on the Home screen, the lock screen and the Dynamic Island through a Live Activity.

It's a one-person app, installed through Xcode. It isn't on the App Store.

## What it does

- **Home screen:** a sport selector (All / Field hockey / Lacrosse) over Live, Recent (newest first) and Upcoming (soonest first). Green and red dots mark wins and losses; "@" means away, "vs" home or neutral.
- **Game detail:** score, score by period, goal list with scorers and game times, plus location, date and weather (Apple WeatherKit).
- **Live Activity:** lock screen and Dynamic Island, with the score, quarter, clock and last goal.
- **Alerts:** goals, quarter starts and the final, delivered by push to the Live Activity.

## How it works

```
NCAA.com live feed  ->  Cloudflare Worker  ->  this app
```

- A separate Cloudflare Worker polls the game feed during games, works out what happened (goal, new quarter, final) and serves the current games as JSON.
- The Worker finds NU games on its own through a self-hosted ncaa-api, so nothing is edited per game. This app reads its JSON. The Worker is in a different project (`nu-score-recorder`) and isn't part of this repo.
- Regular-season lacrosse uses a different source (StatBroadcast), which isn't supported yet.

## Setup

You need a Mac with Xcode 27 and an iPhone running iOS 17.2 or later. Live Activity push also needs a paid Apple Developer account (the app uses the sandbox APNs environment for Xcode installs).

1. Open `NUScores.xcodeproj` in Xcode.
2. Copy `Config.swift.example` to `NUScores/Config.swift` and fill in your Worker URL and admin key. `Config.swift` is git-ignored, so the key stays off GitHub.
3. In Signing & Capabilities, choose your team and set a unique bundle ID for both the app and the widget. The widget's ID must start with the app's ID.
4. Run the **NUScores** scheme (not the widget scheme).

In debug builds, the **Demo** button on the home screen replays a recorded game through the Live Activity, which is useful for testing without a live game.

## Status

| Piece | State |
|---|---|
| Home and game detail screens | Working with real data; the newest changes (sport selector, away-first order, vs/@) still need an Xcode build check |
| Live Activity (lock screen and Dynamic Island) | Working, including push start/update/end from the Worker |
| Push updates when the app is closed | Working in sandbox; verified with the Worker's `/push-test` |
| Upcoming games and schedule | Built (found automatically by the Worker) |
| Past-season games | Worker backfill built, not yet run on real data |
| Regular-season lacrosse source (StatBroadcast) | Not built |

## Team logos

Teams show their logo instead of a color circle once it has been downloaded, and fall back to the circle until then. After
games load, the app asks the Worker's `/logo` route (which turns ncaa-api's SVGs into PNGs) for each opponent and saves the
files in an App Group folder, so the Live Activity can read them too (it can't download images itself). One-time setup in
Xcode: add the **App Groups** capability to both the NUScores and NUScoresWidget targets, with the group
`group.com.jonasblum.NUScores`. Without it everything still works, with circles.

## Known limits

- The feed updates about once a minute, so alerts run a minute or more behind real play. The final can take two to three minutes.
- Quarter starts are announced once the clock is actually running, because the feed changes the quarter label during breaks.
- Check NCAA.com's terms of service before relying on this beyond personal use.

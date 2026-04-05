# Based

A hand-drawn style MLB scorecard app for iOS built with UIKit.

## Features

- **Daily Schedule** — Browse MLB games by date with favorite teams pinned to the top
- **Live Scorecards** — Traditional baseball scorecard view with batter lineups, at-bat results, and inning-by-inning scoring
- **Game Detail** — Live game state including count, outs, baserunners, and current matchup
- **At-Bat Breakdown** — Pitch-by-pitch detail with pitch tracking visualizations
- **Player Profiles** — Tap any player to view bio and season/career batting stats
- **Customizable Tint** — Choose a pencil color theme from presets or a custom color picker

## Tech

- **UIKit** with programmatic layout (no storyboards)
- **MLB Stats API** (`statsapi.mlb.com`) for live data — no API key required
- Custom fonts: **Permanent Marker** (headers) and **Patrick Hand** (body)
- Hand-drawn UI elements rendered with `UIBezierPath`
- Swift concurrency (`async`/`await`) for networking

## Requirements

- iOS 26+
- Xcode 26+

## Building

Open `Based.xcodeproj` in Xcode and run on a simulator or device. No third-party dependencies.

## Author

Made with love in Philadelphia by Colin Weir.

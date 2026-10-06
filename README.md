# All-Sports Scoreboard

A premium, fully offline scoreboard for iPhone and iPad. Swift + SwiftUI, iOS 17+, no backend, no accounts, no network.

## Open & run

1. Open `AllSportsScoreboard.xcodeproj` in Xcode 16 or newer.
2. Select the **AllSportsScoreboard** target → *Signing & Capabilities* → choose your Team. Change the bundle identifier from `com.example.allsportsscoreboard` to your own.
3. Pick a simulator or device and press **Run**. Press **⌘U** to run the unit tests.

Source folders are synchronized with disk, so any file added under `AllSportsScoreboard/` is picked up automatically.

## Architecture

| Folder | What lives there |
| --- | --- |
| `App` | App entry, root navigation, active-game ownership |
| `Models` | `GameConfig`, `GameState`, drift-free `GameClock` |
| `SportRules` | `SportRules` protocol + one small type per sport, `SportCatalog` |
| `ViewModels` | `GameSession`: the scoreboard engine (scoring, undo, clock, periods) |
| `Sound` | On-device synthesized sounds and buzzers, `AVAudioEngine` playback |
| `Services` | Sound + haptic feedback mapping, screen-awake |
| `Persistence` | Settings (UserDefaults), active game save, history (SwiftData) |
| `Components` | Theme, buttons, shared controls |
| `Views` | Home, Setup, Scoreboard, History, Settings |

### Adding a sport

1. Add a case to `SportKind`.
2. Create a type conforming to `SportRules` (copy `HockeyRules` for a timed sport, `VolleyballRules` for a set-based one).
3. Return it from `SportCatalog.rules(for:)` and `defaultConfig(for:)`, and add it to `SportCatalog.all`.

### The clock

`GameClock` never decrements a counter. It stores banked time plus the instant it was started, and every reading is computed from those timestamps, so it cannot drift and it resumes correctly after backgrounding or relaunch. The ~20 Hz UI tick only refreshes the display and checks for warning/expiry.

## Status

Built: 14 sports (Basketball, Football, Soccer, Hockey, Baseball, Volleyball, Tennis, Table Tennis, Badminton, Pickleball, Boxing/MMA, Wrestling, Bucket Golf, Custom), drift-free timer, synthesized sounds with 5 buzzer styles, haptics, undo, swap sides, history, settings, full screen mode, keep-awake, privacy manifest, unit tests (including a QA regression suite).

Scoring models (`ScoringModel`): `points` (running totals over timed periods), `rally` (points → sets), `tennis`, `baseball`, `combat` (timed rounds, rest timer, scorecards). Match logic lives in `GameSession+Match.swift`. Bucket Golf (BucketGolf stroke play: par 3 every hole, bucket-in −1 bonus, hazard penalty, 1–8 players) runs on its own engine, `PlayerGameSession`, with `PlayerBoardView`.

Next: on-device polish pass; App Store assets.

# WPBL Stats API (unofficial, reverse-engineered)

Base host: `https://stats.womensprobaseballleague.com`

Backing data provider is **Presto Sports** (`provider: "presto"` in every payload; raw
Presto objects are embedded verbatim under `presto_data`). The site is a Go server
(`via: Caddy`) that serves both server-rendered HTML "explorer" pages and a small JSON
API under `/v1/`. There is no authentication, no API key, and no CORS header
(`Access-Control-Allow-Origin` is absent), so browser-side fetches from other origins
will be blocked — server-side/CLI requests work fine.

Every JSON response includes:

```
x-data-delay-seconds: 5
```

...suggesting live/in-progress game data is delayed ~5s from the source feed.

2026 season constants observed so far:

| Name | Value |
|---|---|
| `season_id` | `c9sgab9f9yx00z75` |
| Season name | "Womens Pro Baseball League 2026" |
| Season window | 2026-03-01 – 2026-11-15 (per `presto_data.teams.*.season`) |
| Teams | 4 (Boston Hunters, Los Angeles Queens, New York Heights, San Francisco Firebells) |
| Games | 32 (full regular-season schedule, all `game_type: "regular"`) |

Team reference table (`team_id` is the stable ID used everywhere; `code` only appears
inside boxscore payloads):

| team_id | code | name |
|---|---|---|
| `9f08or2mffx81409` | WPBL001 | Boston Hunters |
| `v4gisr4rbgmn67b0` | WPBL002 | Los Angeles Queens |
| `fttth861nft1j2s7` | WPBL003 | New York Heights |
| `vhubhz8li07tmgq8` | WPBL004 | San Francisco Firebells |

`game_id`s are opaque 16-char lowercase base32-ish strings (e.g. `qk2oug9ikob2a1hl`),
not sequential integers — they must be discovered via `/v1/games` or the explorer
pages. Small numeric IDs like `/v1/games/1/boxscore` are **not valid** and 404.

---

## HTML "explorer" pages (server-rendered, no client-side API calls)

These pages are plain server-rendered HTML — there is no `__NEXT_DATA__`/hydration
blob and no separate XHR call the page makes after load; all data is baked into the
HTML response itself. Scraping the `<table class="data-table fan-table">` is the only
way to get this data outside of `/v1/`.

### `GET /explorer/games`
Full 32-game schedule table. Columns: Date, First pitch (UTC), Matchup (links to
`/games/<game_id>`), Status badge (`final`, `final - weather delay`, `Upcoming`),
Score, "Game center →" link. This is a convenience view over `/v1/games` — every field
shown is also in the JSON API, so prefer `/v1/games` for programmatic use.

### `GET /explorer/teams`
Standings table: Team (links to roster), W, L, PCT, Streak, Next game (opponent +
date/time), Roster (player count + link to `/explorer/players?team_id=...`).

Note: as of this probe (2026-08-03, only 2 of 32 games completed) every team still
shows `0-0` / `.000` / streak `—` — standings do not appear to update from completed
game results yet, or only recompute on a delayed job. Don't treat `wins`/`losses` on
`/v1/teams` as reliable during early season.

### `GET /explorer/players`
League-wide player directory table. Columns: `#` (uniform), Player, Team (link, but
**not** to a specific player — it links back to `/explorer/teams`), Position, Height,
Weight, Hometown, Year. Height/Weight/Hometown/Year are `—` (empty) for every player
observed — bio data isn't populated yet. There is no per-player detail page/ID exposed
in this HTML (no `player_id` in the markup); player identity elsewhere in the API
comes only from boxscore JSON (`players[].id`).

### `GET /explorer/players?team_id=<TEAM_ID>`
Same table, filtered server-side to one team's roster. Confirmed the filter is real
(Boston Hunters: 16 rows both here and via team roster count on `/explorer/teams`).
Adds a banner: `Showing players on <strong>{team name}</strong>`.

### `GET /games/<GAME_ID>`
"Game center" HTML page — human-readable render of the same data as
`/v1/games/<GAME_ID>/boxscore` (linescore, box, play-by-play). No additional data
beyond the JSON boxscore endpoint; use the JSON endpoint instead for programmatic
access.

---

## JSON API (`/v1/`)

Unversioned-in-practice but path-prefixed `v1`. Discovered endpoints:

| Endpoint | Method | Notes |
|---|---|---|
| `GET /v1/games` | list | supports query params, see below |
| `GET /v1/games/{game_id}` | single | game metadata only, no play-by-play |
| `GET /v1/games/{game_id}/boxscore` | single | full box score + play-by-play |
| `GET /v1/teams` | list | all 4 teams |
| `GET /v1/teams/{team_id}` | single | (shape not fully probed, 200 JSON) |
| `GET /v1/teams/{team_id}/players` | list | **roster JSON, does exist** — see below |
| `GET /v1/players/{player_id}` | single | **player JSON, does exist** — see below |
| `GET /v1/players` (bare, no id) | — | **404/307-loop** — only works with a specific `{player_id}` or via the team-scoped route above |
| `GET /v1/standings` | — | **404** |
| `GET /v1/seasons` | — | **404** |
| `GET /v1/games/{game_id}/players` \| `/lineups` \| `/lineup` | — | **404** — lineups only available inside `/v1/games/{id}/boxscore` (`starters[]`) |
| `GET /v1/teams/{team_id}/roster` | — | **404** — use `/players` (see above), not `/roster` |
| `GET /v1/{people,athletes,search,leaders,stats}...` | — | **404** — none of these exist |

Errors are plain text (not JSON) with matching HTTP status:
- Unknown game id → `404` body `game not found`
- Unknown team id → `404` body `team not found`
- Unknown game id on boxscore → `404` body `box score not found`

### `GET /v1/games`

Query params (all optional, all confirmed by testing):

| Param | Effect | Notes |
|---|---|---|
| `status` | exact-match filter on `status` field | Values seen: `Not Started`, `Final`, `Final - Weather Delay`. Must match exactly (`status=Upcoming` returns 0 — that's just the HTML badge label, not the real value). URL-encode the space. |
| `limit` | max rows returned | `limit=0` is treated as "no limit" (returns all). |
| `offset` | pagination offset | Confirmed: `offset=2&limit=2` returns items 3–4 of the default-ordered list. |

Params that **look** plausible but did **not** filter anything (server ignores them,
returns the full unfiltered list): `team_id`, `home_team_id`, `away_team_id`,
`season_id`, `game_type`. If you need games for one team, fetch the full `/v1/games`
list and filter client-side on `home_team_id`/`away_team_id`.

Default ordering: ascending by `scheduled_start`.

Response shape:

```jsonc
{
  "count": 32,
  "games": [
    {
      "game_id": "8alsgvzc90ypwphl",
      "provider": "presto",
      "season_id": "c9sgab9f9yx00z75",
      "home_team_id": "fttth861nft1j2s7",
      "away_team_id": "v4gisr4rbgmn67b0",
      "home_team_name": "New York Heights",
      "away_team_name": "Los Angeles Queens",
      "game_type": "regular",
      "venue": "",
      "counts_in_standings": true,
      "status": "Final - Weather Delay",
      "scheduled_start": "2026-08-01T21:00:00Z",   // ISO 8601 UTC
      "completed_at": "2026-08-02T12:29:47Z",
      "updated_at": "2026-08-02T12:29:47Z",
      "presto_data": { /* raw passthrough from Presto Sports, see below */ },
      "state": {
        "game_id": "8alsgvzc90ypwphl",
        "status": "Final - Weather Delay",
        "home_score": 8,
        "away_score": 10,
        "inning": 0,
        "half": "",
        "outs": 0,
        "batter_id": "",
        "updated_at": "2026-08-02T12:29:47Z"
      }
    }
    // ...
  ]
}
```

`presto_data` (raw Presto object, useful fields):
- `score.home` / `score.away` (strings)
- `status`, `statusCode`, `eventTypeCode`, `eventTypeDescription`
- `teams.homeTeam` / `teams.awayTeam`: `teamId`, `teamName`, `logo` (a
  `static.prestosports.com` logo URL keyed by `rpi=WPBLxxx&sport=bsb`), nested
  `season` object (season name/dates/org)
- `venue`, `city`, `address`, `zipCode`, `stateCountry`, `timeZone`/`timeZoneDisplay`
  — all empty strings for every game seen so far (venue data not populated)
- `eventType.isWeatherDelay` etc. — booleans for special-status flags
- `startDateTime` / `lastUpdatedDateTime` — same timestamps as top-level but without
  the trailing `Z` (naive, presumably already UTC)

### `GET /v1/games/{game_id}`

Same object as one entry from `/v1/games`'s `games[]` array (no `boxscore`/`plays`
wrapper — just game metadata + current `state`). Use this when you only need
score/status for one game without pulling the full play-by-play.

### `GET /v1/games/{game_id}/boxscore`

The rich endpoint. Top-level wrapper:

```jsonc
{ "boxscore": { ... } }
```

`boxscore` fields:

| Field | Type | Notes |
|---|---|---|
| `game_id` | string | |
| `provider` | string | always `"presto"` |
| `game_status` | string | e.g. `"Not Started"`, `"Final"`, `"Final - Weather Delay"` |
| `source_updated_at` / `fetched_at` | ISO timestamp | |
| `status` | object | **live/current game state** (see below) |
| `teams` | array[2] | `side: "away"` then `side: "home"` |
| `plays` | array \| null | play-by-play; `null` until the game has started |

`status` object (live state — mostly zeroed/empty for not-yet-started or completed
games; would be populated mid-game):
```jsonc
{
  "complete": false,
  "inning": 0, "half": "",              // "top" | "bottom" while live
  "batting_team_id": "",
  "outs": 0, "balls": 0, "strikes": 0,
  "batter_name": "", "pitcher_name": "",
  "first_base": "", "second_base": "", "third_base": "",  // runner names when occupied
  "bases_occupied": null,               // e.g. [1,2] meaning 1st+2nd occupied
  "bases_loaded": false,
  "away_runs": 0, "home_runs": 0
}
```

Each entry in `teams[]` (pre-game, fields mostly blank; post-game, fully populated):

```jsonc
{
  "side": "away",                 // "away" | "home"
  "id": "vhubhz8li07tmgq8",       // == team_id from /v1/teams, blank pre-game
  "code": "WPBL004",              // Presto team code, blank pre-game
  "name": "San Francisco Firebells",
  "record": "1-0",                // blank pre-game
  "line": [ { "inning": 1, "runs": 1 }, ... ],   // per-inning line score, null pre-game
  "totals": {
    "runs": 11, "hits": 15, "errors": 3, "left_on_base": 11,
    "batting":  { "ab","bb","cs","double","fly","gdp","ground","h","hbp","hitdp",
                  "hittp","hr","ibb","kl","picked","r","rbi","sb","sf","sh","so",
                  "triple": "..." /* all strings, team totals */ },
    "pitching": { "ab","bb","bf","bk","double","er","fly","gdp","ground","h","hbp",
                  "hr","ibb","ip","kl","picked","pitches","r","sfa","sha","so",
                  "strikes","triple","wp": "..." },
    "fielding": { "a","ci","e","pb","po","sba": "..." }
  },
  "players": [ /* per-player stat lines, null pre-game — see below */ ],
  "starters": [ /* starting lineup, null pre-game — see below */ ]
}
```

`starters[]` (batting order for the game):
```jsonc
{ "name": "Amanda Gianelloni", "uniform": "5", "position": "2b", "spot": "1" }
```
`spot` is batting-order position (1-9); pitchers appear with `spot` matching where
they bat if it's their turn (DH-less lineup — pitchers hit).

`players[]` (one entry per player who appeared, box-score stat line):
```jsonc
{
  "id": "v3d0akr1chosb9hc",        // stable player id (only place this ID appears)
  "name": "Amanda Gianelloni",
  "short_name": "Amanda Gianelloni",
  "uniform": "5",
  "position": "2b",                // combo like "p/cf" if player changed position
  "spot": "1",
  "bats": "R", "throws": "R",      // "L" | "R" | "S"(switch)
  "hitting":  { "ab","bb","cs","double","fly","ground","h","hbp","hitdp","hittp",
                "hr","ibb","kl","obp","ops","picked","r","rbi","sb","sf","sh","slg",
                "so","triple": "..." },   // only keys with nonzero/relevant values present
  "pitching": { "ab","appear","bb","bf","bk","double","er","fly","gdp","gs","ground",
                "h","hbp","hr","ibb","ip","kl","loss","pitches","r","save","sfa","sha",
                "so","strikes","triple","whip","win","wp": "..." },  // present only for pitchers
  "fielding": { "a","ci","e","pb","po","sba": "..." }
}
```
Notes:
- Stat sub-objects use **sparse keys** — a field is omitted rather than zeroed if not
  applicable (e.g. non-pitchers have no `pitching` key at all; batters with no extra
  base hits omit `double`/`triple`/`hr`).
- `win`/`loss`/`save` appear as decision-record strings (e.g. `"win": "1-0"`) on the
  pitcher who earned them.
- Dual-position players (e.g. a pitcher who also plays LF) get one `players[]` entry
  with combined stat lines and `position` like `"lf/p"`.

`plays[]` (full play-by-play, chronological, only present once game has started):
```jsonc
{
  "inning": 1, "half": "top",             // "top" | "bottom"
  "team_id": "vhubhz8li07tmgq8",          // batting team
  "sequence": 1,                          // play index within game
  "batter_name": "Amanda Gianelloni",
  "pitcher_name": "Raine Padgham",
  "outs": 0,                              // outs *before* this play resolves? (observed 0 on 1st play, 1 after 2nd play - i.e. outs entering the play)
  "first_base": "", "second_base": "", "third_base": "",  // runners before the play
  "bases_occupied": [], "bases_loaded": false,
  "narrative": "Amanda Gianelloni struck out swinging (1-2 KFBS).",
  "event_type": "strikeout",              // e.g. "strikeout","groundout","single","double","home_run","walk", etc.
  "is_hit": false,
  "is_scoring_play": false,
  "runs_scored": 0,
  "pitch_sequence": "KFBS",               // Retrosheet-style pitch code string
  "pitch_events": [
    { "sequence": 1, "code": "K", "type": "unknown", "description": "Unknown pitch code" },
    { "sequence": 2, "code": "F", "type": "foul", "description": "Foul" },
    { "sequence": 3, "code": "B", "type": "ball", "description": "Ball" },
    { "sequence": 4, "code": "S", "type": "swinging_strike", "description": "Swinging strike" }
  ],
  "fouls": 1, "balls": 1, "strikes": 3
}
```
`pitch_events[].type` values seen: `unknown`, `foul`, `ball`, `swinging_strike`,
`pitchout`. Expect additional standard types (`called_strike`, `in_play`, etc.) once
more games with fuller pitch data are examined — the sample here (`qk2oug9ikob2a1hl`,
`8alsgvzc90ypwphl`) may not cover every code.

### `GET /v1/teams`

```jsonc
{
  "count": 4,
  "teams": [
    {
      "team_id": "9f08or2mffx81409",
      "team_name": "Boston Hunters",
      "season_id": "c9sgab9f9yx00z75",
      "logo_url": "", "sport_id": "", "conference": "", "division": "", "region": "",
      "color": "", "rpi_id": "", "rpi_value": "",
      "wins": 0, "losses": 0, "ties": 0,
      "record": "", "conference_record": "", "streak": "",
      "presto_data": {
        "teamId": "9f08or2mffx81409", "sportId": "", "seasonId": "c9sgab9f9yx00z75",
        "teamName": "Boston Hunters"
      },
      "updated_at": "2026-08-03T14:33:21.056377Z"
    }
    // ...
  ]
}
```
As with the HTML standings page, `wins`/`losses`/`record` are `0`/empty for every team
even after 2 completed games — don't rely on this for live standings yet.

### `GET /v1/teams/{team_id}`
Returned `200 application/json` (not deeply probed) — presumably a single object
matching one entry of `/v1/teams`'s `teams[]` array, same pattern as
`/v1/games/{id}` vs `/v1/games`.

### `GET /v1/teams/{team_id}/players`

**This is the real roster JSON endpoint** (there is no bare `/v1/players` list —
rosters are only reachable per-team). Confirmed counts match the `/explorer/players`
HTML totals exactly: Boston Hunters 16, Los Angeles Queens 18, New York Heights 16,
San Francisco Firebells 16.

Supports `limit`/`offset` (same behavior as `/v1/games`). An unknown-but-well-formed
`team_id` returns `200 {"count":0,"players":[]}` rather than 404 (contrast with
`/v1/teams/{team_id}` itself, which 404s `team not found` for a bad id).

```jsonc
{
  "count": 16,
  "players": [
    {
      "player_id": "6yezcikkcsqlcbk4",
      "team_id": "9f08or2mffx81409",
      "career_id": "",
      "first_name": "Kate",
      "last_name": "Blunt",
      "position": "SS",
      "uniform": "4",
      "height": "", "weight": "", "hometown": "", "summary": "",
      "headshot_url": "", "dob": "", "year": "",
      "is_starter": false,
      "is_active": true,
      "player_status": "ACTIVE",
      "has_stats": false,
      "stats_url": "",
      "presto_data": {
        "data": { "bats": "R", "throws": "R", "hometown": "Ladera Ranch, Calif.",
                   "born": "", "height": "", "weight": "" },
        "teamId": "9f08or2mffx81409", "playerId": "6yezcikkcsqlcbk4",
        "firstName": "Kate", "lastName": "Blunt", "position": "SS", "uniform": "4",
        "active": true, "starter": false, "playerStatus": "ACTIVE",
        "sportCode": 1, "dateCreated": "2026-07-24T23:08:47",
        "apiAccess": ["READ"]
        // + several always-null fields: url, height, weight, summary, careerId,
        //   headshot, hometown, statsURL, attributes, year, dob
      },
      "updated_at": "2026-08-03T14:30:19.691306Z"
    }
    // ...
  ]
}
```

Notable: the top-level `hometown`/`bats`/`throws`/`born` fields are blank, but
**`presto_data.data.hometown`, `.bats`, `.throws` are populated** even though the
top-level normalized fields aren't — worth reading through to `presto_data.data` for
bio info the top-level fields don't surface. `height`/`weight`/`born`/`dob`/`year` are
empty everywhere (not populated by the league yet), matching the `—` placeholders seen
on the `/explorer/players` HTML table.

### `GET /v1/players/{player_id}`

Single player, same shape as one entry of the `/v1/teams/{team_id}/players` list above
(not a superset — no extra fields beyond what's in the roster list). `player_id` is the
same ID that appears as `players[].id` inside `/v1/games/{id}/boxscore`, so you can
pivot from a boxscore stat line to full player bio via this endpoint. Unknown id →
`404` body `player not found`.

---

## Practical recipes

- **Full schedule with scores/status**: `GET /v1/games` (or filter by `status`).
- **One game's current score/status** (polling-friendly, small payload): `GET /v1/games/{game_id}`.
- **Full box score + play-by-play for a completed/live game**: `GET /v1/games/{game_id}/boxscore`.
- **Roster for a team**: `GET /v1/teams/{team_id}/players` (JSON — no need to scrape HTML).
- **Single player bio**: `GET /v1/players/{player_id}` (id sourced from a roster list or from `players[].id` in a boxscore).
- **Team list / IDs**: `GET /v1/teams`.
- **Games for one team**: fetch all of `/v1/games` and filter client-side on `home_team_id`/`away_team_id` (server-side `team_id` param is accepted but ignored).

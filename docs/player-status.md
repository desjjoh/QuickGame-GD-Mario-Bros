# Player status and UI values

GameHandler owns one runtime PlayerStatus Resource (scripts/session/player_status.gd). Player scenes and UI read this record; replacing a player, moving between areas or restarting a level does not create another status record. These values are in memory, with no disk persistence.

## Values and defaults

| Owner | Value | New-game default | Current range |
| --- | --- | --- | --- |
| PlayerStatus | score | 0 | 0..999999 |
| PlayerStatus | coins | 0 | 0..99 |
| PlayerStatus | lives (reserves) | 2, displayed as 3 | -1..98 |
| PlayerStatus | powerup_form | SMALL | SMALL, SUPER, FIRE |
| GameHandler | top_score | 0 at app startup; retained on new game | 0..999999 |
| GameHandler | stage_label | Loaded BaseLevel.stage_label, default 1-1 | String |
| GameHandler | time_remaining | Loaded BaseLevel.starting_time, default 400 | 0..999 |

Numeric values clamp to their current display ranges; invalid form values are ignored. These are initial storage constraints, not a recreation of NES numeric overflow. No 100-coin rollover, extra-life award or score reward exists yet. Negative reserves now trigger [game over](game-over.md). Extend add_coins atomically with the agreed rollover/reward policy before connecting collectibles; it currently clamps at 99. Time is a bound value, not a running countdown. Form is durable session data, separate from movement states, death presentation and future temporary invincibility.

## Updating values

Gameplay uses GameHandler.set_score/add_score, set_coins/add_coins, set_lives, set_player_form and set_top_score. For example, GameHandler.add_score(100) immediately updates the HUD, and GameHandler.set_top_score(12345) updates the title's TOP- 012345 display. This does not automatically promote score to top score.

PlayerStatus validates changes and emits changed_value; GameHandler forwards it through the existing session_value_changed signal. Core fields are also routed by legacy set_session_value/get_session_value calls, so they cannot diverge into a second dictionary copy. Assigning an unchanged typed value emits no event. Other session keys, including area/transport metadata, retain their dictionary behavior.

## UI bindings

HUD reads all initial values on readiness, then listens for changes to score, coins, stage label and time. Existing scene positions and leading score spacing remain; score has six digits, coins two and time three. The title uses the existing white bitmap font on the 8x8 grid for TOP- plus six score digits at (96,184). The loading intro displays reserve lives + 1 and the current stage label, including changes while displayed. Its × symbol stays fixed at X=120; the lives number is right-aligned in a 16-pixel field at X=136..152, so a single digit occupies X=144 and two digits occupy X=136/144. Listeners disconnect on removal. No polling callbacks are added to these value displays; existing title input polling and shared cosmetic animation remain independent.

Stage identity belongs to BaseLevel, not its area theme. GameHandler initializes stage label and time when loading a level. Pipe travel within that level retains them, including entry to Underground. Each level can supply its Stage Display / Stage Label and Starting Time in the Inspector.

## Reset and preservation

- New game: clear_session resets PlayerStatus to Small / 0 score / 0 coins / 2 reserves (3 displayed lives), clears routing and area progress, and resets stage display defaults before loading the stage. Top score survives.
- Area travel: keeps player status, top score, stage label and remaining time.
- Accepted death: BaseLevel.on_death reduces lives once through GameHandler.set_lives; duplicate/invalid requests do not count. Restart preserves that reduced value, other player status and top score, and reloads the stage's starting time/label. Zero reserves still give one attempt; -1 routes to game over after the death jingle. The existing reset_progress_on_death flag controls world progress only.
- Game detach: top score remains available in the running application. Closing the process loses it; disk saving is deferred.

Only Small Mario exists. Recording SUPER/FIRE does not transform Mario or select unavailable scenes; character/form scene resolution and the eventual power-loss-on-death rule remain separate future work. No temporary effect flags or character selection are introduced here.

## Verification

player_status_test covers defaults, bounds, change-only signals, legacy-key routing, initial/live HUD/title/intro values, new-game reset with top-score retention, area travel and death restart continuity. It also checks that coins/score do not grant lives or promote top score automatically. Rendered runs capture the title layout for inspection. Existing HUD, title, death and transition regressions cover integration with their established lifecycles.

Returning to the title uses the same clear_session reset as a new game, after shutting down the outgoing level. Player status, custom session values, pending start, stage index and world progress return to defaults; top score remains in memory until a hard restart. Stage-to-stage advancement does not call this reset.

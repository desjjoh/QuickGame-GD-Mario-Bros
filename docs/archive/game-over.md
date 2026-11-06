# Game over and level progress

GameHandler owns the end-of-run decision. BaseLevel accepts death once, reduces the reserve counter, and completes its existing death presentation/jingle. Its completion then calls GameHandler.restart_after_death: reserves >= 0 use the normal level intro/respawn; reserves < 0 enter GameFlow.GAME_OVER and the named game_over transition. No level handler/autoload or new Project Settings are introduced.

## Reserve lives and UI

PlayerStatus.lives is the NES-style reserve counter, initialized/reset to 2. The intro displays get_display_lives(), which adds one. The sequence is stored 2/displayed 3, stored 1/displayed 2, stored 0/displayed 1, then stored -1/game over. The counter clamps to -1..98 so normal display values fit the existing two-digit field through 99. The game-over card has no lives field; -1 is never shown as a negative life count. Score, coins and top score retain their existing ownership and validation.

## Presentation and audio

assets/transitions/game_over.tres uses the existing coordinator: 12 hidden frames, a 378-frame game_over presentation with HUD visible, then 12 hidden frames. The centered white bitmap GAME OVER label is authored on the 8x8 UI grid in scenes/ui/transitions/game_over.tscn. Gameplay is hidden; no Cover node or clear-color/background override is added. Its sound is assets/soundtrack/smb_gameover.wav (about 3.774 seconds), played once through a card-owned non-positional AudioStreamPlayer. The shared mix assigns -5 dB trim plus -3 dB master, matching the death-jingle gain policy; subjective listening may still require adjustment. Source audio/import settings are unchanged.

The [reference disassembly mirror](https://gist.github.com/emilyst/976f75ca3a2c51daa831) shows a negative-counter branch in PlayerLoseLife, a game-over music queue in SetupGameOver, and ScreenTimer=0x12 with a 21-frame interval divider. The 378-frame hold approximates that NTSC timing rather than reproducing timer phase and screen-setup overhead exactly. The original also allows Start to leave early; this first implementation returns automatically after the hold/audio and does not implement skipping, continues, demo playback or a second player.

TransitionStage.wait_for_presentation is opt-in and defaults false for existing cards. After minimum_frames, an opted-in Control must return true from is_presentation_complete(). completion_timeout_frames bounds an unfinished stage (default 600 frames, counted from stage start, at least minimum_frames). Missing contracts/timeouts finish the transaction as unsuccessful; game-over recovery still returns to a usable title if the Game owns that sequence. GameOver's audio completion is independently bounded by its sound length plus one second or fallback_timeout (default ten seconds), whichever is longer. Missing sound completes immediately but the minimum card hold remains. Cancellation/removal stops card audio.

## Cleanup and title return

At the covered operation, the old level is shut down first, allowing its final snapshot, then removed and queued for deletion. Its one-level progress store remains available throughout the card. No fresh player or negative-lives intro is created. Score/coin totals remain visible during game over. On completion, level retirement is checked again, input confirmation is consumed, and GameHandler.show_title performs the common title-entry cleanup: finish any outgoing level shutdown, call clear_session to reset the complete run except top score, then create the existing title/TestLevel background. This also clears progress when returning from playable TestLevel to the same scene used as the title background. Top score survives; automatic top-score promotion remains deferred. Title entry already resets score/coins, Small form and reserves=2; starting a new game also performs this reset defensively.

Holding Start through the card cannot immediately start another game: ControllerHandler requires release before its next Start edge, including release tracking while gameplay intent is disabled. Game replacement/detach and old completion are ownership-checked; a cancelled old card cannot overwrite a newer external level. A replacement initialized during a cancelled transition has its obsolete transition flag cleared without overriding a newer active transaction. With transitions explicitly disabled (test/direct-flow fallback), final death cleans up and returns to the title immediately without presentation/audio.

## One logical level in memory

GameHandler holds _progress_level_key plus one _area_progress dictionary indexed by area ID. Existing store_area_progress/get_area_progress/forget_area_progress callers retain their level-key arguments, but snapshots for multiple level keys are no longer retained. Data is copied at the boundary. BaseLevel passes itself when writing so a previous instance cannot write into a later visit of the same level.

- Area changes retain the store, including used blocks and future collected-world-coin records.
- Recreating the same named level after death retains it, unless the explicit reset_progress_on_death override is enabled.
- Loading a different logical level clears it after old shutdown and before new readiness.
- Returning from another level starts a fresh visit, even if the scene was played previously.
- Entering the title via show_title clears it after outgoing shutdown, regardless of why the menu is shown; game-over presentation itself preserves it.
- Detaching Game does not enter the menu and leaves the final snapshot available. External replacement follows normal level-identity rules; a stale game-over callback cannot clear the replacement store.
- clear_session clears the store and player defaults, retaining top score.

Logical identity uses the registered level scene path; anonymous/standalone fixtures retain their instance-scoped behavior. Runtime unload/reload of areas does not select a new level. Shared assets and packed templates are still cached; this is progress ownership, not full texture eviction or disk saves. Collectible coin entities are not implemented yet; the generic store can already hold their future collection flags.

## Verification

game_over_test covers three attempts, the zero/negative boundary, the reference-sized hold, actual sound completion, missing-audio and stalled-presentation fallback, HUD visibility, progress cleanup, fresh Start, new-game defaults, external replacement and detach. level_progress_test covers copied records, area/same-level retention, different-level reset and stale-source rejection. Existing death/status/transition/streaming regressions retain their lifecycle coverage. See verification.md for the executed results and remaining limits.

# Player death lifecycle

BaseLevel coordinates death for all stages. The implemented trigger is falling fully below the active camera viewport. Accepted death deducts one shared life. Negative reserves now trigger [game over](game-over.md). Mario now has optional visible death presentation; no gameplay hazard/enemy caller is added yet. Checkpoints and collectible coins remain unimplemented.

## Detection and ownership

After player movement and camera/bounds processing, BaseLevel compares BasePlayer.death_envelope_top() with the active viewport bottom plus Fall Death Margin (default 34 pixels). The envelope uses the authored rectangular collision shape, independent of animation frames; small Mario's top is 14 pixels above his feet. Partially visible players do not die. With a viewport bottom at Y=240, small Mario triggers after his feet pass Y=288, 32 pixels deeper than the former Y=256 cutoff. This approximates the reference's vertical-page threshold after translating its 32px player drawing envelope to our feet-based origin. Cleanup still happens immediately at that cutoff rather than simulating the remaining invisible fall. Camera zoom and the occupied area's world position are included. Fall Death Enabled defaults to true. There is no bottom clamp.

BaseLevel.on_death(player, present=false) accepts the current player once and rejects duplicate death, shutdown and active transport. After setting death_in_progress, it calls GameHandler.set_lives(player_status.lives - 1); the shared setter permits -1 reserves and notifies UI. Invalid/repeated requests do not deduct. It freezes camera following/bounds handling and refuses new transport until restart. The death_started signal is notification, not ownership of the sequence. BaseLevel's physics callback continues only to coordinate death timing.

All other BaseEntity descendants are reversibly gameplay-suspended. Their FSM frame, physics, input, animation-finished callbacks and ordinary transitions are gated; entity/component physics callbacks are disabled with their previous enable states retained. Independent AnimationPlayer playback and the global cosmetic clock remain active. Clock-sampled question blocks and HUD coins keep their shared phase even though their native playback is paused. BaseBlock rejects new hits while suspended. This is gameplay suspension, not SceneTree pause or terminal shutdown.

Custom gameplay frame callbacks, external signals and animation method/property tracks must respect suspension: cosmetic animation must not move bodies, spawn objects or mutate gameplay while frozen. New autonomous physics types need explicit qualification. This does not suspend the entire physics server or implement a general pause menu. Off-camera enemy activation/disposal remains separate planned work.

## Player cleanup and optional presentation

BasePlayer.begin_death exits the current state without exit presentation, disconnects controller event delivery, cancels jump activity, stops current SFX, zeros velocity and disables collision layer/mask. is_dead prevents repetition.

For pit deaths, presentation is false: finish_death notifies the level immediately. The level performs terminal player shutdown, hides/queues the entity for removal, clears current_player and its own player reference. The level owns the remaining audio/timer, so removing Mario does not interrupt death completion.

Visible death uses on_death(player, true). Small Mario assigns StateMachine/Dead (MarioDeadState) through BasePlayer.death_state, displaying assets/player/mario (small)/mario-dead.png as a static pose. Controls, event input and frame updates are disabled for the state; its physics ticks remain active. Mario retains facing and his existing one-pixel-lower sprite baseline. No gameplay trigger or debug input binding calls it yet.

Dead holds position for 16 physics ticks, launches at -240 px/s, applies death-only gravity of 562.5 px/s squared and caps downward speed at 240 px/s. These are nominal 60Hz conversions of the reference's $fc launch and $28 gravity, with the initial TimerControl pause represented explicitly. Position integrates before gravity. The state bypasses normal JumpAction, horizontal movement, corner recovery and ceiling bonks; collision layer/mask are already zero from begin_death. It neither plays the jump SFX nor owns the death jingle.

While descending, Dead calls finish_death only after the actual sprite top is below the active camera's viewport bottom, including zoom and area world position. This prevents its final visible row disappearing early. BaseLevel then performs the existing terminal entity cleanup and independently waits for audio/fallback timing before respawn or game over. Missing presentation completes immediately; the existing watchdog still bounds a missing camera or unfinished presentation. The generic presentation contract remains tested with a separate fixture.

## Sound and completion

BaseLevel's Death Sound uses assets/soundtrack/smb_mariodie.wav through an independent, level-owned non-positional AudioStreamPlayer. A private runtime copy disables looping without changing the source/import settings. This is a death event sound; area soundtrack playback remains removed.

With a valid sound, completion waits for both presentation and the sound's finished notification. Missing audio uses Death Fallback Delay (default 1 second). Audio failure/no finish notification is bounded by the greater of the fallback delay and stream length plus one second. Death Presentation Timeout (default 10 seconds), extended for longer audio, bounds a stuck presentation. Shutdown stops/releases death audio. Deferred restart rechecks ownership so an old level cannot replace a new level after cancellation/replacement.

## Restart and progress

GameHandler.reset_progress_on_death is the global world-progress configuration, default false. It is a script variable on the existing autoload, not a new Project Setting. Set true to restore authored world state after death; false preserves progress. This replaces the earlier planned per-level flag.

GameHandler retains the loaded PackedScene and owns restart. It first shuts down the old level, allowing the final active area snapshot to save. If reset is enabled, it then clears only that level's stored progress before loading the same scene again. This ordering prevents shutdown from rewriting cleared data. Named levels use the existing scene-keyed progress contract; anonymous runtime fixtures retain their existing nonpersistent semantics.

Reload restores the original MainArea camera and the actual Players/PlayerSpawn marker. Inactive-area snapshots survive when preserving progress. Used/removed blocks and runtime tile edits follow the flag; future collected-world-coin records must join that contract. Coin counters, score, lives, power-ups and unrelated level data are not cleared by this policy. Normal pipe travel continues preserving progress independently.

## Reference and verification

The reference's PlayerHole/HoleDie separates off-screen fall handling from visible PlayerDeath presentation and uses death-event music before PlayerLoseLife. TimerControl also gates enemy movement and some enemy animation. Our independent audio completion, optional presentation and continuing cosmetic animation are deliberate adaptations, not cycle-accurate parity. See the [disassembly](https://gist.github.com/1wErt3r/4048722).

The death regression covers threshold visibility, duplicate/transport rejection, player state/input cleanup and freeing, reversible suspension with continuing animation, the optional presentation contract, real one-shot sound decoding/playback, restart at PlayerSpawn, both global progress policies across active/inactive areas, exactly-once life loss, zero-life restart, live intro updates and stale/reentrant ownership. See [verification](verification.md) for executed checks and limitations.

## Presented restart

After the existing death wait/jingle, GameHandler restarts through the global level transition: quick black, load, splash with HUD, quick black, gameplay. The life already deducted at death acceptance survives this restart; loading the level does not deduct again. Progress-reset configuration remains independent. Standalone restart limitations still apply. See [transitions](transitions.md).

## Life deduction boundary

Deduct at the accepted BaseLevel.on_death call, before presentation/audio, rather than in BasePlayer.begin_death or GameHandler.restart_after_death. This applies whether presentation is requested or the player is offscreen. Set the duplicate guard before publishing the lives signal so reentrant requests cannot charge twice. If a status listener synchronously replaces/shuts down the old level, on_death returns after the charge without starting stale cleanup/audio.

The intro's existing GameHandler binding displays the reduced reserve count plus one automatically. A death from 1 to 0 reserves respawns with one displayed attempt; 0 to -1 produces game over after death completion. Restart alone preserves the current count. New game initializes two reserves, displayed as three lives. Score/coin totals, top score and the world-progress reset policy are unchanged. This counter update happens at acceptance; it is not a claim of exact original-game jingle/decrement timing.

GameHandler now retains only the current logical level's area snapshots. Leaving for another level or returning to title clears world progress; ordinary same-level respawn still honors reset_progress_on_death. The common show_title callback owns clearing after final shutdown, independent of that override; the game-over card itself retains the cache until title entry. See [game over](game-over.md).


## Preview and verification

Open tests/dead_state_test.tscn and run it with F6 to watch the automated visible-death cases in the main and lower areas. This regression scene calls the lifecycle directly; normal F5 gameplay gains no new death trigger. It checks the exact hold, first -4px launch step at 60Hz, gravity/cap, facing/texture, blocked input, camera freeze, world suspension, full offscreen removal, one life charge, respawn and final-attempt title reset. The non-presented pit path remains immediate. This is a continuous-motion adaptation of the reference, not a fixed-point/cycle-accurate emulator. Executed outcomes are recorded in verification.md.

## Timer expiry

BaseLevel DeathReason.TIMEOUT uses the presented death path and queues TIME UP before the lives/game-over sequence. Normal pit deaths remain unpresented. See [level timer](level-timer.md).

# Player death lifecycle

BaseLevel coordinates death for all stages. The implemented trigger is falling fully below the active camera viewport. Lives, game over, checkpoints, collectible coins and Mario's visible hit-death animation remain unimplemented. No life or session-counter deduction occurs.

## Detection and ownership

After player movement and camera/bounds processing, BaseLevel compares BasePlayer.death_envelope_top() with the active viewport bottom plus Fall Death Margin (default 34 pixels). The envelope uses the authored rectangular collision shape, independent of animation frames; small Mario's top is 14 pixels above his feet. Partially visible players do not die. With a viewport bottom at Y=240, small Mario triggers after his feet pass Y=288, 32 pixels deeper than the former Y=256 cutoff. This approximates the reference's vertical-page threshold after translating its 32px player drawing envelope to our feet-based origin. Cleanup still happens immediately at that cutoff rather than simulating the remaining invisible fall. Camera zoom and the occupied area's world position are included. Fall Death Enabled defaults to true. There is no bottom clamp.

BaseLevel.on_death(player, present=false) accepts the current player once and rejects duplicate death, shutdown and active transport. It freezes camera following/bounds handling and refuses new transport until restart. The death_started signal is notification, not ownership of the sequence. BaseLevel's physics callback continues only to coordinate death timing.

All other BaseEntity descendants are reversibly gameplay-suspended. Their FSM frame, physics, input, animation-finished callbacks and ordinary transitions are gated; entity/component physics callbacks are disabled with their previous enable states retained. Independent AnimationPlayer playback and the global cosmetic clock remain active. Clock-sampled question blocks and HUD coins keep their shared phase even though their native playback is paused. BaseBlock rejects new hits while suspended. This is gameplay suspension, not SceneTree pause or terminal shutdown.

Custom gameplay frame callbacks, external signals and animation method/property tracks must respect suspension: cosmetic animation must not move bodies, spawn objects or mutate gameplay while frozen. New autonomous physics types need explicit qualification. This does not suspend the entire physics server or implement a general pause menu. Off-camera enemy activation/disposal remains separate planned work.

## Player cleanup and optional presentation

BasePlayer.begin_death exits the current state without exit presentation, disconnects controller event delivery, cancels jump activity, stops current SFX, zeros velocity and disables collision layer/mask. is_dead prevents repetition.

For pit deaths, presentation is false: finish_death notifies the level immediately. The level performs terminal player shutdown, hides/queues the entity for removal, clears current_player and its own player reference. The level owns the remaining audio/timer, so removing Mario does not interrupt death completion.

Future visible deaths can assign a concrete player-owned Death State and request present=true. Controls/input are disabled for that state; it may perform its own death-only motion and calls finish_death when finished. This presentation contract is tested with a fixture; Mario has no visible Death State or hit-death artwork assigned yet. Missing presentation completes immediately. A watchdog prevents an unfinished presentation from trapping the level.

## Sound and completion

BaseLevel's Death Sound uses assets/soundtrack/smb_mariodie.wav through an independent, level-owned non-positional AudioStreamPlayer. A private runtime copy disables looping without changing the source/import settings. This is a death event sound; area soundtrack playback remains removed.

With a valid sound, completion waits for both presentation and the sound's finished notification. Missing audio uses Death Fallback Delay (default 1 second). Audio failure/no finish notification is bounded by the greater of the fallback delay and stream length plus one second. Death Presentation Timeout (default 10 seconds), extended for longer audio, bounds a stuck presentation. Shutdown stops/releases death audio. Deferred restart rechecks ownership so an old level cannot replace a new level after cancellation/replacement.

## Restart and progress

GameHandler.reset_progress_on_death is the global world-progress configuration, default false. It is a script variable on the existing autoload, not a new Project Setting. Set true to restore authored world state after death; false preserves progress. This replaces the earlier planned per-level flag.

GameHandler retains the loaded PackedScene and owns restart. It first shuts down the old level, allowing the final active area snapshot to save. If reset is enabled, it then clears only that level's stored progress before loading the same scene again. This ordering prevents shutdown from rewriting cleared data. Named levels use the existing scene-keyed progress contract; anonymous runtime fixtures retain their existing nonpersistent semantics.

Reload restores the original MainArea camera and the actual Players/PlayerSpawn marker. Inactive-area snapshots survive when preserving progress. Used/removed blocks and runtime tile edits follow the flag; future collected-world-coin records must join that contract. Coin counters, score, lives, power-ups and unrelated level data are not cleared by this policy. Normal pipe travel continues preserving progress independently.

## Reference and verification

The reference's PlayerHole/HoleDie separates off-screen fall handling from visible PlayerDeath presentation and uses death-event music before PlayerLoseLife. TimerControl also gates enemy movement and some enemy animation. Our independent audio completion, optional presentation and continuing cosmetic animation are deliberate adaptations, not cycle-accurate parity. See the [disassembly](https://gist.github.com/1wErt3r/4048722).

The death regression covers threshold visibility, duplicate/transport rejection, player state/input cleanup and freeing, reversible suspension with continuing animation, the optional presentation contract, real one-shot sound decoding/playback, restart at PlayerSpawn, both global progress policies across active/inactive areas, unchanged lives and stale restart ownership. See [verification](verification.md) for executed checks and limitations.

## Presented restart

After the existing death wait/jingle, GameHandler restarts through the global level transition: quick black, load, splash with HUD, quick black, gameplay. Progress-reset configuration and no-lives-deduction behavior remain unchanged. Standalone restart limitations still apply. See [transitions](transitions.md).

# Flagpole ending presentation

## Current behavior

1-1 has one stage in Game.Stages. Its configured flagpole now starts the reusable level-owned ending presentation: scripted Mario/flag descent, 24-tick dismount hold, automatic rightward walk, player retirement at the independent castle endpoint, score/fireworks completion hooks, music/final hold, then the normal final-stage return to title. The castle is a collision-free EntityLayout stamp with its own doorway and rooftop flag.

Score uses TimeScoreStep to convert remaining time into score without counting audio. Fireworks remains a no-op EndingStep. Flagpole height points are awarded when descent ends. The castle flag raises after time conversion. Fireworks are deferred. Both steps participate in the asynchronous completion contract. Top-score promotion belongs to common title entry after the final run score is known, before run cleanup.

## Authoring

The level root exports Ending Presentation. 1-1 points it to its FlagpoleEnding child, an instance of scenes/levels/endings/flagpole_ending.tscn. That presentation matches area_id=main and flagpole_cell=(196,2); other poles remain ordinary climbables unless configured. Binding uses the painted cell identity, never the closest pole.

Paint Castle (5x5) on the Overworld EntityLayout. The presentation pairs its flagpole_cell and castle_cell within area_id. In 1-1 the castle stamp is at (201,8), and its Doorway marker resolves to (3256,208). Moving the stamp moves the doorway and flag. Update castle_cell to match the new stamp. The castle prefab reuses the 21 decoration tiles from the previous layout.

Levels without an Ending Presentation retain manual climbing. Castle-ending presentations can implement the same LevelEndingPresentation contract later. Keep the configured pole and exit in the same active area for this first sequence; cross-area ending choreography is not implemented.

## Lifecycle and progression

BaseLevel.begin_ending accepts the configured presentation, current live player and source once. It gates normal timeout/death/transport/completion requests. GameHandler.claim_completion changes flow to COMPLETING and emits completion_started once without immediately replacing the level. Ordinary on_complete and Warp callers keep their previous direct progression behavior.

The presentation installs Mario's owned FlagpoleEnding state after the contact-state transition finishes. PlayerFlagpoleEndingState reuses climbing, horizontal movement, gravity and walk cadence while ignoring controller input. Scripted physics remains active; the presentation does not pause the FSM it needs to animate.

At the endpoint, the presentation calls player.shutdown(), clears matching BaseLevel.player and GameHandler.current_player references and queues the entity for deletion. The ending owns audio and hooks, so it continues after Mario is gone. No hidden stopping block or background-priority hiding is used. Handler-owned player/session status survives until normal next-stage/title policy runs.

BaseLevel.finish_ending only accepts its completed presentation. GameHandler then chooses the next stage through the existing stage list, or uses common title entry after the last stage. It does not require a surviving player. Final title entry promotes a higher final run score to top score, then performs the existing full run/progress cleanup.

Cancellation stops owned audio, invalidates hook tickets, releases the camera lock, resets the flag and restores controls. If cancellation occurs after retirement, the level recreates its player at PlayerSpawn and snaps the camera back. External level replacement restores normal PLAYING flow for the replacement. Source loss cancels the sequence rather than leaving a scripted player stuck. Level shutdown cancels outstanding presentation work; stale hook completion cannot advance a later run.

## Reference choreography

The source routines are recorded in [the reference investigation](flagpole-ending-plan.md). This implementation uses the following translated rules:

- Consume legitimate approach movement before acquiring a runtime camera lock. Attachment/side snaps do not count as forward camera travel. The lock is owned by the presentation, separate from authored Follow Enabled, and consumes tracking history while held.
- On contact, play smb_flagpole.wav once and start lowering the flag. Mario is forced onto the left side, facing right. Nominal downward speed is 1+$ff/256 pixels per tick, using our shared floating-point component.
- Mario stops near two pixels above the base, unless contact began lower. The flag sprite uses a fractional-byte accumulator (normally a one-pixel first step followed by two-pixel steps) and checks its stop threshold before movement, matching the reference ordering. Its center threshold is base-top minus 14 pixels, corresponding to reference flag top $aa at base top $c0; the last step can overshoot it by one pixel. Descent advances when the flag reaches its threshold or Mario reaches the fallback threshold two pixels below the base top. A low grab retains its Y so this fallback can end descent before moving the flag.
- Dismount places Mario on the other side facing inward, holds 24 ticks, then nudges four pixels outward and starts ordinary walk-profile motion. There is no invented jump impulse.
- When his feet reach base-top plus 14 pixels during the walk, release scroll lock and play smb_stage_clear.wav. Locked displacement is not caught up afterwards. A very close custom endpoint starts music/unlocks defensively at retirement if that threshold has not been reached.
- After the score and fireworks hooks finish and stage-clear playback ends, run a full 126-physics-tick hold (about 2.1 seconds). The reference reloads six 21-frame interval ticks and concurrently waits for event music, producing a phase-dependent roughly 105–126-frame timer. Our hold deliberately starts after music as well, preserving the requested visible pause even when timer conversion is short or skipped. This existing ordering is retained with time conversion; it differs from the reference's overlapping waits. Audio is bounded by stream length plus one second if completion fails.

The two sounds use runtime non-looping copies and the shared mix gain; existing asset import semantics are untouched. The presentation replaces earlier player SFX at contact and replaces flag audio with stage-clear music at the walk cue, avoiding layered player/presentation noise.

The accepted differences are the marker instead of hidden collision, actual player removal instead of drawing behind the castle, silent time conversion and the temporarily empty fireworks hook. Continuous floating-point movement, current climb animation cadence and renderer scheduling are not byte/cycle-accurate qualification; exact original-hardware parity is not claimed.

## Score conversion and fireworks completion

EndingStep.begin increments a ticket and calls _begin(ticket). The default immediately calls complete(ticket). Override _begin in a derived script to perform future work, then call complete with that original ticket. Only the current active ticket emits finished, once. cancel invalidates it. The presentation retains grab_height above the base and remaining_time_at_contact for later reward logic, independent of player lifetime. Score runs before the castle flag raise and Fireworks. The presentation waits for these phases, the final delay and music.

Mario reaches the center of the doorway and is retired immediately, matching the reference disappearance timing. TimeScoreStep begins on retirement. It subtracts one GameHandler.time_remaining unit and calls GameHandler.add_score(50) per physics tick, beginning on the following tick. At 60 Hz, 300 units award 15,000 points over about five seconds. HUD values update through their existing signals; the original remaining_time_at_contact stays unchanged for future fireworks selection. Conversion does not wait for stage-clear music to end. After the final decrement reaches zero, the following tick completes Score and starts the castle flag raise, matching the reference task check order. No extra Score-phase delay is introduced.

Timer-disabled stages and already-zero counters skip conversion immediately, without points or timer mutation. The step uses a weak reference to its owning BaseLevel, checks current-level/completion ownership and its ticket, and disables physics callbacks on completion/cancellation. It checks ownership again after timer notifications so a synchronous level replacement cannot credit the new session. Partially awarded points remain if the ending is cancelled; future units stop. Existing score clamping remains in GameHandler/PlayerStatus.

The counting SFX is deliberately absent. The reference uses Sfx_TimerTick/PlayTimerTick on square channel 2 (six-frame effect, requested during four of every eight global frames). Acquisition, gain normalization and cadence integration remain backlog work; stage-clear and flag audio are unchanged.

Hooks notify completion and use GameHandler for rewards rather than player-owned counters. An individual hook does not dispatch stage progression.

## World-space score popup

Instantiate `scenes/components/presentation/score_popup.tscn` and add it to a world-space parent. Call `show_score(amount, world_position)` for points or `show_one_up(world_position)` for an extra-life display. The position is the center of the 16×8 tile. The scene starts hidden and uses nearest filtering. Unsupported point amounts hide the popup and return false.

The atlas supports 100, 200, 400, 500, 800, 1000, 2000, 4000, 5000, 8000 and 1 UP. Callers own motion, lifetime and reward application. The flagpole presentation selects 100, 400, 800, 2000 or 5000 points from the first accepted grab. Heights above 16, 56, 80 and 126 pixels advance to the next tier after applying the reference whole-pixel Y conversion. The popup starts 12 pixels right of the shaft and 12 pixels above the base, measured at its center. It rises with the flag descent using the upward fractional step and stays in place afterward. Cancellation hides and frees it. The height bonus is applied once when descent ends, before the separate time conversion.

## Castle flag raise

CastleEntity owns the flag sprite behind the castle tiles. After Score completes, the presentation advances it one pixel per physics tick for 31 ticks, then begins Fireworks on the next tick. The reference starts the flag at $90 and checks for Y below $72 before advancing. The presentation drives these steps even when the camera buffer suspends the castle's own callbacks. Cancellation resets and hides the flag.

## Return transition

The finish definition keeps gameplay and HUD hidden for the existing minimum 12 ticks while loading the title, followed by a 12-tick quick outro. A title created during a transition stays hidden until the coordinator finishes, so its UI and background appear together. No black cover or background override is added, and startup still opens directly on the title.

## Verification

flagpole_ending_test covers descent and flag motion, ignored controls/stopped timer, locked camera without unlock catch-up, timed dismount, a real walk to the independent endpoint, player lifecycle removal, independently delayed/stale score/firework hooks, real music after player retirement, covered title return, cancellation recovery, external replacement and source loss. time_score_test covers conversion cadence, HUD values, original timer preservation, disabled/zero timers, exactly-once completion, cancellation/stale callbacks, reentrant replacement and score saturation. Existing level_completion_test retains direct/Warp/next-stage and ownership coverage. See [verification](verification.md) for actual run outcomes.

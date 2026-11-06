# Level timer

BaseLevel owns countdown phase and timeout detection. GameHandler.load_level initializes the displayed value once from Starting Time and publishes Timer Enabled. After the destination intro finishes, the idempotent BaseLevel.on_level_start() arms a full first interval and emits level_started; it does not assign the starting value again. Title backgrounds never start gameplay timers.

## Timing and pauses

One displayed TIME unit lasts 24 active physics ticks, following the reference GameTimerCtrlTimer reload of $18. This is a game timer, not a wall-clock second. The project starts at the authored value and gives it a full interval rather than reproducing the NES entrance's extra initial unit/immediate decrement.

001 becomes 000 after one interval. Another complete interval at 000 triggers timeout. Countdown pauses during transitions, area transport, death and completion; paused ticks are not caught up. Area changes retain the current value and partial interval. Death respawn loads the level and initializes its authored starting value again.

The shared animation clock remains untouched: question blocks and HUD coins retain their matching phase. The countdown observes its tick count without resetting or synchronizing that clock at level start.

## Timeout lifecycle

Timeout calls BaseLevel.on_death(player, true, DeathReason.TIMEOUT), forces small powerup status as in the reference, and uses Mario's existing Dead presentation. Life charging, entity suspension and player cleanup remain in the death lifecycle. Afterwards the coordinator presents TIME UP for 147 nominal physics frames (the reference's seven 21-frame screen intervals), with the HUD showing 000. It then runs the existing lives intro/respawn or, when reserves are below zero, GAME OVER and common title return.

TIME UP uses existing transition phases and no new black cover. External replacement/shutdown validates ownership before continuing the old death sequence. Pit deaths retain their existing non-presented path and do not show TIME UP. Hurry music is not implemented.

## Authoring

On the level root, set Starting Time (0–999) and Timer Enabled. Disabled timers retain the TIME heading but hide its numeric value. TestLevel disables the timer; 1-1 uses the enabled default. No Project Settings or input bindings change.

The start hook is driven by GameHandler's PLAYING flow after transitions. Standalone scene execution outside that flow does not implicitly start a timer.

## Verification

The level_timer_test scene checks single value initialization, a full first interval, idempotent start, phase-preserving pauses and area transfers, disabled HUD digits, zero dwell, animated timeout, and TIME UP before both respawn and GAME OVER. Run it through scripts/run_tests.ps1 with the rest of the gameplay regressions.


## LevelTimer ownership

BaseLevel starts and advances its LevelTimer child on eligible gameplay ticks. LevelTimer retains the 24-tick phase through pauses and updates GameHandler.time_remaining. It signals expiry once after the zero interval. BaseLevel routes that signal into timeout death. Test Level disables the timer and keeps the TIME label visible.

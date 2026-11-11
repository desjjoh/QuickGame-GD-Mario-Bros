# Backlog

## World 1-3 verification

- Play through 1-3 from spawn to the Large Castle ending. Check lift crossings, Red Parakoopa encounters, and the return to title in a normal run.

## Brick breaking

Breaking physics, themed debris, the cached shatter cue, delayed follow-up bonk, and 50 points without a popup are implemented. Accepted bumps and breaks collect a world coin directly above the block. Goombas, Koopas, shells, and mushrooms share ordered block-hit delivery.

- Compare receiver selection near brick seams if a block hit unexpectedly misses or catches an actor. The game currently uses a strip query where the NES uses an actor terrain probe.

Keep the accepted cached audio. Live shared noise-channel playback was removed after causing stutter.

## Level and entity authoring

- Extend climbable behavior to vines and add their detach rules.
- Define restart behavior for standalone F6 levels.
- Add standalone power-up painting when needed; no dedicated power-up layer currently exists.

## Presentation and reference checks

- Compare castle-firework timing, blast playback, and the final music/hold handoff with Mesen.
- Compare generated cues and music with Mesen, including loop seams, pulse takeover, and voice balance.
- Add Castle and Water tracks when stages need them.
- Reproduce occasional camera hitching at high refresh rates in a rendered build.
- Reproduce the intermittent moving-Koopa stray pixel and investigate fractional-position compositor differences.
- Reproduce the natural right-edge shell/pair contact report. Controlled rejection tests verify retry behavior but do not establish that the reported encounter is resolved.
- Extend movement comparison beyond the current flat-ground landing/turn/re-jump captures to broader terrain and rendered play.

## Verification

- Requalify the full suite when requested. The game-over, jump benchmark, timer fixture, Mario form fixture, and resolution-aware shadow checks now pass their focused checks.
- Distinguish rendered-only test skips from failures in the headless runner; `window_render_test` currently skips headless execution while the runner requires PASS.
- Investigate native shutdown failures if reproducible. Regression teardown addresses the isolated deferred audio cleanup warnings; this does not certify every native shutdown path.

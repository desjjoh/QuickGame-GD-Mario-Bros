# Castle fireworks

## Ownership and sequence

CastleEntity owns one Sprite2D under Fireworks/Burst, using the three frames of assets/items/fireworks.png. No projectile, enemy slot, collision body, or independently spawned entity is involved. The flagpole presentation asks CastleFireworksStep to run the castle's sequence after the tiny flag finishes rising. The adapter advances the castle once per eligible physics tick, requests sound, awards points through GameHandler, and reports completion through the existing EndingStep ticket contract.

At the castle doorway, before starting timer conversion, FlagpoleEndingPresentation configures the adapter from the current remaining time. The last digit 1, 3, or 6 selects that many bursts; all others select zero. Disabled timers also select zero. remaining_time_at_contact remains the separate original flagpole snapshot. Changing that diagnostic snapshot does not configure fireworks. A zero count completes the fireworks step immediately.

## Timing and artwork

The first burst appears when the fireworks step begins. Each of the three frames lasts eight nominal 60 Hz ticks. A burst finishes at tick 24, then an eight-tick gap precedes the next launch at tick 32. Sequence lengths are 24, 88, and 184 ticks for one, three, and six bursts. The adapter skips an advance on its begin tick so the first frame gets its full duration. Pause freezes the sprite and local elapsed ticks together.

The NES uses six fixed position entries, traversed backwards. One burst uses entry 5; three use entries 5, 4, 3; six use entries 5 through 0. X offsets relative to the castle flag are -48, 0, 48, 48, -48, -16. Y offsets relative to the doorway's floor are -112, -144, -96, -144, -112, -160. Sprite top-left is four pixels above/left of each reference object anchor. Local offsets let the effect move with the castle. Physics interpolation is disabled on the burst so changing locations does not sweep the image through the sky.

When a burst finishes, the castle emits firework_finished. The adapter requests the blast and awards 500 points once. It hides the sprite before notifying listeners. Cancellation hides it, invalidates the step ticket, disconnects the callback, and stops a playing fireworks cue without stopping an unrelated shared-voice cue. Level shutdown also cancels the castle presentation.

## Reference and sound

Reference: [SMB disassembly](https://gist.github.com/1wErt3r/4048722), GameTimerFireworks, InitFireworks, RunFireworks, FireworksSoundScore, DrawExplosion_Fireworks, PlayBlast, and FreqRegLookupTbl. The reference selects the count before timer conversion, launches at 32-tick spacing, advances graphics every eight ticks, and requests sound and 500 points on removal.

SoundHandler renders the square-two blast at frequency-table offsets $5e and $18 (periods $2f9 and $17c): eight frames with control $9f/sweep $94, then 24 frames with control $9f/sweep $93. The shared pulse generator accepts square-two sweep negation without changing existing square-one callers. Playback remains non-positional with default gain and pitch, on the existing shared reward voice. Music pulse takeover uses the existing reward-voice notifications.

The current ending's post-delay and music wait are retained. The NES starts its end-delay task around the last launch and waits for music concurrently; exact first-frame, audio, and final handoff alignment still require Mesen comparison. The implementation waits for the last completed burst, then uses the existing ending wait. Exact full-sequence parity is not claimed.

## Verification - 2026-11-07

Godot 4.7.2 headless fireworks_test reached PASS. It covers all final digits and disabled timers, 0/1/3/6 castle sequences, every frame and position, exact burst completion ticks, repeated completion, cancellation, generated audio duration, real doorway-time selection distinct from contact time, timer conversion/flag/fireworks ordering, 1500 points for three bursts, shared-voice routing, and pause/resume.

Flagpole-ending, time-score, level-completion, pause, and sound-mix regressions also reached PASS. Flagpole-ending and level-completion reported two ObjectDB leaks each. Focused formatting checks were performed. No full suite, rendered playtest, or Mesen listening/frame comparison was performed.

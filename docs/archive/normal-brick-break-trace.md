# Normal input-only NES brick-break trace

## 2026-11-08

No game-code changes were made. Captured original 1-1 from boot using controller input only: Start, approach/jump past the Goomba, hit the mushroom question block, collect its mushroom naturally, then stand under the ordinary brick at world X352 and jump. OperMode remains 1 (actual game), not the title demo. No RAM/ROM writes, save-state injection, position/form/velocity injection, or block-buffer edits occur. Lua memory callbacks only observe writes and return no replacement values.

Runner: the existing isolated Mesen runner. ROM SHA-256: f61548fdf1670cffefcc4f0b7bdcdd9eaba0c226e3b74f8666071496988248de. ROM is not included. Script: reference/normal-brick-input.lua. Frame log: reference/normal-brick-input.csv. Ordered CPU writes: reference/normal-brick-writes.csv. PNGs reference/normal-brick-934.png through -939.png preserve the six visual frames. Run with QUICKGAME_REFERENCE_OUTPUT pointing at the capture directory and Mesen.exe --testRunner --timeout=20 <local ROM> <script>.

Initial pilot runs died before collection, or entered the attract demo when a one-poll Start pulse was missed. The final script holds Start across several polls and explicitly records mode/mode_task. Those unsuccessful pilot observations are not used as the normal-play trace. The final input-only capture was repeated with observation callbacks and again with screenshot capture, reproducing the sequence.

### End-of-frame results

NES Player_Y_Position ($ce) is used here, not Godot's feet coordinate; smaller Y means upward.

| Frame | Meaning | Y | Signed integer Y speed | Fractional force ($433) | Position fraction ($416) |
| --- | --- | --- | --- | --- | --- |
| 934 | Last frame before break | 157 | -4 | 160 | 64 |
| 935 | Brick breaks | 153 | -2 | 192 | 224 |
| 936 | One further upward pixel, then reversal | 152 | +1 | 224 | 160 |
| 937 | Descending | 154 | +2 | 80 | 128 |
| 938 | Descending | 156 | +2 | 192 | 208 |
| 939 | Descending | 159 | +3 | 48 | 144 |

### Ordered writes around the break

Callbacks run before the observed write, so adjacent columns in the write CSV describe old memory, while address/value identify the upcoming write.

Frame 935:

1. Normal integration writes Y157→153 and updates the fraction fields.
2. At CPU PC $bd4d, the hit writes temporary metatile $23 to block-buffer address $0646.
3. At PC $be13, BrickShatter writes $fe (-2) to $009f. Y remains 153 at that point; it is a speed change, not an immediate position adjustment.

Frame 936:

1. Position fraction $e0 + force $c0 produces carry 1, so integer displacement is -2 +1 = -1. Y153→152 at PC $bfef.
2. Gravity updates the fractional force to $e0 and retains integer speed -2.
3. At PC $dcf6, the head collision response writes speed +1. The temporary solid cell is still present at this time.
4. At PC $bef6, the block updater replaces $0646 with $00 after the reversal.

Frame 937 then integrates downward to Y154.

### Conclusion and scope

The $fe write survives into one real movement update in this ordinary straight-up break. Mario does move one additional integer screen pixel upward, then reverses on the same next frame. It is not overwritten before that update, not a fixed two-pixel allowance, and not equivalent to a long freely rising arc. This trace resolves the previously uncertain write/update order for this encounter.

This is one ordinary straight-up brick break after natural growth. It does not establish every running, seam, crouched, or VRAM-busy case. The currently selected project behavior still stops vertical motion immediately, as the user requested and playtested; this investigation does not change it or claim that zero extra displacement is byte-for-byte identical to this recorded encounter. Broader interpretations about engineering intent are not established by the capture.


## 2026-11-08 — Running jumps and brick seams, input-only extension

Extended the boot-to-mushroom route using reference/running-brick-input.lua, with BRICK_TRACE_DIRECTION (+1/-1) and BRICK_TRACE_TAKEOFF (world sprite-left X) as controller-route parameters. No game memory, ROM, or save-state writes are performed. Each run naturally starts the game, acquires Super, stages on the visible floor, then holds Run/direction and jumps at the specified threshold. Observed OperMode=1 and mode task=3 during all retained test jumps. Each case records frame state, ordered writes, shatter events with actual struck brick/head coordinates, and initial screenshots. The edge-escape case includes screenshot offsets 0–12. Controller target positions are not substitutes for actual hit positions; those are recorded by the BrickShatter speed-write callback.

The final rightward staging point is X336, limited by the NES camera's one-way scroll after natural mushroom collection; leftward staging is X432. Rightward acceleration therefore varies with the takeoff threshold, while leftward approaches have longer run-up. Do not call every retained attempt a maximum-speed run. Thirteen unreachable rightward pilot takeoffs (the camera prevented reaching their earlier staging point) were excluded and their unused CSVs removed. Two initial Lua launches timed out due to a script-local label declaration error, corrected before successful capture. These are pilot failures, not evidence about game collisions.

### Retained capture set

21 completed jump routes: 14 shatter events and seven routes with no shatter. Per-run files are reference/running-{left|right}-<takeoff>-frames.csv, -writes.csv, -events.csv and associated PNGs. reference/running-brick-summary.csv indexes actual break frame, brick coordinate, head coordinate, seam offset, speed, immediate/maximum extra ascent and first downward-speed frame. Seven no-shatter routes remain explicit outcomes, not silently discarded successful breaks.

| Case | Brick X / head X at break | Horizontal outcome | Post-break vertical outcome |
| --- | --- | --- | --- |
| right-366 | 384 / 384 (exact left seam) | Keeps rightward speed | One extra upward pixel; +1 speed next frame |
| right-367 / right-368 | 384 / 386 (2px into tile) | Keeps rightward speed | One extra upward pixel; +1 next frame |
| right-372 | 384 / 391 | Keeps rightward speed | One extra upward pixel; +1 next frame |
| right-376 | 384 / 395 | Keeps rightward speed | One extra upward pixel; +1 next frame |
| left-388 / left-390 | 384 / 385 (1px into tile) | Speed cleared on next frame | One extra upward pixel; +1 next frame |
| left-366 / left-370 | 352 / 360 or 365 | Speed cleared on next frame | One extra upward pixel; +1 next frame |
| left-350 / left-358 | 352 / 356 | Already stopped on break frame | One extra upward pixel; +1 next frame |
| left-392 / left-394 | 384 / 387 or 390 | Speed cleared on next frame | One extra upward pixel; +1 next frame |
| right-378 | 384 / 398 (2px before row end) | Keeps rightward speed | Escapes row; continues rising five pixels total |

All 14 shatters write $fe to Player_Y_Speed through BrickShatter. Thirteen reverse to +1 on the following frame after one extra upward pixel. In right-378, the next head X is 400, beyond the final brick at [384,400), so it does not sample the temporary broken cell: speed stays negative and normal fractional gravity continues the ascent. At frame 984 it breaks at origin Y152; frames 985–991 reach Y151,150,149,148,148,147,147. Speed becomes nonnegative at 992 and positive at 994. There is no neighboring solid ahead to catch it. This is a captured normal-play escape outcome, not merely a deduction from the $fe instruction.

Leftward seam cases show that the original really can stop horizontal movement beside a newly broken brick. Therefore a golden rule that every shatter preserves horizontal travel is incorrect. Separate head and side probes, their fixed checking order, cell position and movement direction matter. These captures also supersede any universal claim that the -2 write is always overwritten before movement or always reverses after one tick.

### Scope and project decision

This investigation leaves project behavior unchanged. The user's selected no-ascent brick response is intentionally retained; it should not be described as exact emulation of these traces. No new immunity, marker, timer, position snap, or collision rule was added. Current reference evidence should guide any future fidelity discussion, but does not override that explicit gameplay choice.

Final retained capture runs exited successfully. The existing ROM hash recorded above applies. No full game regression suite was run because this work only adds observation scripts/data/documentation. Screenshots were inspected for the edge-escape trajectory. This set covers the first 1-1 row with its actual intervening question/used blocks, held Jump, running-button approaches and both directions. It does not exhaust other rows, tapped Jump, crouch jumps, or every fractional state. There is no byte-for-byte Godot comparison in this extension.

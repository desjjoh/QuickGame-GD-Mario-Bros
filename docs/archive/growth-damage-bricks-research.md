# Growth, injury, Super Mushroom, and brick breaking

Research date: 2026-11-07. Steps 1–2 are implemented in [Mario-owned form presentations](mario-form-presentations.md), and steps 3–4 in [Super damage](super-mario-damage.md) and [Super Mushroom](super-mushroom.md). Brick breaking remains proposed. Work order agreed with the user: steps 1–2 together (growth/shrinking), steps 3–4 together (damage/Super Mushroom), then step 5 (brick breaking). Keep the existing Mario instance and movement state machine. Do not add modern gameplay enhancements without discussion.

## Evidence and limits

Primary source: [Super Mario Bros. disassembly](https://gist.github.com/1wErt3r/4048722). Labels below are preferable to line numbers, which depend on the downloaded revision. Existing terrain/contact findings remain in [Super Mario movement](super-mario-movement.md) and [Super Mario research](super-mario-research.md).

Mesen 2.1.1 executed the original NTSC reference ROM using [form-change-trace.lua](reference/form-change-trace.lua). [Selected trace rows](reference/form-change-mesen.csv) preserve every change in routine, size, animation control, and injury timer. These are controlled RAM fixtures entering the routines with their expected initial values, not an input-only pickup/injury playthrough. ROM bytes were unchanged. This verifies routine timing and position retention, but does not establish pickup alignment, enemy contact ordering, airborne transformations, or brick debris visually. No gameplay code, project settings, or import options were changed for this investigation.

## Steps 1–2: growth and shrinking

`PlayerStatus` describes Small/Super/Fire (0/1/2); `PlayerSize` describes large/small (0/1). They change at different moments. Do not use a visual pose alone as the authoritative gameplay form.

| Detail | Reference behavior |
| --- | --- |
| Growth entry | `UpToSuper` sets status Super, routine 9, player state 0, master timer `$ff`, and scroll amount zero. |
| Growth size switch | `PlayerChangeSize` calls `InitChangeSize` at timer `$f8`. It toggles size, initializes animation control, and sets the change-size flag. |
| Growth poses | `ChangeSizeOffsetAdder`: Small, intermediate, Small, intermediate, Small, intermediate, Super, Small, intermediate, Super. |
| Shrink entry | `ForceInjury` sets status Small immediately, injury timer 8, injury/pipe sound, routine 10, player state 1, master timer `$ff`, scroll amount zero. |
| Shrink size switch | `PlayerInjuryBlink` falls through into `InitChangeSize` at exactly `$f0`. |
| Shrink poses | Alternates Small and Super swimming poses using `ShrinkPlayer`; this is not the growth sequence played backward. |
| Pose advance | `HandleChangeSize` advances when global frame counter AND 3 is zero; ten control entries, then clears the flag. The first entry can be shortened or skipped by global phase. |
| Routine completion | Growth ends at `$c4`; injury ends at `$c8`. These are separate from the end of the pose cycle. |
| Position | Size initialization does not move Mario or test headroom. Maintain the common feet/canvas anchor. |

Measured fixture: growth entered on frame 341, switched size/started animation on 347, cleared the change flag on 383, returned to routine 8 on 399. Injury entered on 461, switched size on 475, cleared the flag on 511, returned on 515. Mario's Y stayed 176 throughout both fixtures. Read these as observed frame indices for this fixture, not universal phase-independent animation durations. Master-timer differences are 59 ticks for growth (`$ff` to `$c4`) and 55 for injury (`$ff` to `$c8`), subject to entry/update ordering.

The master timer suppresses normal frame/interval timer decrements while it counts down. The global frame counter continues; player movement is also gated by `PlayerChangeSizeFlag`. This is not equivalent to pausing the whole scene tree: graphics and routine processing continue, and injury calls player control during part of its sequence. Audit each affected subsystem rather than claiming every object freezes identically. User pause must freeze the sequence without disabling the existing pause cue path.

Original ownership proposal: extend the existing form controller with a finite transformation sequence, retaining the body, camera target, and actor. Let a presentation coordinator gate normal pose/movement ownership during that sequence; keep authoritative form/session updates explicit. The user subsequently chose Mario ownership. The implemented Mario child and limited level gate are described in [form presentations](mario-form-presentations.md); no duplicate player scenes or level-ending dependency were added.

Artwork: both Small and Super swimming sheets have been supplied, alongside the growth intermediate. The first swimming frame in each sheet was selected after comparison with the source graphics table and Mesen captures during phases 1–2. Additional swimming frames remain unused here.

Focused checks: exact pose order and logical-size switch; preserved feet, position, and actor; grounded and airborne entry; ceiling overlap without a headroom gate; pause/resume; completion restores pose ownership once; death/area teardown cancels safely. Compare actual pickup/injury in Mesen before declaring visual parity.

## Steps 3–4: damage and Super Mushroom

`ForceInjury` kills Small Mario, but demotes both Super and Fire directly to Small. It does not stop at Super when Fire is hurt. `KillPlayer` clears horizontal speed and starts the death sequence with vertical speed `$fc`. Keep lethal hazards such as falling and timer expiry separate from ordinary enemy damage; invulnerability must not prevent those outcomes.

`InjuryTimer` starts at 8 and decrements on the shared 21-frame interval timer only after the master timer releases it. In the fixture it remained 8 throughout shrinking, first became 7 on frame 521, and reached zero on 668. This is 153 frames after routine completion here; remaining protection varies with interval phase. `PlayerGfxHandler` skips drawing on alternating global frames while the timer is nonzero. This is damage protection, distinct from Starman behavior. Contact guards must prevent repeated injuries and duplicate transitions.

`SetupPowerUp` resolves a mushroom/flower block's reward at release: Small produces a mushroom, Super or Fire produces a flower. The type is then retained by that live object. Existing 1-Up and Star types bypass this tier selection. Thus a tiered reward should be a semantic reward choice that resolves a scene when released, alongside explicit 1-Up, coin, and timed-coin choices in the existing reward painter.

`HandlePowerUpCollision` erases the pickup, requests the 1000-point popup and grab cue, then branches on status. Small becomes Super. Super becomes Fire; Fire stays Fire. The mushroom/flower collection branch is shared: even an already-released mushroom collected after becoming Super follows the status-based Fire upgrade. Discuss the temporary policy while Fire is unavailable; do not silently invent an extra-life reward or unsupported Fire form.

Reuse `PowerUp → Mushroom` for Super Mushroom movement, emergence, block interaction, activation limits, and cleanup. Give Super Mushroom its collection effect, reusing the existing score/popup/audio paths. Route ordinary enemy damage through one player damage entry point instead of each enemy deciding death. Keep session form and live form synchronized, including reload and death rules.

Release nuance: `GrowThePowerUp` rises on global four-frame cadence, remains behind background during emergence, then starts rightward with speed `$10` (1 pixel/tick in its fixed-point horizontal representation). It begins drawing/contact routines once emergence state reaches 6, before full release. Current `PowerUp` disables collection until emergence finishes. This difference needs an explicit implementation discussion and an overlap test; it is not silently changed by this research.

Focused checks: Small damage kills; Super damage shrinks once; contact protection and blink expire correctly; hazards remain lethal; collection grants 1000 once and frees once; tier is selected at release; reward replacement and reload contracts survive; airborne/ceiling pickup; pause freezes all local sequence timers. Fire Flower and Starman remain later features.

## Step 5: brick breaking

`PlayerHeadCollision` selects breakable state for large Mario and bounce state for Small. Reward metatiles override that choice to bounce for either size: an unspent reward brick must dispense its reward rather than shatter. Depleted reward blocks retain their established solid behavior. Crouch changes the sampled head position, but the break decision uses size, not crouch.

`BumpBlock` sets player vertical speed to zero. `BrickShatter` instead sets it to `$fe` (−2 pixels/tick): breaking must not simply reuse the regular bonk response unchanged. It immediately removes/replaces the terrain metatile, requests the noise-channel shatter cue, spawns chunks, and awards 50 points through score digits. There is no floating 50-point popup in that routine. Both bounce and shatter call `CheckTopOfBlock`, which collects an ordinary coin immediately above the block through the jumping-coin path.

Four visible 8×8 chunks use two simulated trajectories and mirrored X positions. Initial horizontal speed is `$f0` (−1 pixel/tick), with the opposite pieces mirrored around the original block; initial vertical speeds are −6 and −4 pixels/tick, lower pieces start 8 pixels below the upper pair. `ImposeGravityBlock` supplies `$50` fractional acceleration; confirm its integration/cap and initial rendering offsets before translating constants into Godot units. `DrawBrickChunks` uses global frame bits 2–3 for flips. They are presentation debris, not four colliding terrain bodies. The source removes the chunk object after its upper trajectory passes the bottom threshold `$f0`; Godot should use its established cleanup boundary while preserving the visible trajectory, with any difference documented.

Proposed change: add a break outcome to the existing block-hit route, using Mario's existing `can_break_bricks` capability and the block's reward/depletion rules. Keep the reusable block-impact notification so enemies/power-ups above the brick still receive their existing reaction. Check reference victim behavior on a shattering brick before assuming it equals bounce. Make terrain removal and reward/score effects occur once; retain the project's area-progress policy explicitly rather than copying NES storage mechanics.

Focused checks: Small bounces; standing/crouched Super breaks ordinary brick variants; reward bricks dispense; depleted blocks stay solid; upward velocity differs correctly; coin above is collected once; impact victims; 50 points once; theme artwork; debris cleanup and pause; area/death persistence. Mesen input-driven brick break/debris comparison and final sound/art alignment remain required before claiming this step matches.

## Readiness

The sequence and core source branches are documented, and routine timing was measured in Mesen. Phases 1–4 have implementation notes covering focused verification and fidelity limits. Until Fire is implemented, Super Mushroom gives already-Super Mario 1,000 points and retains Super under the agreed first-pass policy. Early-emergence pickup timing remains unchanged; shatter victim/debris edge cases still need investigation before brick breaking. These are bounded follow-up checks, not verified behavior. No regression suite was run for the original documentation-only investigation.

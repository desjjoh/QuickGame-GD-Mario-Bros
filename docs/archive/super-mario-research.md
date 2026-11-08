# Super Mario reference investigation

Date: 2026-11-07. Status: research complete for the source paths below; emulator observations outstanding. No Super Mario behavior is implemented by this document.

## Scope and evidence

The behavior target is the original NES Super Mario Bros. Do not introduce modern gameplay enhancements or alternative rules unless the user requests alternatives. In particular, do not prevent uncrouching or growth merely because the taller body overlaps terrain.

Primary source: [SMB disassembly](https://gist.github.com/1wErt3r/4048722). Research used the existing local copy at `.godot/validation/smb-reference.asm` and cross-checked the public source. Labels below identify evidence rather than relying on fragile webpage line numbers. Code instructions take precedence over misleading assembly comments; observations and deductions are distinguished below.

No Mesen session was running when checked, and no NES ROM was found among repository files. No emulator replay, screen capture, ROM modification, or frame-by-frame gameplay comparison was performed. The scenarios in the final section remain required before claiming visual or complete behavioral parity.

## Coordinates, graphics, and enemy contact

The NES renders the player on a 16x32 sprite canvas for both sizes. Small Mario uses blank tiles in the upper two rows; crouching Super Mario has a blank upper row and three occupied tile rows. Tile occupancy is not an exact opaque-pixel measurement. Super's standing art spans four tile rows. Therefore cropped modern sprite sheets must preserve the same feet anchor rather than reuse a single center offset for every pose.

Use NES origin `(x, y)` below. The shared nominal feet baseline is `y + 32`; the horizontal canvas center is `x + 8`. Mapping to this project's feet-centered Body origin means subtracting `(8,32)` from reference-local points. Actual visible NES OAM placement/opaque pixels still require rendered checking; do not infer an inclusive pixel count from the coordinate spans below.

`PlayerCtrlRoutine` selects `Player_BoundBoxCtrl`: 0 for big standing, 1 for small, 2 for big crouching. `BoundBoxCtrlData` supplies these object-contact rectangles:

| Profile | Reference left/top/right/bottom | Coordinate span | Project feet-centered rectangle |
| --- | --- | --- | --- |
| Super standing | (2,8)-(14,32) | 12x24 | (-6,-24)-(6,0) |
| Small | (3,20)-(13,32) | 10x12 | (-5,-12)-(5,0) |
| Super crouched | (2,20)-(14,32) | 12x12 | (-6,-12)-(6,0) |

These are object-contact boxes, used by the enemy collision path, not the terrain body. Current Small Mario already has a 10x12 EnemyHurtbox centered at (0,-6). Super can use standing 12x24 centered at (0,-12), crouched 12x12 centered at (0,-6), subject to Godot edge-contact verification. Fire Mario uses the big size path; color/status is separate from PlayerSize.

Evidence: `PlayerCtrlRoutine`/`SizeChk`, `BoundBoxCtrlData`, `BoundingBoxCore`, `PlayerEnemyCollision`, `PlayerGraphicsTable`, `RenderPlayerSub`, `ProcessPlayerAction`.

## Terrain is a probe system

`PlayerBGCollision` chooses a seven-entry probe group using `BlockBufferAdderData`: offset 0 for big standing on land, 7 for big swimming, 14 for small or crouching. Land probes relative to the NES origin:

| Profile | Head | Left/right feet | Left side, upper/lower | Right side, upper/lower |
| --- | --- | --- | --- | --- |
| Super standing | (8,4) | (3,32), (12,32) | (2,8), (2,24) | (13,8), (13,24) |
| Small / Super crouched | (8,18) | (3,32), (12,32) | (2,24), (2,24) | (13,24), (13,24) |

The lower profile repeats its side sample rather than testing a full-height edge. Feet remain fixed. The standing head is 28 pixels above the baseline; the short head is 14 pixels above it. This does not establish a perfect 11x28 standing terrain rectangle: the center head probe and side probes have different extents. Current Small Mario uses an 11x14 CharacterBody2D rectangle plus corner correction and bonk probes, already an approximation of this distinction.

Head checks have vertical screen bounds (`PlayerBGUpperExtent`, $20 big/$10 small or crouched). A head metatile reacts as a bonk only while rising and when the player's origin low Y nibble is at least 4. Solid terrain reverses vertical motion; interactive blocks use PlayerHeadCollision and existing block-bounce gating. Standing inside a ceiling with zero/downward velocity does not independently fire the rising head-bonk path. Feet and sides also have screen/metatile-specific gates.

Evidence: `ChkCollSize`, `HeadChk`, `DoFootCheck`, `DoPlayerSideCheck`, `BlockBufferAdderData`, `BlockBuffer_X_Adder`, `BlockBuffer_Y_Adder`, `BlockBufferCollision`.

## Crouch input and movement

Source-confirmed rules:

- Small Mario clears CrouchingFlag. Big Mario samples Down only when Player_State is grounded (0). While airborne, it skips the write and preserves the existing flag.
- Releasing Down while grounded clears crouch without a terrain-fit test. Releasing Down during a crouch jump does not clear it midair. Pressing Down after an ordinary jump does not initiate crouch midair.
- Grounded Down plus either horizontal input clears both the horizontal and vertical directional bits before crouch selection. It does not simply retain Down and disable walking. This can clear an existing crouch; input combinations and simultaneous-frame transitions need Mesen confirmation.
- Ground movement still runs shared friction and horizontal integration. Entering crouch does not explicitly set horizontal speed to zero. Existing momentum can slide while friction reduces it; there is no separate crawl engine.
- A fresh Jump press from the ground uses the same speed-dependent jump-force tables whether standing or crouching. Crouch does not have an independent reduced jump impulse.
- Airborne horizontal input still uses the shared air movement path. Releasing Jump still selects the stronger falling force through the normal variable-jump handling.
- A crouch jump selects the crouch artwork while Player_State remains jumping. Landing sets Player_State to grounded during collision, after that frame's crouch sampling; the following movement update can re-sample Down. Do not equate vertical descent with the separate Falling state: JumpSwimSub handles both halves of a normal jump.
- `ActionFalling` selects walk/run graphics without checking crouch. A crouched walk-off may therefore have a different visual result from a crouch jump even while its preserved flag selects short collision. This requires emulator observation, not a blanket crouch-air-animation assumption.
- `PJumpSnd` selects separate big/small jump cues by PlayerSize. Do not approximate this with unverified pitch or gain changes.

Evidence: `PlayerCtrlRoutine`, `PlayerMovementSubs`, `OnGroundStateSub`, `CheckForJumping`, `ProcJumping`, `JumpSwimSub`, `LRAir`, `PJumpSnd`, `ProcessPlayerAction`, `ActionFalling`.

## Uncrouching inside terrain and push-out

There is no stand-up clearance test. Once grounded Down is released, standing probes and the standing object-contact box are selected in the normal update. The source does not find a nearest free position or force Mario to remain crouched.

`DoPlayerSideCheck` samples the left side first, then the right. For a blocking sample, `ImpedePlayerMove` clears the appropriate movement bit. If Mario is stationary or moving into that obstruction, it zeros horizontal speed, sets SideCollisionTimer to $10, and nudges the origin one pixel away: right for a left-side obstruction, left for a right-side obstruction. Movement already directed away from that side follows the branch that restricts input without applying that correction. Later samples use the updated position. Direction depends on encountered probes and velocity, not a universal facing-direction or nearest-exit rule.

Deduction: uncrouching can put the upper side probes into terrain and cause successive horizontal nudges. The head may overlap without a bonk if not rising. A single tile, both-sided enclosure, partial top overlap, corners, and movement into/away from the obstruction can produce different results. Do not promise that every overlap resolves immediately or to the geometrically nearest opening.

Metatiles matter: hidden blocks are ignored for side blocking; coins are collectible; climbable tiles and springs have their own branches. Sideways pipe upper tiles are specially skipped in the upper-side pass, while the lower pipe tile can start transport. Treating every overlap as a generic solid-box recovery would erase these distinctions.

Evidence: `DoPlayerSideCheck`, `SideCheckLoop`, `CheckSideMTiles`, `ChkInvisibleMTiles`, `StopPlayerMove`, `ImpedePlayerMove`.

## Pipes and posture

Vertical entry is tested from the landing/foot path: Down must survive input filtering, and the left/right foot samples must contain the matching enterable pipe-cap metatiles ($10/$11). The routine has no small/big eligibility branch and no instruction that forces a large player to stand. Entry moves down one pixel per update, using ChangeAreaTimer=$30 (48 counts); it does not run the ordinary movement/crouch sampler each entry update.

Side entry checks grounded state, facing right, and the lower sideways-pipe metatile ($6c or $1f), with special treatment of upper tiles ($1c/$6b). It is not an ordinary overlap plus a generic headroom test. EnterSidePipe sets horizontal speed $08 (0.5 px/frame), runs auto-controlled right movement, and uses grid alignment/area-change timing. Auto-controlled movement can re-sample posture; do not assume the vertical-entry crouch policy also applies to side entry.

Vertical emergence moves the reference origin upward one pixel per update and uses the authored Y threshold $91. This is a reference-specific placement convention, not a universal feet-relative threshold to copy into arbitrary Godot pipe scenes. The exact carried/reset crouch flag across area initialization, first controllable frame, and each entry/exit direction still needs a traced emulator observation.

Current project considerations: PipeEntrance already uses feet alignment and rejects horizontal input for vertical entry. PlayerPipeEnterState owns scripted transport and suspended body collision, computes vertical hidden depth from sprite geometry, and contains a fixed side hidden-depth value (14). Super artwork, pose selection, side occlusion, and restoration all need explicit verification before adapting these paths. No new pipe architecture is approved by this research.

Evidence: `HandlePipeEntry`, `PipeDwnS`, `EnterSidePipe`, `VerticalPipeEntry`, `PlayerEntrance`/`EntrMode2`; project pipe_entrance.gd and pipe_enter_state.gd.

## Growth, shrinking, and obstruction

PlayerStatus (small/super/fire) and PlayerSize (big=0/small=1) are separate. Mushroom/flower collection awards the normal pickup reward then selects a transformation path; there is no free-headroom query. The shared 32-pixel sprite-canvas baseline is retained rather than translating Mario upward solely to grow.

Growth enters game routine $09 with TimerControl=$ff. At $f8, InitChangeSize toggles PlayerSize, starts the size-change graphic sequence, and resets its animation control. At $c4, the growth routine completes. HandleChangeSize advances on global frame multiples of four using ChangeSizeOffsetAdder; ten animation steps alternate small/intermediate/big poses. The exact first-step phase is not a universal fixed duration. The size toggle changes future collision selection; the routine is not a safe-fit expansion algorithm.

Damage checks status: Small Mario dies; both Super and Fire are set to Small status. ForceInjury loads InjuryTimer=$08 and game routine $0a, sets jumping state, and starts TimerControl=$ff. At $f0, PlayerInjuryBlink falls through ExitBlink into InitChangeSize (the nearby comment calls the branch unconditional, but its equality fall-through is significant). Later updates can run PlayerCtrlRoutine; $c8 finishes the injury routine. The graphics shrink sequence is distinct from growth. InjuryTimer is an interval timer at $079e, and flashing uses global frame parity. Do not quote a simple 8-frame protection duration or invent a fixed modern knockback from this code.

The transformation routines do not perform an immediate nearest-clear-space correction. Growth beneath a ceiling changes the eventual probes/box; ordinary collision processing then governs obstruction once it runs. Exactly when push-out first appears relative to the visual transformation, and whether particular head/side overlaps react differently, remains a Mesen check.

Evidence: `HandlePowerUpCollision`, `Shroom_Flower_PUp`, `UpToSuper`, `SetPRout`, `ForceInjury`, `PlayerChangeSize`, `PlayerInjuryBlink`, `InitChangeSize`, `HandleChangeSize`, `ShrinkPlayer`, `DecTimers`, `PlayerGfxHandler`.

## Proposed next implementation boundary

Proposal only: retain one Mario actor and shared movement state machine. Define form/posture data separately from terrain sampling and object-contact profiles. Implement feet-anchored artwork and enemy boxes, then reproduce the verified crouch/input/airborne rules and terrain probe behavior. An equivalent Godot rectangle alone is insufficient evidence of fidelity. Existing CornerCorrectionComponent only handles rising head escape and falling landing assistance; it does not implement standing overlap push-out. Growth, damage, and pipe presentations should use these verified profiles through existing owners rather than live in a new independent player implementation.

## Required emulator scenarios and unresolved measurements

1. Hold/release Down at rest and with left/right momentum; test Down+Left/Right together and on adjacent frames, both facings.
2. Crouch-jump, release Down while rising/descending, press Down after a standing jump, and compare crouched walk-off artwork and collision.
3. Uncrouch beneath a single low tile, multiple tiles, both-sided enclosure, and near each edge; record per-frame X/Y, velocity, first blocked probe, and any bonk. Repeat with solid ground, bricks, question blocks, and pipe geometry.
4. Collect a mushroom while grounded, jumping, crouched if reachable, and under one-tile clearance. Record PlayerStatus, PlayerSize, CrouchingFlag, TimerControl, animation index, and when terrain collision next runs.
5. Damage Super/Fire while standing/crouching/airborne and under ceilings; observe size timing, displacement, shrink frames, flashing, and interval-timer expiry.
6. Enter and emerge from vertical and sideways pipes as Super, holding/releasing Down and horizontal input. Record area-init posture, feet placement, sprite occlusion, first controllable frame, and persistence of form.
7. Compare visible sprite top/bottom and exact edge contacts against debugger boxes. The coordinate spans above are verified; opaque art pixels, OAM scanline offset, inclusive NES collision edges, and Godot's continuous-shape equivalence are not yet qualified.

No gameplay regressions were run: this change only records research. Validation checked probe/bounding-box values against the assembly, documentation diff integrity, and preserved the gameplay/settings/AGENTS files. No project settings, import options, scene configuration, or audio were changed.


## Complete player collision inventory - 2026-11-07

Scope: all three player terrain-probe groups and all three player object-contact box profiles in the reference. This does not claim that every enemy, projectile, platform, or metatile in the engine has been qualified. Fire shares the big profiles. Swimming probes are recorded for completeness, not a proposal to add swimming now.

Every coordinate below is an offset, not a radius or ray length. NES offsets are added to Player_X/Y_Position before looking up the containing 16x16 metatile. The project offsets subtract the shared canvas center/feet offset (8,32). There are seven table entries per profile, including deliberately duplicated short-profile side probes.

| Profile | Table index | Probe | NES offset | Feet-centered offset |
| --- | --- | --- | --- | --- |
| Super/Fire standing, land | 0 | Head | (8,4) | (0,-28) |
| Super/Fire standing, land | 1 | Left foot | (3,32) | (-5,0) |
| Super/Fire standing, land | 2 | Right foot | (12,32) | (4,0) |
| Super/Fire standing, land | 3 | Left upper side | (2,8) | (-6,-24) |
| Super/Fire standing, land | 4 | Left lower side | (2,24) | (-6,-8) |
| Super/Fire standing, land | 5 | Right upper side | (13,8) | (5,-24) |
| Super/Fire standing, land | 6 | Right lower side | (13,24) | (5,-8) |
| Super/Fire standing, swimming | 7 | Head | (8,2) | (0,-30) |
| Super/Fire standing, swimming | 8 | Left foot | (3,32) | (-5,0) |
| Super/Fire standing, swimming | 9 | Right foot | (12,32) | (4,0) |
| Super/Fire standing, swimming | 10 | Left upper side | (2,8) | (-6,-24) |
| Super/Fire standing, swimming | 11 | Left lower side | (2,24) | (-6,-8) |
| Super/Fire standing, swimming | 12 | Right upper side | (13,8) | (5,-24) |
| Super/Fire standing, swimming | 13 | Right lower side | (13,24) | (5,-8) |
| Small or big crouching | 14 | Head | (8,18) | (0,-14) |
| Small or big crouching | 15 | Left foot | (3,32) | (-5,0) |
| Small or big crouching | 16 | Right foot | (12,32) | (4,0) |
| Small or big crouching | 17 | Left upper side | (2,24) | (-6,-8) |
| Small or big crouching | 18 | Left lower side | (2,24) | (-6,-8) |
| Small or big crouching | 19 | Right upper side | (13,24) | (5,-8) |
| Small or big crouching | 20 | Right lower side | (13,24) | (5,-8) |

### Contact-box shape and placement

| Profile | Box control | Size (coordinate span) | Feet-centered shape center | NES min/max |
| --- | --- | --- | --- | --- |
| Super/Fire standing | 0 | 12x24 | (0,-12) | (2,8)-(14,32) |
| Small | 1 | 10x12 | (0,-6) | (3,20)-(13,32) |
| Super/Fire crouching | 2 | 12x12 | (0,-6) | (2,20)-(14,32) |

`SprObjectCollisionCore` explicitly accepts equality at box edges in its normal non-wrapping comparisons. Consequently the spans above must not be described as counts of discrete occupied pixels (for example, endpoints 2 and 14 span 12 coordinate units). Godot Area2D contact at exact touching boundaries still requires testing; enlarging every shape by one pixel without comparison would be an invented correction. The wrap/offscreen branches are separate from the normal on-screen case.

### Terrain and contact processing order

1. Sample/filter input and update grounded crouch; airborne crouch is retained.
2. Integrate shared movement, then select the object-contact box from size/posture and derive current coordinates.
3. Terrain checks run head, feet, then sides. Feet are sampled left then right. Side entries are left-upper, left-lower, right-upper, right-lower, with metatile-dependent early exits.
4. Successful landing snaps the NES origin's low Y nibble to zero, tests vertical-pipe entry, clears vertical speed/fractional force and stomp count, then sets grounded state. The normal landing branch requires original low Y nibble <5; deeper foot penetration can instead invoke ImpedePlayerMove.
5. Side collision can zero horizontal speed and nudge X by one pixel, in sampled order. This is not a full-shape depenetration or nearest-space search. Follow the velocity checks described above.

Collision gates to retain in an implementation specification: collision-disable/engine-routine checks; high Y page must be 1; ordinary player terrain checking returns at origin Y >=$cf; head extent differs by size/posture and requires upward velocity plus low Y nibble >=4 for a bonk; side upper/lower screen bounds differ; hidden/coin/climbable/pipe/spring metatiles use their own handling. These gates should not be replaced silently by one generic shape-overlap rule.

### Existing project geometry versus reference targets

| Part | Current Small Mario | Super/Fire target or status |
| --- | --- | --- |
| Terrain CharacterBody2D shape | 11x14; center (-0.5,-7), feet at Body Y=0 | No final rectangle approved: reference probes above are authoritative |
| EnemyHurtbox Area2D | 10x12; center (0,-6), layer 1024, mask 0 | Standing 12x24 at (0,-12); crouched 12x12 at (0,-6), subject to edge tests |
| Visible sprite placement | Sprite2D position (0,-7), current cropped Small artwork | Derive from each supplied frame's canvas/transparent padding; preserve feet, do not stretch Small art |
| Normal head/hidden-block attack | BonkAction center-head ray based on terrain shape; hidden underside crossing probe | Must follow the chosen standing/crouched head profile |
| Terrain corrections | CornerCorrectionComponent rising head escape and falling landing assistance | Standing overlap push-out not yet implemented |
| Pipe alignment | PipeEntrance uses Body feet; transport temporarily disables body collision | Verify posture-specific art, hidden depth, side alignment, and restoration |
| Enemy contact classification | BaseEnemy samples overlap every other physics tick and classifies stomp/damage | Must consume the selected hurtbox without making Mario-specific form rules enemy-owned |

The unconfigured generic BasePlayer scene has a 16x16 placeholder body; the concrete Small Mario overrides it with 11x14. Do not mistake that placeholder for the shipped Small dimensions. No Super terrain shape, runtime posture node, or form resource has been created by this research.

## Proposed player scene and form ownership

Current implementation: `scenes/player/mario (small)/mario.tscn` inherits BasePlayer and uses the `Mario` script, Mario movement states, motion/action components, and presentation nodes. Super is not a separate implemented player. New Super artwork is user-supplied input, not proof that a Super actor or form system exists.

Recommended design, still proposed: one active Mario scene and actor instance, with Small, Super, and eventually Fire as configurations of that actor. Keep one Body, EnemyHurtbox, state machine, controller connection, camera target, level player reference, and transport/presentation interface. Growing or shrinking changes configuration and runs a presentation; it does not free Mario and instantiate a replacement player scene.

| Owner | Proposed responsibility |
| --- | --- |
| BasePlayer/shared motion | Generic body movement, collision-profile application hooks, feet anchor, and existing player lifecycle interfaces |
| Mario-specific form controller/data | Small/Super/Fire identity, animation sets, standing/crouched profiles, jump cue and form capabilities; future damage/form change requests |
| Mario posture handling | Crouch flag, reference grounded sampling/airborne preservation, filtered input, profile and pose selection |
| Shared Mario movement states | Reused Idle/Move/Jump/Slide/Climb mechanics; consume selected profiles and animation identifiers without duplicated Super copies |
| Terrain handling | Verified head/foot/side probes, bonk delivery, landing and obstruction correction |
| Pipe and level presentation owners | Entry/exit/flagpole operations through existing generic player interfaces, with current form/posture presentation |
| Future star-effect component | Temporary invincibility independent of Small/Super/Fire; not part of this implementation phase |

A data Resource (.tres) is suitable for reusable form configuration: it stores artwork/animation mappings and profile values without creating another actor. Exact resource names, fields, and scene reorganization are for the next implementation discussion. The existing folder name `mario (small)` need not imply separate player classes for every size; renaming/consolidating its scene is a future scoped change, not performed here.

Crouch is orthogonal to form and can persist through a jump. Therefore a ground-only Crouch state must not be the sole owner of short collision or crouch flags. We may add a grounded Crouch movement state if its action logic needs one, while a Mario posture component remains authoritative across movement transitions. That is a design option, not an implemented state. A second complete Super state-machine copy is not recommended.

Verification for this inventory: generated all 21 player terrain table entries directly from the assembly and checked all three player contact controls. Read the normal edge-equality collision branches and compared current scene geometry and controller/movement/bonk/pipe paths. Godot rectangle equivalence, rendered art alignment, and the emulator matrix remain outstanding. No gameplay tests were run for this documentation-only change.


## Artwork inspection follow-up

The supplied Super sheets are mapped in [Super Mario artwork inventory](super-mario-artwork.md), including exact frame regions, alpha padding, feet alignment relative to current Small Mario, theme availability, and missing growth/shrink poses. This is asset inspection only; no form controller, Super player scene, import settings, or animation wiring has been implemented.

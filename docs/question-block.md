# Question block

QuestionBlock inherits BaseBlock's solid 16x16 body, top-left origin, presentation bounce component, and terminal shutdown. Its existing state machine owns three states:

- Active plays the looping question animation and accepts an upward `bonk` hit.
- Bouncing rejects further hits, stops the loop, selects question-block-4.png, and begins the sprite bounce on entry. On completion it transitions to Inactive.
- Inactive keeps the used sprite and rejects hits, with frame, physics, and input updates disabled.

There are no items, coins, score rewards, persistence, or brick-breaking rules yet. Reloading the level creates fresh active blocks. The solid body stays fixed throughout the visual bounce.

## Hit delivery and reuse

EntityHit is a short-lived RefCounted message containing attacker, maneuver, direction, and strength. BaseBlock.receive_hit forwards it to the current EntityState; the default state implementation rejects it. ActiveBlockState accepts its configured maneuver only when direction points upward, then transitions to its exported reaction_state. BouncingBlockState inherits the default rejection and owns bounce startup, advancement, and cleanup. Inactive uses the default EntityState with presentation settings only. Neither state queries player input or requires Mario specifically.

BasePlayer owns Actions/Bonk, disabled by default; Mario enables it. During a rising ceiling collision, after corner correction and move_and_slide, Bonk first probes upward at the player's center-head X, using the reference BlockBufferColli_Head / BlockBuffer_X_Adder (+8 from sprite-left) selection principle. The tile directly above that probe wins, independently of which slide contacts Godot reports. An exact seam belongs to the right-hand tile. A used block or solid terrain under the probe prevents redirecting the hit to a neighboring active block. If the probe finds no solid, Bonk falls back to actual ceiling-contact blocks, choosing the nearest center with a right-hand tie break; this preserves partial edge hits and is a deliberate adaptation rather than exact NES behavior. Side-only touches and corners cleared by correction do not activate blocks. Bonk sends one hit per collision evaluation. Inactive rejects repeated delivery. The existing player ceiling response owns the bump sound, so the block does not play a duplicate.

Other players can enable/configure Bonk or supply another action that sends EntityHit. Other blocks can reuse the two scripts under scripts/states/blocks, assign their presentation in the Inspector, and link Active's reaction_state. BaseBlock's machine remains empty unless a concrete scene supplies states. Bricks reuse these scripts with Active -> Bouncing -> Active: Bouncing sets return_state to Active, while question-block Bouncing sets return_state to Inactive.

## Presentation and reference

Active uses AnimationPlayer with animations/active.tres. The palette cycle is bright/medium/dark/medium for 24/8/8/8 nominal 60-Hz frames, or 0.8 seconds total. Textures question-block.png through question-block-4.png live under assets/Overworld (Palette 1)/interactibles/blocks/. The fourth texture is the used appearance, not a fourth loop frame.

The [reference disassembly](https://gist.github.com/1wErt3r/4048722) supplies ColorRotatePalette's palette phases, BumpBlock's initial Y speed of -2 pixels/frame, and ImposeGravityBlock's force of $50/256 pixels/frame squared. BlockBounce converts the latter two at nominal 60 Hz to initial_speed=-120 pixels/second and gravity=1125 pixels/second squared. It advances the sprite offset and restores its starting position on return or state exit/shutdown. These values are editable on BaseBlock/Presentation/Bounce.

This is a continuous-value visual approximation. The original temporarily blanks its collision metatile and uses a moving block object before replacing the metatile; this project deliberately keeps the static collider. Original fixed-point rounding, metatile update timing, global block slots/timers, interactions above the block, and item-specific behavior are not reproduced. The used texture appears immediately on Bouncing entry and remains in Inactive.

## Reaction events

Bouncing inherits BaseState.entered and exited signals plus Enter Sound Effect and animation presentation settings. Connect entered for a one-time reaction at bounce entry (future item spawning, particles, or other behavior). Its bounce_completed signal fires once on natural completion, before transition to return_state. Shutdown/interruption restores the sprite through exit without emitting bounce_completed; exited alone does not mean successful completion. No item spawning or additional SFX is connected yet; Mario still owns the existing bump sound.

## Editing and verification

Paint question markers in TestLevel/Areas/MainArea/Layouts/EntityLayout using source 1, entity_id question_block. The level's Entity Scenes dictionary maps this ID to QuestionBlock. Existing painted cells are preserved; tests create independent fixtures.

question_block_test verifies palette timings and loop wrap, real Mario jump-to-block activation, invalid-hit rejection, ordered Active -> Bouncing -> Inactive transitions, entry/completion event counts, one-time activation, used appearance, sprite bounce with fixed collision, independence of neighboring blocks, and cleanup during a bounce. Headless checks do not replace visual/audio playtesting.

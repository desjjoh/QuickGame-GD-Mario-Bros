# Question block

QuestionBlock inherits BaseBlock's solid 16x16 body, top-left origin, presentation bounce component, and terminal shutdown. Its existing state machine owns three states:

- Active samples the shared cosmetic animation clock and accepts an upward `bonk` hit.
- Bouncing rejects further hits, stops the loop, selects question-block-4.png, and begins the sprite bounce on entry. On completion it transitions to Inactive.
- Inactive keeps the used sprite and rejects hits, with frame, physics, and input updates disabled.

Question blocks contain one coin by default. Brick-breaking rules remain future work. Area progress is preserved in GameHandler: returning to an area or replacing the same named level within the session restores used question blocks. A fresh session starts from the authored layout. The solid body stays fixed throughout the visual bounce.

## Hit delivery and reuse

EntityHit is a short-lived RefCounted message containing attacker, maneuver, direction, and strength. BaseBlock.receive_hit forwards it to the current EntityState; the default state implementation rejects it. ActiveBlockState accepts its configured maneuver only when direction points upward, then transitions to its exported reaction_state. BouncingBlockState inherits the default rejection and owns bounce startup, advancement, and cleanup. Inactive uses the default EntityState with presentation settings only. Neither state queries player input or requires Mario specifically.

BasePlayer owns Actions/Bonk, disabled by default; Mario enables it. During a rising ceiling collision, after corner correction and move_and_slide, Bonk first probes upward at the player's center-head X, using the reference BlockBufferColli_Head / BlockBuffer_X_Adder (+8 from sprite-left) selection principle. The tile directly above that probe wins, independently of which slide contacts Godot reports. An exact seam belongs to the right-hand tile. A used block or solid terrain under the probe prevents redirecting the hit to a neighboring active block. If the probe finds no solid, Bonk falls back to actual ceiling-contact blocks, choosing the nearest center with a right-hand tie break; this preserves partial edge hits and is a deliberate adaptation rather than exact NES behavior. Side-only touches and corners cleared by correction do not activate blocks. Bonk sends one hit per collision evaluation. Inactive rejects repeated delivery. The existing player ceiling response owns the bump sound, so the block does not play a duplicate.

Other players can enable/configure Bonk or supply another action that sends EntityHit. Other blocks can reuse the two scripts under scripts/states/blocks, assign their presentation in the Inspector, and link Active's reaction_state. BaseBlock's machine remains empty unless a concrete scene supplies states. Bricks reuse these scripts with Active -> Bouncing -> Active: Bouncing sets return_state to Active, while question-block Bouncing sets return_state to Inactive.

## Presentation and reference

Active enables Presentation/PaletteAnimation, which samples the [shared clock](animation-clock.md) through the existing AnimationPlayer and animations/active.tres. Native playback is paused; joining an area immediately selects the global phase. State exit disables synchronization before the reaction takes control. The palette cycle is bright/medium/dark/medium for 24/8/8/8 nominal 60-Hz frames, or 0.8 seconds total. Textures question-block.png through question-block-4.png live under assets/palettes/overworld/interactibles/blocks/. The fourth texture is the used appearance, not a fourth loop frame.

The [reference disassembly](https://gist.github.com/1wErt3r/4048722) supplies ColorRotatePalette's palette phases, BumpBlock's initial Y speed of -2 pixels/frame, and ImposeGravityBlock's force of $50/256 pixels/frame squared. BlockBounce converts the latter two at nominal 60 Hz to initial_speed=-120 pixels/second and gravity=1125 pixels/second squared. It advances the sprite offset and restores its starting position on return or state exit/shutdown. These values are editable on BaseBlock/Presentation/Bounce.

This is a continuous-value visual approximation. The original temporarily blanks its collision metatile and uses a moving block object before replacing the metatile; this project deliberately keeps the static collider. Original fixed-point rounding, metatile update timing, global block slots/timers, interactions above the block, and additional item types are outside the current implementation. The used texture appears immediately on Bouncing entry and remains in Inactive.

## Reaction events

Bouncing inherits BaseState.entered and exited signals plus Enter Sound Effect and animation presentation settings. QuestionBlock connects entered for its one-time reward on bounce entry. Its bounce_completed signal fires once on natural completion, before transition to return_state. Shutdown/interruption restores the sprite through exit without emitting bounce_completed; exited alone does not mean successful completion. QuestionBlock calls GameHandler.award_coin() to grant one coin and 200 points and play the existing shared reward cue. Mario still owns the bump sound. The area owns a transient sprite using the four frames in assets/items/block-coin.png. After its rise and fall it shows the existing 200 score sprite, then frees both visuals. It has no pickup collision because the coin is granted at launch. The motion approximates CoinBlock and ProcJumpCoin with a launch of -300 px/s, gravity of 1125 px/s², and a transition to the popup at +300 px/s. Sprite frames advance every two nominal NES frames and the popup floats for about 46 frames. Pixel rounding and global animation phase differ from the disassembly. Mesen frame and audio comparisons remain open. See the [reference mirror](https://gist.github.com/bitemyapp/d2007143221e4f01186949dc37677507).

## Editing and verification

Paint question markers in 1-1/Areas/MainArea/Layouts/EntityLayout using source 1, entity_id question_block. The level's Entity Scenes dictionary maps this ID to QuestionBlock. Existing painted cells are preserved; tests create independent fixtures.

question_block_test verifies palette timings and loop wrap, real Mario jump-to-block activation, invalid-hit rejection, ordered Active -> Bouncing -> Inactive transitions, entry/completion event counts, one-time activation, used appearance, sprite bounce with fixed collision, independence of neighboring blocks, and cleanup during a bounce. Headless checks do not replace visual/audio playtesting.

Area unload during Bouncing saves its logical Inactive result. Restoration selects Inactive before startup, so entry bounce/events are not replayed. See [area lifecycle](areas.md).

## Hidden question blocks

Paint Hidden Question Block on EntityLayout. The unused outline is visible in the editor and in-game for this pass. Mario passes through from the side and above. A rising center-head crossing at the underside triggers the existing bonk response and reward. The block then becomes solid and uses the normal used sprite. The same reward brush applies to both question-block stamps.

## Static reward bricks - 2026-11-07

Reward Brick and Reward Brick Alt inherit question_block.tscn. Their Active state overrides the sprite texture to brick.tres or brick-alternate.tres and clears synchronized_animation, keeping the starter artwork static. Bouncing and Inactive retain the shared used-block presentation. Both variants default to one coin and accept the existing Coin/1-Up reward painting and always-visible translucent overlays. Markers use source IDs 12 and 13 in each themed EntityLayout. Ordinary Brick and Alternate Brick remain separate. Timed Coins uses the same painting workflow; see [timed coin rewards](timed-coins.md).

The standalone 1-Up spawner marker was removed from EntityLayout; no replacement power-up painting layer is included. The internal spawner scene and 1-Up block reward remain available. Deferred standalone power-up authoring is separate from these reward-brick variants.

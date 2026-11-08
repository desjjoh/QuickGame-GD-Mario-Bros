# Super Mushroom

Implementation completed 2026-11-08. Super Mushroom reuses the existing mushroom emergence, walking/falling, wall reversal, block-hit response, pickup, spawn-category limit, and offscreen cleanup. It gives 1,000 points, a 1000 popup, and the power-up grab cue; Small Mario grows on the same live actor.

## Scene and collection ownership

The common `scenes/entities/powerups/mushroom.tscn` contains the existing 14×16 terrain shape, 12×12 pickup shape at (0,−1), body/sprite arrangement, and BlockHitReceiver. OneUpMushroom and SuperMushroom inherit this scene and supply their scripts/artwork. Both scripts inherit Mushroom, which inherits PowerUp and SpawnableEntity. No new movement or cleanup implementation was introduced.

PowerUp identifies the actual collecting BasePlayer rather than consulting a global current-player reference. It sets its removal latch before calling `_begin_collection(player)`; rejection releases the latch without reporting consumption or granting a reward. Super Mushroom accepts Mario only: Small must successfully start growth, and already-Super collects without another transformation. Successful collection reports consumption, grants the reward once, and frees the item. Duplicate signal/poll callbacks cannot award it again.

Available power-ups poll existing pickup overlaps as well as listening to entry signals. This handles a contact that began while gameplay was suspended or a form presentation rejected collection, without requiring Mario to leave and enter again. It does not defer a spawner attempt or change spawn limits. The inherited emergence path still disables pickup until the mushroom clears the block; the previously documented early-emergence NES pickup difference remains unchanged.

The 1000 popup uses the existing popup scene and its position/interpolation initialization under the item's world-space parent, then the existing 24-pixel/0.8-second rise pattern. Collection changes score through GameHandler, without adding a life or coin. A Small collector invokes `Mario.grow()`; the existing form presentation owns world suspension, live profile timing, session form, pause, and cancellation.

## Authoring

The existing Block Rewards add-on adds **Apply Super Mushroom Reward**. Select EntityLayout, choose that brush, and click any supported painted reward block. The editor stores the existing `BlockReward.Kind.POWER_UP` with `super_mushroom.tscn`; it uses the same undo/redo and sparse per-cell storage as 1-Up rewards. A translucent red-mushroom preview is drawn on the block continuously. The four supported variants are question block, hidden question block, reward brick, and alternate reward brick.

Coin remains the default, and previous 1-Up/timed-coin IDs and saved assignments are retained. This is an explicit Super Mushroom reward, not a tiered mushroom/flower reward. No standalone mushroom marker, physics-object painter, or new project setting was added. No stage placements were changed. The supplied `assets/items/red-mushroom.png` is used through the existing theme-resolution path; no new palette variants were generated.

## Reward and deliberate reference difference

The user answered “always 1,000 pts” when asked about collecting a mushroom while already Super, in the context of keeping Super until Fire is implemented. Both forms therefore receive 1,000 points. Small grows, while Super retains its form. This is a temporary, approved difference: the NES's shared mushroom/flower collection branch upgrades an already-Super collector to Fire even for an already-released mushroom. Fire and automatic block tier selection remain future work.

`SoundHandler.power_up_grab` is synthesized from the disassembly's `PowerUpGrabFreqData`, read backward as the length counter descends: 27 frequency entries, two nominal 60 Hz frames each, Square 2 control `$5d`, sweep `$7f`. It uses the existing pulse renderer and reward voice, including the existing protected 1-Up priority. No playback gain, pitch scaling, positional audio, or existing cue amplitude was changed. Synthesis follows the source registers; this pass did not perform an audible Mesen comparison.

## Verification

The focused Super Mushroom regression checks release from all four block variants, pickup disabled during emergence, final release height, real Area2D pickup, Small growth on the same actor, 1,000 points for either form, popup position/region, cue and default gain/pitch, pickup after suspended overlap, inherited walking/falling, cleanup, and released spawn capacity. The grab stream is checked for its source-derived 54-frame duration.

Initial focused runs exposed two fixtures depending on editable sandbox defaults: the damage test assumed a Super start, and the 1-Up movement test assumed a wall. Tests now provide those forms/terrain explicitly without modifying the sandbox scene. After the shared-overlap change and fixture corrections, `super_mushroom_test`, `one_up_test`, and `mario_damage_test` passed without engine errors or warnings. The earlier focused run also passed `question_block_test`, `reward_brick_test`, `score_popup_test`, and `sound_mix_test`. The full suite and rendered editor painting/manual audio comparison were not run. The editor imported the updated add-on and new scene class without parse errors.

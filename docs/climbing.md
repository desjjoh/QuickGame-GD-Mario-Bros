# Climbable entities and flagpole

## Ownership

BaseClimbable inherits BaseEntity. It provides an Area2D, ClimbTop/ClimbBottom markers, a narrow shaft capture band, and player_attached/player_detached signals. These signals identify accepted climbing attachments, not every overlapping physics tick. Later completion code can listen to player_attached; the configured level presentation subscribes to this signal and claims completion. The entity itself does not advance stages.

The surface does not subscribe to ControllerHandler and disables its own frame/physics callbacks. Overlap signals register weak candidate references on the player's Motion/Climbing component. BasePlayer checks generic climbables before movement and sweeps actual body displacement afterwards. Flagpoles sample the final position after movement; a physics-area query fills gaps before overlap notifications arrive. The query uses scene collision layer 8 (bit 128), not a new solid collision surface. Only body movement that actually occurred is tested, so walking into a wall before the pole does not grab through it. Only a live player in a control-enabled PlayerState can attach. Dead, transported, title-frozen and suspended players cannot grab. Candidates from removed/unloaded entities are discarded.

ClimbingComponent owns attachment position, nominal speed values and side-switch timing. PlayerClimbState is reusable script behavior under scripts/states/player; Mario owns a concrete MarioClimbState node, its Move return reference, and climb animation resource. BasePlayer has no concrete Mario state nodes.

## Painting the fixed flagpole

Select Areas/MainArea/Layouts/EntityLayout in 1-1, then choose **Flagpole (2x11)** in the TileSet source palette. Paint once to place the complete entity and save before F5. Source ID 5 carries entity_id=flagpole. The marker uses the existing 16x16 grid; its top-left cell anchors a 32x176 preview/assembly. The pole and solid base occupy the right column; the flag extends left. Place the bottom row at the intended base location and allow ten tile rows above it.

For example, a marker at cell (6,2) puts the shaft center at X=120 and the solid block at (112,192), with its bottom at Y=208. No example was painted into the authored stage. The climbing regression creates its own layout.

Flagpole inherits BaseClimbable and contains one top tile, nine shaft tiles, one flag sprite and one normal StaticBody2D base. The base uses assets/palettes/overworld/tileset/block.png; the shaft is non-solid. The scene's markers and detection geometry define the climb limits. Height is fixed for this milestone; per-instance height generation is deferred.

BaseLevel's default Entity Scenes mapping includes flagpole, as do the existing 1-1/TestLevel overrides. Both entity TileSets expose the same marker ID. Only Overworld flag art currently exists: other themes retain that art while the base block follows the area's existing texture remapping. No underground flag art is fabricated. scripts/build_flagpole_marker.gd regenerates the full paint preview from source textures; imported textures are used by the runtime entity.

## Capture geometry

Attachment Tolerance is now the half-width of the shaft band (2 pixels by default), rather than the old 8-pixel distance from Mario's feet. Generic climbables use the transformed collision-body envelope against that thin shaft. FlagpoleEntity uses the reference small-Mario side probe (feet minus eight pixels, editable on Motion/Climbing) and horizontal capture bands relative to the shaft: [-10,-6) and [6,10) pixels at the player feet origin. These translate the reference player-X low-nibble acceptance of $06 through $09 into our centered body coordinates; final side placement remains seven pixels from the shaft. The left approach captures three pixels earlier than the former body-envelope approximation. It is independent of sprite transparency. The final side-probe sample must lie within a grab band. Attachment snaps Mario sideways and preserves the accepted Y, including low contacts below the base top.

This specifically covers walking/running across the shaft while standing on the base block and contact during the landing tick. The wider Area2D is candidate discovery only; it does not cause attachment by itself. Walking beside the base on the lower floor still does not count as shaft contact. The side-probe geometry uses Godot world coordinates and floating-point movement.

## Controls and reference behavior

Touch the narrow capture region to grab automatically. Horizontal momentum is cleared and Mario aligns to a side of the shaft. Up/Down climb; neutral input hangs without gravity. Horizontal input can switch sides and keeps Mario facing inward; neither direction manually releases the attachment. Side switching retains its 24-tick timer, and neutral horizontal input clears it. A held direction is consumed until released or changed so it does not repeatedly swap sides. Solid terrain prevents a side switch through a wall.

The supplied disassembly's Climb_Y_SpeedData/Climb_Y_MForceData give nominal movement of -0.875 pixels/tick upward and +1.99609375 downward: 52.5 and 119.765625 pixels/second at 60 ticks. The component exposes these values plus a seven-pixel side offset and 24-tick switch interval. These are floating-point equivalents, not byte-for-byte NES fixed-point positioning or exact side collision probes.

Mario's two supplied climb textures form a two-frame loop: eight ticks per pose upward, four downward. Neutral/blocked climbing always returns to the first climbing pose, including when stopped at either bound. Side placement still resets interpolation without changing states. Run and Jump do not start ordinary run/jump actions while attached, matching the reference's separate climbing branch. At the top, climbing clamps; automatic vine area transport is deferred. The bottom bound stops downward travel and keeps Mario attached in Climb with a stopped pose. Up can resume manual climbing. Only an explicit state change or loss of the surface releases the attachment; after an explicit release, the same surface cannot immediately recapture him until he leaves its detection region.

The configured 1-1 pole now uses [the flagpole ending presentation](flagpole-ending.md): controlled descent, moving flag, dismount, walk and audio. Other/unconfigured poles remain manually climbable for testing. Score/firework effects and actual vines remain deferred.

## Upper-limit reference findings

The reference flagpole accepts both its ball and shaft as climbing metatiles, then enters forced descent. It does not provide a player-controlled climb to the ball or a stand-on-top phase. An unconfigured manual flagpole remains a test behavior: its authored top clamps movement and retains attachment, rather than inventing a top dismount.

A transport vine is different. VineCollision starts Vine_AutoClimb when the reference player Y is below $20 near the HUD. The game then forces Up until Mario has climbed above the screen (high page zero and low Y below $e4), and switches areas with the vine entrance mode. These are NES screen-coordinate thresholds, not direct values for our feet-based world coordinates. Ordinary climbing is also maintained by contact probes, rather than an unconditional finite-vine top clamp. Actual vines and their surface-end/transport policies are not implemented yet; their behavior must remain separate from flagpole bounds.

## Lifecycle and verification

Exiting Climb clears its attachment, zeros residual climb velocity and restores animation speed. Explicit-release suppression ends when the actual body leaves the detection region, even if overlap signals missed the brief contact. Death and transport stop the state through existing lifecycle handling. Removing/disabling a surface returns Mario to normal Move/passive falling on his next active tick. Area activity and entity shutdown retain their existing ownership; there is no global climbable polling loop.

climbing_test paints one marker in an isolated fixture and checks automatic attachment, signals, nominal speeds, held input restrictions, side-switch cooldown, top/bottom bounds, no immediate regrab, solid base landing, animation, suspension, removal, area travel and presented death cleanup. See [verification](verification.md) for executed checks.

Reference: [SMB disassembly](https://gist.github.com/1wErt3r/4048722), especially HandleClimbing, PutPlayerOnVine, PlayerPhysicsSub, ClimbingSub and ActionClimbing.

climb_capture_test separately checks 28 real-tick walk/run contacts from both directions at top/middle/base/landing-edge heights, standing on the base, rejection of crossings whose final position is outside the shaft, wall occlusion and below-shaft rejection.

## Upper ball grabs

The flagpole captures over the full ball metatile beginning at its top edge. Its Detection region now covers that tile, and its feet-based ClimbTop is eight pixels below the tile origin rather than 24. For a pole beginning at Y=32, the highest valid small-Mario feet position is Y=40. A grab there remains at Y=40 rather than being pulled down to the former Y=56 limit, including when the ending state takes over. Side-probe contact above the ball is rejected. Neither the sprite art nor jump acceleration, velocity or gravity was changed. A real running-jump fixture from a raised step verifies a ball grab above the previous clamp; base/landing and final-position tests remain in place.

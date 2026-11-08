# Mario form configuration

Date: 2026-11-07. Implemented first pass: startup artwork/contact configuration, not complete Super gameplay.

## Ownership and scene structure

The existing Mario scene still inherits BasePlayer. It now contains a Form child with MarioFormController; no Super player scene, duplicate state machine, or actor replacement was introduced. Mario exports Starting Form, defaulting to assets/player/forms/small.tres. BaseLevel optionally passes Player Start Configuration to the new generic BasePlayer.configure_start hook before adding the actor to the tree. Mario accepts MarioForm resources. TestLevel supplies super.tres; 1-1 supplies no override and remains Small.

MarioForm stores the selected artwork, three walk frames, two climb frames, optional crouch/intermediate growth textures, sprite position, standing/crouched enemy-contact sizes and centers, and can_crouch/can_break_bricks capability data. This does not implement actions or session persistence. GameHandler.player_status.powerup_form is not changed by the sandbox preview; actual power-up collection, transformations, damage, and persistence are future integration steps.

## Presentation application

Before the initial movement state starts, the controller maps Idle, Move, Slide, Jump, PipeEnter, and Climb sprite textures to the selected form. It builds a local animation library by copying the existing clips and replacing walk/climb texture keys. Clip timings, cadence, track paths, and shared movement scripts remain unchanged. Other animation clips are copied without remapping. Runtime configuration of the same actor reapplies the current state's presentation and restores the previous active animation phase; it does not change Body position, velocity, state-machine identity, or level/player ownership. This is a configuration operation, not a growth sequence.

All Super frames use their supplied full 16x32 canvases. Walk/climb atlas regions are 16x32 at X 0/16/32 and X 0/16 respectively. The new mario-intermediate.png was visually inspected as a 16x32 growth composition and is referenced as optional growth data, not played. Crouch similarly remains an available texture rather than a new behavior. Small's existing AtlasTexture resources are reused. Dead intentionally keeps the existing Small death texture and offset for either starting form; full Super damage behavior is not part of this pass.

## Alignment and contact profiles

Small retains Sprite2D position (0,-7) for its 16x16 artwork, a 10x12 enemy-contact shape at (0,-6), and its existing terrain body. Super uses Sprite2D position (0,-15) for 16x32 artwork, a 12x24 standing enemy-contact shape at (0,-12), and crouched profile data of 12x12 at (0,-6). The selected presentation offset preserves the existing rectangle bottom at Body-local Y=+1 and last opaque row at Y=0; it does not move the body or silently alter Small's convention. Climb's per-frame transparent foot padding is retained. Exact OAM/ROM pixel alignment remains unverified.

The contact RectangleShape2D is unique per applied instance, so Super cannot resize another actor's shared shape. The terrain body remains the existing Small 11x14 at (-0.5,-7). This preview must not be described as reference-complete Super collision. Standing terrain probes, uncrouching push-out, crouch/crouch-jump behavior, growth/shrink playback, Super damage, brick breaking, and form-specific jump sound are not implemented. Capability flags describe intended form abilities only. Audio gain and pitch were not changed.

## Authoring and verification

For F6, select TestLevel and set Player Start Configuration to assets/player/forms/small.tres or super.tres. The player_scene continues referencing the same Mario scene. For the actor's general default, edit Starting Form on that scene. These are scene/resource properties, not project settings or new Input Map actions. The user approved this startup/form configuration scope before implementation. The seven new Super images were imported with the existing Godot defaults; no import option was deliberately changed.

mario_form_test verifies sandbox Super and ordinary Small defaults, supplied growth texture dimensions, capability/profile data, every walk/climb texture key, static state textures, feet anchoring, instance-isolated libraries, Small/Super reconfiguration without actor/body/state replacement, preserved animation phase, and Small death presentation. Existing enemy_spawn edge-contact assertions explicitly request Small, rather than depending on the sandbox's development preview default.

Ten focused regressions reached PASS in Godot 4.7.2: mario_form, movement, climbing, sideways_pipe, flagpole_ending, title_backdrop, death, pause, enemy_spawn, and koopa_contact. Pause ran in real time; deterministic checks used fixed 60 FPS. ObjectDB exit warnings remain (final form run 2, movement 2, climbing 4, sideways pipe 10, flagpole 2, title backdrop 2, death 3, pause 2, enemy spawn 8, Koopa contact 4). Initial failures from reading an absent animation phase and a Small-only contact fixture were corrected; final focused runs passed without those errors. Full suite, rendered manual playtesting, and Mesen comparison were not performed.


## Standing/crouch integration follow-up - 2026-11-07

The first-pass preview limitations above are superseded for standing terrain probes, crouching/crouch jumps, uncrouch push-out, Super jump cue, and pipe/climbing/ending integration by [Super movement and posture](super-mario-movement.md). The short support body remains deliberate; Super's upper collisions use reference probes. Growth, shrinking/damage, and brick breaking remain deferred. Mesen runtime traces now qualify the specific scenarios recorded in the follow-up.

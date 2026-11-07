# Change history

Entries use the user's America/Toronto calendar dates. The initial history was reconstructed on 2026-11-01 from this conversation and inspected files; intermediate edits were not timestamped independently. Verification below describes checks performed at the time, not new checks on every later revision. New entries should state date, change, reason, affected paths, verification, and limitations.

## 2026-10-31 — Initial scaffold and return to defaults

- Added an entry scene, static test floor, spawn marker, starter documentation, and display overrides.
- The user asked to start over and restore defaults. The scaffold/settings were subsequently removed; a later inspection confirmed no blue clear-color override remained.
- Paths: `project.godot`, the former `game/`, `levels/`, and starter documentation.
- Verification: original scaffold imported and started headlessly with Godot 4.7.2 after redirecting temporary editor data into `.godot/`; later file inspection confirmed settings restoration. No visual verification claimed.

## 2026-11-01 — Pixel-art game and floor

- With explicit settings approval, configured a 256×240 viewport, 768×720 initial window, integer viewport scaling, preserved aspect ratio, and the Game entry scene. Used nearest filtering locally; retained the default background.
- Created Game loading TestLevel, a four-source 16×16 TileSet, a two-row floor, collision, Camera2D, and spawn marker.
- Paths: `project.godot`, `scenes/main/`, `scenes/levels/test_level.tscn`, `assets/tileset/terrain.tres`.
- Verification: Godot import/startup and headless checks for level loading, 32 floor tiles, viewport, camera, filtering, and floor collision. No visual verification claimed.

## 2026-11-01 — Base scenes and stationary player

- Created BaseLevel, BaseEntity, and BasePlayer foundations. Organized BasePlayer under `scenes/player/base/`; created Mario with inherited scene/script and a static sprite.
- TestLevel inherited BaseLevel; its script spawns the configured player after child readiness, with duplicate-spawn protection. Adjusted the marker to place feet on the floor.
- Removed placed brick/question blocks and their three terrain sources at the user's request, retaining images for future static entities.
- Paths: `scenes/levels/base/`, `scenes/entities/base/`, `scenes/player/`, TestLevel, terrain resource.
- Verification: headless import and scene startup; floor-cell checks during cleanup. The user later renamed Mario's folder to `mario (small)`; subsequent work preserved it. No movement or gravity added.

## 2026-11-01 — Entity state machine

- Added BaseState, EntityState, PlayerState, an entity-owned machine, presentation options, update/input hooks, validated transitions, and an initial Idle state.
- Added optional sprite/AnimationPlayer references and a player AnimationPlayer without animation assets.
- Paths: `scenes/components/state_machine/`, entity/player scenes and scripts, `tests/`, `docs/state-machine.md`.
- Verification: Godot 4.7.2 checks for isolated entities, hook routing, processing gates, presentation/animation, transition guards, stop/restart, and Mario spawning into Idle. No visual animation or movement implemented.

## 2026-11-01 — Character-owned states and global handlers

- Removed movement/jump permission flags; kept one controls flag. Moved shared PlayerState to `scripts/states/player/`; Mario now owns Idle, leaving BasePlayer's machine empty.
- Added GameHandler and ControllerHandler under `scripts/handlers/` and registered both autoloads with explicit user approval. GameHandler owns level replacement and in-memory session context; controller events now supply entity state input.
- Added secondary, start, and select held-input fields with unassigned action names. Input Map settings were not changed.
- Verification: headless tests passed for state transitions, ownership, level replacement, input disconnection, session retention, and controller permissions; game startup passed. Secondary/start/select addition received startup verification only. Disk saves, custom bindings, input buffering, and gameplay movement remain absent.

## 2026-11-01 — Documentation baseline and update policy

- Added the project overview, architecture reference, decision register, settings ledger, and this reconstructed history. Corrected the state-machine guide to acknowledge the existing controller handler.
- Added `AGENTS.md` requiring documentation with every change and prior approval for settings changes. Recorded implemented behavior separately from the proposed explicit scene/entity lifecycle and the unresolved physics-root tradeoff.
- Paths: `README.md`, `AGENTS.md`, `docs/`.
- Verification: compared documentation against current scripts, scenes, and `project.godot`; checked local Markdown links. No runtime changes or settings changes; runtime tests were not rerun for this documentation-only update.
- Policy clarification: the user subsequently limited updates to important milestones, major implementations, architectural decisions, and deliberate settings changes. D009 supersedes the original every-change requirement; routine edits do not need individual entries.

## 2026-11-01 — Composed horizontal movement and state effects

- Added a reusable HorizontalMovement action under BasePlayer/Actions and Mario-owned Move state, linked to Idle. Existing controller left/right inputs now accelerate, reverse, and brake Mario's physical body. Facing updates mirror the sprite and state offset. No run/jump/gravity/Air or camera following added.
- Moved common presentation onto BaseState; added optional enter/exit sounds, exit animation, and entered/exited signals around custom hooks. Machine-owned wrappers preserve effects when hooks are overridden. One-shot sound nodes follow the entity/body and queue removal when finished. No actual sound clips or animation frames are assigned.
- Paths: `scenes/components/actions/`, shared state/machine scripts, BaseEntity/BasePlayer, Mario states/scene, `tests/`, and current guides. No project settings, Input Map, or import settings changed.
- Verification: Godot 4.7.2 import passed; state/handler checks passed with new effect and signal-order coverage. Synthetic-input physics tests passed for Idle/Move, acceleration to target speed, reversal, facing/offsets, braking, disabled controls, constant height, and timestep-independent velocity. Audible output, visual appearance, and control feel remain manual editor checks.

## 2026-11-01 — Shared motion values, Run, and static Idle

- Added per-player MotionValues with editable defaults, named prioritized overrides, and a Body velocity proxy. HorizontalMovement now reads effective shared values. Run applies/removes only its own modifier; future level/state sources can override individual fields independently.
- Replaced prototype tuning with the initial coefficients documented in `movement.md`. This remains an approximation rather than verified original-game trajectories. Idle stops playback and selects static frame 0; no idle animation created.
- With explicit user approval, bound secondary/Run to physical Left Shift and gamepad left face button. Start/select remain unbound; other project and import settings unchanged.
- Paths: shared movement/action/state scripts, BasePlayer and Mario scene configuration, ControllerHandler, `project.godot`, tests, and current guides.
- Verification: Godot 4.7.2 import and startup passed; state/handler tests passed. Movement tests completed with PASS for walk/run, static Idle, bindings, braking/reversal, control gating, modifier precedence/removal, instance isolation, velocity proxy, and timestep independence. The test runner uses a frame-rate cap to allow real physics ticks; an earlier bounded uncapped run exited before completion and was not counted as a pass. No original-game trace comparison or visual/audible verification performed.

## 2026-11-01 — Slide/skid state and composition action

- Added Mario-owned Slide with Move transitions and a reusable Slide action under BasePlayer/Actions. Reverse input at speed applies a named modifier and brakes existing momentum; low residual X velocity is cleared before resuming Move. Release/resume-old-direction cancels Slide, and exit preserves other modifiers.
- Added normal/fast skid parameters and documented their source conversions and fidelity limits. Slide currently uses static frame 0, with no new art or sound. No project settings, bindings, or imports changed.
- Paths: `scenes/components/actions/slide.*`, BasePlayer, Mario Move/Slide scripts and scene, `tests/slide_test.*`, and current guides.
- Verification: Godot 4.7.2 import passed. Existing movement and state/handler suites passed. New Slide checks passed for numerical rates, preserved momentum, both directions, stopping without overshoot, priority overrides, cancellation, Slide/Move/Idle transitions, and modifier cleanup. No visual playtest or original-game trajectory comparison performed.

## 2026-11-01 — Velocity-driven walk/run cycle

- Added the supplied walk-1/2/3 textures to an external looping `walk` Animation resource and Mario's default animation library. Move selects it, while Idle and Slide retain their static sprites.
- Added Mario-owned WalkAnimation composition action; actual horizontal velocity selects playback cadence without restarting the loop. Move restores prior speed on exit. Timing and source interpretation are recorded in `movement.md`, including countdown-phase and exact-timing limitations.
- Paths: Mario's scene/script/Move state and `animations/walk.tres`, `scenes/components/actions/walk_animation.*`, animation tests, the Slide test's obsolete static-walk assertion, and current guides. Mario's animation callback is physics-based; no project settings, input bindings, movement tuning, or custom import settings changed.
- Verification: Godot 4.7.2 import/startup passed. New animation tests passed for three-pose order and looping, velocity-band boundaries in both directions, live progression, speed selection independent of Run input, braking slowdown, and Idle restoration. Existing movement, state/handler, and full skid-release tests passed. No rendered gameplay inspection or exact original-game frame trace comparison performed.

## 2026-11-01 — Jump, gravity, weight, and Air

- Added Jump/Gravity composition nodes, shared editable vertical values, and Mario's Air state using the supplied sprite. Ground states now maintain floor contact, jump on fresh primary input, and fall on ledge departure. Air preserves neutral horizontal momentum and selects grounded states on landing.
- Added speed-selected takeoff/gravity profiles, latched variable-height release, terminal fall speed, and weight as a gravity multiplier. Source conversions and fidelity boundaries are in jumping.md. No project settings, custom imports, or input bindings changed.
- Verification: Godot 4.7.2 jump tests passed for short/held height difference, weight effect, landing, sprite/cleanup, takeoff speed bands, ledge falling, air-jump rejection, and ceiling collision. Existing movement, state/handler, animation, and skid-release suites passed. Horizontal test instances now extend their terrain to keep these tests grounded; production terrain was not widened. No original-game trace or rendered gameplay qualification performed.

## 2026-11-01 — Air control and skid-jump braking

- Added AirMovement with separate editable rates/caps and a named modifier. Ground transitions capture facing/history before Slide cleanup; Air uses facing-based acceleration/braking and preserves neutral momentum. Landing removes Air's modifier. No settings, bindings, gravity/jump tuning, or assets changed.
- Recorded source anchors, speed rules, and fast-history proxy limits in jumping.md. Full fixed-point and RunningSpeed latch parity are not claimed.
- Verification: Godot 4.7.2 import passed. Air checks passed for both travel directions, skid jumps, rate bands/history, sign changes, neutral coasting, and landing cleanup. Jump/ceiling/variable-height and raw controller-event tests also passed. Existing movement, animation, state/handler, and skid-release checks were run for regressions; no rendered/hardware or exact original-frame comparison performed.

## 2026-11-01 — Motion, action, and presentation organization

- Moved Gravity, HorizontalMovement, and AirMovement from Actions to Motion, and WalkAnimation to Presentation, in both component files and inherited player scene groups. Run, Jump, and Slide remain Actions. MotionValues remains shared data. Renamed non-action classes to Component and updated callers while preserving script UIDs.
- Updated current guides and added the full player tree to architecture.md. Prior milestone paths remain historical. No calculations, values, bindings, invocation order, project settings, or import settings changed.
- Verification: Godot 4.7.2 import passed. Jump, Air, animation, movement, controller bindings, state/handler, and skid-release regressions passed. Searched active scripts/scenes/tests for obsolete paths and class references.

## 2026-11-01 — Jump sound playback diagnosis and import correction

- Jump already emitted its sound signal and created a correctly assigned audio node, but the WAV's embedded loop metadata enabled a zero-length loop. The initial node-creation checks did not establish audible playback.
- With explicit user approval, changed this WAV's import Loop Mode from Detect From WAV to Disabled and reimported it. No volume, bus, compression, source asset, or gameplay changes were required.
- Added imported-loop and decoded-amplitude regression checks. Godot 4.7.2 tests passed for raw controller events, one sound per jump, rejected-air-jump behavior, and decoded sound data. Runtime Master-bus capture changed from a near-silent peak around 0.000017 to around 0.16 for jump playback. Physical speaker output still requires a user check.

## 2026-11-01 — Grounded skid audio

- Mario's Slide state loops smb-skid.mp3 using a local stream copy and stops playback on exit or loss of floor contact. Entry requires floor contact and horizontal motion. Import settings are unchanged.
- The SMB disassembly's ProcOnGroundActs selects the skid pose for sufficient speed and opposing moving/facing directions; it does not implement a skid sound. Audio is a project addition, not NES audio parity. Slide regression tests passed.


## 2026-11-01 — Skid sound repetition correction

- Supersedes whole-recording looping: Slide now retriggers the skid MP3 every 6/60 seconds while grounded, using one owned audio player. Playback stops on exit or loss of floor contact; import settings remain unchanged.
- Reference: https://github.com/threecreepio/smb2j-disassembly/blob/master/sm2main.asm — ProcOnGroundActs queues the skid sound; PlaySkidSfx sets a six-frame counter, and NoiseSfxHandler finishes an active burst before accepting another. This is The Lost Levels (SMB2J), distinct from the original SMB1 disassembly. The sampled MP3 approximates the synthesized burst; its timbre is not cycle-accurate.


## 2026-11-01 — Combined level shadow trial

- User requested a visible trial including Mario, enemies, terrain, interactable objects, and decorations. BaseLevel now inherits CanvasGroup and uses level_shadow.gdshader to cast one combined silhouette onto the separate backdrop. Default offset is (3, 3) logical pixels, black at 40% opacity, with 8-pixel group margins.
- Existing child paths and spawning are preserved. No project or import settings changed. Forward+ D3D12 rendered preview captured successfully; see level-shadow.md for controls and composition limits.


## 2026-11-01 — Soft outer level shadow

- At the user's request, replaced the crisp offset trial with a centered alpha blur: offset (0, 0), blur radius 4 logical pixels, black at 40% opacity. The combined silhouette produces a soft outer halo while foreground sprites stay sharp. Added an editable blur_radius shader parameter.
- Rendered and inspected successfully with Forward+ D3D12. The 9-by-9 weighted kernel increases texture sampling; target-device performance has not been profiled. See level-shadow.md.


## 2026-11-01 — Base level horizontal camera bounds

- Ported the reference demo's camera-center/viewport-width/zoom clamp with a 7-world-pixel inset into BaseLevel. It clamps the moving Body after player physics (priority 100), preserving vertical position and velocity as in the reference. No bottom-boundary restart was added.
- Enabled by default; level exports keep_player_on_screen and horizontal_screen_inset allow overrides. Tests for motion beyond the camera explicitly opt out. Focused boundary checks passed for both sides, zoom, shifted camera, preserved Y/velocity, and opt-out. The rule assumes the current unrotated camera.


## 2026-11-01 — Camera boundary speed correction

- Supersedes the earlier velocity-preserving camera clamp. Following the SMB1 ScrollHandler/KeepOnscr routine, BaseLevel now clears horizontal speed at either edge unless effective player input points inward. This applies equally to grounded and airborne players and preserves vertical motion. The 7-pixel reference-app inset remains unchanged; this is not a cycle-accurate port of NES boundary coordinates or fractional arithmetic.
- Uses the current PlayerState's input so controls_enabled is respected. Tests passed for left/right edges, zoom, inward/outward/neutral input, rising/zero/falling vertical velocity, and opt-out. No project or import settings changed.


## 2026-11-01 — Wall-like camera edge resolution

- Corrected the inward-input exception introduced in the prior camera-boundary revision: it could retain outward momentum during an airborne reversal and cause an unwanted landing skid. Boundaries now cancel only outward velocity regardless of input, preserving inward and vertical velocity. This intentionally supersedes the direct KeepOnscr input check to match the requested wall-like behavior in this controller.
- Boundary tests cover both sides, zoom, all input directions, and inward/outward velocity. A runtime regression covers airborne edge contact with inward input, landing without Slide, and facing inward.


## 2026-11-01 — Solid ceiling response and bump sound

- Added BasePlayer.move_body() as the shared movement/collision-response entry point and routed Mario states through it. Rising ceiling contact starts downward motion at 3.75 pixels/second and falling-profile gravity, with one smb_bump.wav playback. This follows SMB1 SolidOrClimb/NYSpd for solid ceilings; interactive block reactions remain future work.
- No import or project settings changed. Jump regression checks passed, including held-jump ceiling contact, downward response, gravity, one nonlooping bump, decoded waveform amplitude, and landing. Hardware audio was not directly heard.


## 2026-11-01 — Exclusive entity sound effects

- BaseEntity.play_sound_effect now immediately stops and retires the entity's previous effect before starting a new one. Null effects do not interrupt playback. Mario's skid bursts use this same path, so jump, bump, skid, and state presentation effects replace one another. Each entity owns its channel; different entities remain independent.
- Slide cleanup retains its own playback reference so exiting Slide cannot stop the newer jump sound. State-machine, slide, and jump tests passed; interruption is explicitly asserted. No audio bus or import settings changed.


## 2026-11-01 — Entity and level shutdown lifecycle

- Added idempotent terminal shutdown to BaseEntity, BaseLevel, and EntityStateMachine. GameHandler invokes level shutdown before replacement/removal. Tree exit provides fallback cleanup. Levels discover descendant entities under their scene ownership tree.
- State cleanup and signals run once; shutdown suppresses standard exit animation/sound, disconnects input and animation callbacks, prevents restart/transitions/spawning, and stops active presentation. Startup remains synchronous _ready(); no activation/loading framework was added.
- Synced README and architecture/state-machine/movement guides with Motion-owned values, Air, current audio/collision/shadow ownership, Run-before-Jump ordering, and shutdown. Historical entries are retained.


Verification: all eight headless regression scenes passed. Lifecycle checks explicitly cover repeated shutdown, no exit presentation, callback disconnection, blocked updates/restart, tree-exit fallback, shutdown requested during enter, nested entity cleanup, and cleanup before level removal. Gameplay feel and hardware audio were not manually playtested for this milestone.


## 2026-11-01 — First block entity

- Added BaseEntity > BaseBlock > BrickBlock scene inheritance. BaseBlock has a 16-by-16 solid StaticBody2D and a sprite, with a top-left grid origin. BrickBlock supplies the existing Sprite-0002.png texture; no concrete script or states are needed yet.
- Placed one brick at (64, 144) under TestLevel/WorldObjects, as requested for a first playable block. It receives the existing ceiling-bump response and contributes to the combined shadow. Breaking, bouncing, and rewards remain unimplemented. No project/input/import settings were changed.
- Block regression passed: inherited setup, solid underside collision, landing, unchanged block position, and level-owned shutdown. Captured a Forward+ rendered preview.


## 2026-11-01 — TileMap-authored entity layout

- Added inherited EntityLayout and WorldObjects nodes to BaseLevel. Before player spawn, the level reads entity_id marker custom data and maps it through the exported Entity Scenes dictionary to BaseEntity scenes. Runtime markers hide; generation is one-shot and idempotent. Collision and behavior remain entity-owned.
- Dedicated entity_layout.tres uses a 16-by-16 brick marker with no physics. TestLevel now paints four bricks at cells (4,9), (5,9), (6,9), (11,9), retaining the editor-moved brick position (176,144). Removed the manual instance and duplicate container after reconciling a concurrent editor save. Existing ground edits were retained.
- Added entity-layout.md and updated architecture. Tests verify generated counts, no duplication, collision-free markers, solid contact, non-solid spawning, coordinate conversion, and shutdown. No project/input/import settings changed.


Final verification: block generation regression and all eight existing regression scenes passed after reconciling the editor save, with no shutdown leak warnings in those final runs. The final Forward+ preview shows the four generated bricks and was visually inspected.


## 2026-11-01 — Sprite names and folders

- Moved all small Mario PNGs and import sidecars into assets/player/mario (small)/. Renamed numbered tile sprites to ground.png, brick.png, brick-alternate.png, and question-block.png; block sprites now live in assets/interactibles/blocks/. TileSet resources remain in assets/tileset/.
- Updated scene, animation, TileSet, test, and current documentation references. Preserved import UIDs and import parameters; Godot regenerated cache paths on reimport. Historical path references remain historical. Preserved the user's newly painted TestLevel cells and isolated the block regression's four-cell fixture from stage edits.


Verification: reimport completed; scene/resource paths resolve. Block, walk-animation, slide, and jump regressions passed after the move. No sprite pixel data or gameplay tuning changed.


## 2026-11-01 — Animated question block

- Added QuestionBlock inheriting BaseBlock, using all three supplied question-block textures. Autoplay AnimationPlayer cycles bright/medium/dark/medium over 24/8/8/8 nominal 60-Hz frames, matching the SMB palette cycle's phase durations. No concrete states or reward/depleted/bounce behavior were added.
- Added a collision-free question marker and scene mapping, with two cells at (4,9) and (6,9); existing brick layout retained. Shutdown stops the inherited animation reference. No project or import settings changed.
- Question-block, block, and state-machine regression checks passed; captured a Forward+ preview. See question-block.md for reference and approximation boundaries.


## 2026-11-01 — Wider stage and original-style scrolling

- Extended the painted ground to 56 columns, X=-128..768, and moved initial camera/spawn left together by 128 pixels. Added LevelCamera with right-only integer-step scrolling, 80/112 screen thresholds, fixed Y, and a right world bound. BaseLevel updates the camera after player movement and before the screen clamp.
- Preserved the editor's organizational changes and marker cells, resolving spawn/layout by unique descendant names. Test fixtures no longer rely on the old floor edge or current painted question-block positions. Source rules and approximation limits are in camera.md.


Verification: all eleven headless regression scenes passed in final checks, including a live run to the camera's right limit. A Forward+ D3D12 scrolling preview was captured and visually inspected. No backward or vertical camera tracking is enabled.


## 2026-11-01 — Continuous camera tracking

- Investigated reported choppy running/scrolling. Removed floor rounding of target position in LevelCamera: steady 150-pixel/second motion at 60 Hz previously produced alternating 2/3-pixel camera steps while the player moved continuously. Early tracking now uses a stable half-speed factor instead of subtracting a whole pixel from qualifying steps. This intentionally supersedes the exact integer-step approximation while preserving right-only movement, 80/112 thresholds, fixed Y, and world bounds.
- Camera regression passes, including explicit constant 2.5-pixel displacement checks and a live run to the right limit. Project settings, interpolation, viewport, and filtering were not changed. Final perceived smoothness still requires user playtesting.


## 2026-11-01 — Original-sized testing stage

- Restored the 16-column, two-row floor at X=0..256 and original camera/spawn positions. Set scene camera bounds to 0/256 while retaining the scrolling implementation and tuning for larger stages. Block markers retained.
- Scrolling regression now owns its wide test fixture. Camera-follow, camera-boundary, and block tests passed. Updated current camera/architecture guides and settings record.


## 2026-11-01 — Restore centered outer halo material

- Investigated the changed shadow appearance. BaseLevel's saved ShaderMaterial offset was (3,3), overriding the shader's centered (0,0) default. Restored the material value to (0,0), matching the previously requested outer blur. Blur radius 4 and opacity 0.4 remain unchanged.
- Captured and visually inspected the rendered result with Forward+ D3D12. No gameplay, project, or import settings changed.


## 2026-11-02 — Environment theme asset folders

- Added overworld/underground/castle directories beneath assets/tileset, assets/interactibles, and assets/enemies. Moved current ground/block terrain sprites and interactible block animation frames into overworld (palette 1); no enemy sprites existed. Empty theme directories have .gitkeep placeholders.
- Retained shared TileSet resource paths and player/audio/scene organization. Updated scene, animation, TileSet, import-source, and current documentation paths; historical paths are retained in this log. No runtime theme switching, artwork recoloring, or gameplay changes were introduced.
- Verified all seven sprite hashes, import UIDs, and import parameters were preserved, scene/resource paths resolve, and block/question-block regressions pass. Godot reimported relocated artwork without changing import parameters.


## 2026-11-02 — Theme-first environment folders

- Supersedes the category-first folders added earlier today. Environment artwork now lives under assets/Overworld (Palette 1)/tileset, enemies, and interactibles. Underground and Castle have the same category folders, without assigning unconfirmed palette numbers.
- Moved PNG/import sidecars and empty-folder placeholders, updated references and current guides, and retained shared assets/tileset TileSet resources. Player, sound, scene, and gameplay organization is unchanged. Theme selection remains deferred.


Verification: Godot reimport succeeded; sprite hashes, import UIDs, and import parameters are preserved; scene/resource references resolve; block and question-block regressions pass.


## 2026-11-02 — Paintable decoration layer

- Added inherited Decorations TileMapLayer and a dedicated collision-free decoration TileSet using the supplied Overworld bush left/middle/right textures. Painted small and wide sample bushes behind gameplay, with the same 16-by-16 grid. Decorations are direct tiles, not spawned entities, and join the existing combined halo.
- Added empty decorations folders to Underground and Castle. Updated architecture, theme guide, and scene settings record. Movement regression passed, and a Forward+ rendered preview was visually inspected for bush placement and player layering. No project or existing import settings changed.


## 2026-11-02 — Include decorations in the shared halo

- Fixed the prior decoration layering choice: negative Z separated bushes from the CanvasGroup composite, so gameplay shadows rendered over them. Decorations now shares Z=0 and draws first by sibling order, keeping it behind gameplay within one composited silhouette.
- Rendered and visually inspected with Forward+ D3D12: bushes receive the outer halo and retain sharp foreground color. Updated current architecture guidance and recorded the scene-order change.


## 2026-11-02 — Narrower small-Mario collision

- Added a Mario-specific 11-by-14 collision rectangle at (-0.5,-7), based on the disassembly's small-player head/side terrain probes. Preserved 16-by-16 artwork and feet origin; BasePlayer's generic shape remains unchanged. Documented the difference between NES probes and this Godot envelope.
- Gap/ledge regression passed, along with jump/ceiling, block, and camera-boundary tests. Ceiling assertions now use the smaller body's actual head height. No level painting or physics coefficients changed.


## 2026-11-02 — Corner forgiveness and foreground Mario

- Added a Motion corner-correction component before normal body motion. Two foot rays allow shallow descending top-face recovery up to four pixels with clearance checks; rising edge contact can escape sideways up to four pixels when the projected center head path is clear. Centered ceiling bumps retain the existing response and sound. This adapts NES probe behavior to swept rectangles; it is not an exact collision-routine port.
- Ordered WorldObjects then Players last within the same CanvasGroup Z band, so Mario draws over terrain and blocks without losing the combined halo. No painted cells, project settings, or existing import parameters changed.
- Focused two-sided corner, momentum, centered bump, deep wall, miss, low-ceiling, gap/ledge, jump/block, slide/air, camera-boundary, and lifecycle regressions passed. Collision-only tests disable bump audio to avoid an immediate-quit audio-driver retention warning; audio remains covered by jump tests. Forward+ overlap render verified foreground Mario. See corner-correction.md.


## 2026-11-02 — Running gap landing recovery

- Reproduced full-run failure at a one-tile floor gap: the existing correction detected a shallow landing but the following diagonal sweep collided with the tile side and cancelled X velocity. Recovery now completes the collision-checked horizontal step while raised, then integrates vertical movement once and preserves X speed.
- Added shallow physical-envelope edge probes after the reference-style inset feet, preventing the swept rectangle from striking a side one pixel before its inset probes reach the top. Kept the four-pixel limit, clearance checks, miss/deep-wall rejection, and existing head-corner behavior. No level painting, project settings, or movement coefficients changed.
- Added real-state running-gap regression across both directions and five subpixel approach phases, plus wider-gap rejection. Updated corner-correction.md.


## 2026-11-02 — Jump state distinct from passive falling

- At the user's correction, renamed Mario's Air state/script to Jump (preserving the script UID). Deliberate grounded jumps retain Jump and the existing jump pose through ascent/descent until landing. Passive ledge falls and recovered gap crossings stay in Move with walk/run presentation; Idle/Slide select Move on support loss.
- Move invokes the shared AirMovement/Gravity components while unsupported and cleans up the air modifier on landing/exit. No coyote time or delayed fall was added. Updated state links, tests, current guides, and README; historical Air entries remain historical.
- Running-gap checks now assert Move and walk animation throughout both-direction crossings and Move during wide-gap falls. Jump checks assert Jump persists while its action is active. No project/import settings or level painting changed.


Verification: all fourteen regression scenes passed across the final checks. Both-direction gap crossings retain Move/walk presentation at five approach phases, wide gaps fall within Move, and deliberate jumps keep Jump until landing. Headless checks do not establish subjective animation feel.


## 2026-11-02 — Freeze Move animation during passive falling

- Move now freezes the current walk pose and playback phase on support loss, then restores velocity-based cadence on landing. The animation is not restarted, and Jump's separate presentation is unchanged.
- Added a live falling/landing animation regression; running-gap and jump checks passed. Grounded animation tests now establish floor contact before checking frame progression. No project/import settings or movement coefficients changed.


## 2026-11-02 — Base-scene cleanup and verification checkpoint

- Grouped BasePlayer scene declarations by Body, Motion, and Actions. Moved the empty Presentation container from BasePlayer into Mario, where WalkAnimation actually uses it. BasePlayer now owns the Body/AnimationPlayer reference directly; Mario only supplies its library and physics callback override. Renamed stale internal Air resource IDs to Jump.
- Replaced BaseLevel's recursive node-name searches with explicit owned paths (Players/PlayerSpawn and EntityLayout). Added Inspector export groups for spawning, screen bounds, and ceiling response without changing values. Retained empty inherited state machines as deliberate extension points for blocks and generic entities. No unrelated gameplay refactor was introduced.
- Added scripts/run_tests.ps1 to discover all regression scenes and reject nonzero exits, missing PASS markers, engine errors, or warnings. All 15 scenes passed. Resource audit found no missing paths or unreferenced scene/resource declarations. Generic BaseEntity/BasePlayer/BaseBlock instantiation and shutdown, owned references, Mario presentation, and layer ordering passed a rendered runtime smoke check; its Forward+ preview was visually inspected.
- TestLevel's file hash is unchanged: painted cells, camera settings, and shader tuning were preserved. Updated current architecture/state-machine/camera docs, README, and added verification.md. No project/input/import settings changed. Headless checks and a render smoke check do not replace subjective movement/audio playtesting.


## 2026-11-02 — Project display name

- Renamed application/config/name and README title to QuickGame-Godot2D (Super Mario Bros), as requested. Workspace directory and resource paths remain unchanged. See settings.md for the default user-data directory implication.


## 2026-11-02 — Broader platformer tutorial identity

- Renamed the project display title and README to QuickGAME-GD Mario Bros, superseding the earlier game-specific title. Updated the introduction to explain the multi-game tutorial scope. Retained historical names and game-specific technical attribution. Workspace folder, resource paths, and gameplay are unchanged.
- Verification: checked the configured display name and README identity on disk. Gameplay tests were not run for this metadata/documentation change.

## 2026-11-02 — Inherited level layouts and enforced grid

- Grouped all authoring layers under BaseLevel/Layouts: DecorationLayout, GroundLayout, and EntityLayout. Ground now belongs to BaseLevel; TestLevel supplies TileSets and painted cells. Updated spawning paths and regression fixtures for the inherited hierarchy.
- Added level_layouts.gd as an editor/runtime tool script enforcing identity local transforms and 16x16 square TileSet cells. Independent layout transforms are reset. The whole stage can still be positioned through its level root. Existing collision, camera, halo, project settings, Input Map, and import settings are unchanged.
- Verified all three painted tile_map_data byte arrays are unchanged. The existing 15 regression scenes passed. The new grid test initially failed to parse due to a missing explicit type annotation; after correction its focused rerun passed without engine errors or warnings. It verifies inherited ground, transform/cell-size/shape correction, preserved cells, matching grid coordinates, and aligned entity spawning. Interactive editor behavior was not manually inspected.
- Updated architecture, entity-layout, verification, settings, and decisions documentation.

## 2026-11-02 — Question-block activation and reusable block states

- Added EntityHit context and a reusable Bonk action, disabled on BasePlayer and enabled by Mario. Rising ceiling contacts deliver one center-head-selected hit through BaseBlock to its current EntityState. The existing player ceiling response retains sound ownership. Bricks keep their empty FSM and existing solid behavior.
- QuestionBlock now supplies Active and Inactive nodes to its inherited machine. Active owns the palette loop and hit acceptance; Inactive immediately rejects further hits, selects the supplied question-block-4.png used sprite, and starts the shared visual bounce on entry. Shutdown/exit restores the sprite origin. No rewards, items, breaking, or new input bindings were added.
- BlockBounce uses reference-derived initial speed/gravity (-120 px/s and 1125 px/s squared at nominal 60 Hz), while deliberately retaining fixed collision rather than the original temporary metatile/moving-object behavior. See question-block.md for source routines and fidelity limits. No existing project settings, import parameters, painted cells, camera, or halo tuning were changed; the newly supplied texture was imported with defaults.
- Verification: editor import completed; all 16 regression scenes passed without engine errors or warnings. Expanded question-block coverage includes real jump contact, wrong-maneuver/direction rejection, used presentation, visual motion with fixed collision, repeated-hit rejection, neighboring-block independence, and shutdown during the bounce. Interactive visual/audio playtesting remains to be done.

## 2026-11-02 — Repeatable brick bounce

- BrickBlock now configures the shared block-state scripts as Active -> Bouncing -> Active. The shared reaction state optionally returns to a configured return_state after the bounce; QuestionBlock leaves it unset and stays Inactive. Renamed Active's transition export to reaction_state to support both uses.
- Bricks accept upward Bonk hits, reject further hits during the reaction, retain their artwork and fixed solid collider, and can bounce again afterward. Strength does not yet select breaking behavior. No terrain painting, project/input/import settings, sound ownership, or motion values changed.
- Verification: all 16 regression scenes passed without engine errors or warnings. Expanded brick tests cover two real jump contacts on the same brick, visual movement with fixed collision, invalid and repeated-hit rejection, strong hits still bouncing, and shutdown during a bounce. Question-block one-shot behavior also passed. Updated current state, architecture, question-block, and verification guides.

## 2026-11-02 — Explicit question-block Bouncing state

- Split question blocks into Active -> Bouncing -> Inactive. Renamed the shared reaction script from inactive_block_state.gd to bouncing_block_state.gd, preserving its UID. Bricks continue using it for Active -> Bouncing -> Active. Inactive uses the generic EntityState and disables processing; used artwork timing remains immediate on accepted hit.
- Bouncing exposes inherited entry/exit signals and presentation settings plus a one-shot bounce_completed signal on natural completion. Interruption/shutdown restores presentation without completion. No items or additional audio are spawned.
- Verification: focused question_block_test and block_test passed without engine errors or warnings. Question-block coverage now checks ordered Bouncing/Inactive transitions, one entry/completion event, rejection during Bouncing, and no completion on interrupted shutdown. The full regression suite was not rerun for this focused state change. Updated current guides and appended the replacement decision.

## 2026-11-02 — Bonk edge-contact correction

- Reproduced an underside collision that failed activation when Mario's center was outside the brick. Removed the center-inside-tile rejection: Bonk now selects one actual ceiling-contact block by nearest center, with a right-block tie break. Side-only contacts and corrected-away corners remain excluded; movement/corner-correction values are unchanged.
- The new bonk_contact_test failed at the left edge before the fix and passed afterward, covering both edges, a seam, an escaped corner, and horizontal side contact. Focused brick, question-block, and corner-correction regressions also passed without engine errors or warnings. The full 17-scene suite was not rerun. Updated the current hit-selection guide and verification inventory.

## 2026-11-02 — Reference-based Bonk seam selection

- Inspected the reference HeadChk, BlockBufferColli_Head, BlockBuffer_X_Adder, and BlockBufferCollision routines: the head probe uses sprite-left +8 to select one tile. Replaced contact-ranking as the primary selector with a short center-head upward ray after an actual ceiling collision. Exact seams select the right tile; a used block/solid under the probe cannot redirect activation to an active neighbor.
- Retained contact ranking only when the probe finds no solid, preserving the prior edge-contact fix. This fallback and continuous Godot collision remain explicit adaptations; original fixed-point timing and global BlockBounceTimer behavior are not reproduced. Source: https://gist.github.com/1wErt3r/4048722 .
- Verification: expanded bonk_contact_test checks the actual block selected left of, at, and right of a seam, plus used-neighbor rejection, isolated edges, corner escape, and side contacts. Focused Bonk, brick, question-block, and corner-correction tests passed without engine errors or warnings. Physics fixture cleanup now waits a frame between trials. Full regression suite not rerun. Updated current behavior and verification guides.

## 2026-11-02 - Static pipe tiles and expanded test stage

- Added the four supplied vertical pipe pieces to terrain.tres as sources 1..4, retaining ground source 0. Each piece has solid 16x16 collision. These are paintable non-interactive terrain tiles; travel entities and area transitions remain future work. No pipes were painted automatically.
- Expanded TestLevel rightward to 768 pixels, adding floor cells in columns 16..47, extending the blue background, and matching the camera's right world bound. Existing painted content and camera tracking rules are preserved.
- Verification: resource check passed for all 96 floor cells, camera bounds, four tile textures, and collision polygons. Focused camera-follow regression passed, including live traversal; editor import completed cleanly. Full gameplay suite not run for this content change. Updated architecture, camera, shadow, entity-layout, and settings guides.

## 2026-11-02 - Shift test content right by eleven tiles

- Shifted every currently painted decoration, terrain, and entity marker by +11 cells (+176 pixels), preserving all tile IDs and the user's additional painted content. Moved PlayerSpawn from (40,208) to (216,208). Added ground in columns 0..10 at rows 13/14 to make the new left-hand space usable.
- Camera starts at (128,120), retains world-left 0 and right-only tracking, and now ends at world-right 944. Keeping the initial view at the left edge makes the added space accessible. The current scene no longer contains the separate Background node; no background was recreated or global color changed.
- Verification: checked every original cell survives at its +11 coordinate with unchanged tile data; headless normal startup passed without errors or warnings. Full regression suite not run for the layout change.

## 2026-11-02 - Enclosed lower test area

- Added TestLevel/Areas/LowerArea at world (0,512), with a black background, arrival marker, and disabled fixed LevelCamera. Added a 16-column room to the shared terrain grid with solid ceiling, side walls, and floor; existing painted content is unchanged. Main camera remains current until future pipe traversal explicitly switches it. No pipe entry/exit logic or general area-management system was introduced.
- Verification: lower_area_test passed without engine errors or warnings. It checks the startup camera, room enclosure, then simulates arrival and holds both movement directions to verify fixed camera position and player containment. Full 18-scene regression suite not run for this addition. Updated architecture, camera, verification, and settings documentation.

## 2026-11-02 - Interpolated player and camera rendering

- Measured 60-Hz physics against an approximately 240-Hz display with interpolation off; the camera followed in the same tick but physics positions repeated on most render frames. Enabled the explicitly approved project interpolation setting and added initial player/camera history resets. Kept 60-Hz physics and existing scrolling rules.
- Regression testing exposed interpolated screen-center feedback in camera follow. Follow and screen clamping now use authoritative LevelCamera global coordinates. Updated boundary assertions accordingly. Camera-follow and lower-room fixtures now build independent terrain because newly painted pipes and moved rooms had invalidated their previous layout assumptions; user-authored scenes were preserved.
- Verification: initial 18-scene suite reported camera-follow and lower-area failures; 16 other scenes passed. After fixes, focused camera-follow, camera-bounds, and lower-area reruns passed without engine errors or warnings. Final full-suite rerun was not performed. Rendered Forward+ probe confirmed interpolation=true, zero physics-follow mismatches and zero repeated rendered canvas positions across 329 measured frames; frame-time median approximately 4.17 ms and maximum 4.73 ms in that sample. A subjective playtest remains necessary. Updated camera/settings documentation.

## 2026-11-02 - Remove jump takeoff pause

- Reproduced a skipped movement tick when Idle/Move/Slide selected Jump: jump velocity changed, but movement waited until the next physics tick, briefly halting horizontal scrolling. PlayerState.continue_jump_physics now enters Jump and lets it consume the otherwise unused takeoff tick. Outgoing state cleanup runs before Jump physics; gravity, speed, air-control, camera, and interpolation settings are unchanged.
- Expanded air-movement coverage for immediate upward/horizontal movement from all three ground states under both Run contexts. The strengthened check executes inside a real physics callback on an isolated flat fixture and checks one step within 0.1 pixel collision-recovery tolerance. It failed before the implementation and passes after it.
- Verification: full 18-scene suite passed without engine errors or warnings after the implementation. The subsequently strengthened air-movement assertion also passed in its focused rerun. Forward+ run/jump probe recorded zero same-tick camera-follow mismatches and zero repeated rendered canvas positions over 569 measured frames, with approximately 4.17 ms median and 4.60 ms maximum frame time in this sample. Subjective playtesting remains necessary; no claim of eliminating every display hitch. Updated jumping, camera, and verification guides.

## 2026-11-02 - Area-owned Overworld and Underground themes

- Added BaseLevelArea and a reusable base_area.tscn with its own layouts, WorldObjects, Arrival, and camera. MainArea selects Overworld and LowerArea selects Underground through AreaTheme resources. BaseLevel generates each area's entities, assigns themes before startup, and retains shared player ownership and descendant shutdown. Main-area convenience properties remain available.
- Added compatible Underground terrain/marker TileSets and explicit texture mappings for the supplied ground, brick, and alternate-brick art. Missing pipe, question-block, and decoration variants fall back to Overworld. BaseState static presentation and private animation-library copies resolve through the entity theme. Mario's appearance, shared block scripts, and source animation resources remain unchanged. No palette shader or runtime theme switching was introduced.
- Split all painted cells into area-local layouts and normalized LowerArea's origin to its existing camera-view top-left. Automated comparison confirmed every saved cell retains its original world coordinate and logical tile identifiers; existing camera/arrival world positions are preserved. No project/input/import parameters or shader/background tuning changed.
- Verification: final full 19-scene regression run passed without engine errors or warnings. Added area_theme_test for theme separation, retained terrain collision, artwork fallback, themed spawning and bounce recovery, source-resource isolation, and shutdown. Initial fixture failures from nested scene packing were corrected; tests now preserve editable area overrides, and the reusable area's camera uses the standard enabled default while LowerArea explicitly remains disabled. Rendered Forward+ previews of both areas were visually inspected and completed cleanly.
- Updated architecture, theme authoring, camera, entity layout, question-block paths, settings, decisions, README, and verification documentation. Pipe travel, music changes, active-area game state, hot-swapping spawned entities, and the per-cell contents editor remain future work.

## 2026-11-02 - Restore nested area layout persistence

- Fixed Bonk's unassigned-variable warning by explicitly initializing selected to null. Separately diagnosed the empty scene: saving without persisted Editable Children flags had discarded nested area painted-layer and camera overrides. Added the required editable paths to BaseLevel/TestLevel and restored all six layout byte arrays from the saved pre-migration cell snapshot.
- Preserved the user's latest LowerArea position (896,240); restored its local camera (128,120), disabled startup state, local Arrival (32,48), and matching fixed-view world bounds 896/1152. Restored the main camera to (128,120), enabled, bounds 0/944. Current guides reflect the moved area.
- Verification: rendered both restored areas with Forward+ and visually inspected them; startup completed without errors/warnings. Expanded area_theme_test to save/reload the scene and assert every painted layer and both camera enabled states survive; it passed. Focused Bonk contact regression passed. The full suite was not rerun for this repair.

## 2026-11-02 - Paintable one-way pipe entry

- Added PipeEntrance inheriting BaseEntity, rendering both top pieces with a 32x16 solid cap. Registered marker source 3 and entity_id pipe_entrance in both area-theme palettes; TestLevel maps it to the shared scene. One marker occupies the left opening cell and creates a two-tile-wide entity. Existing painted cells are unchanged; no example entrance was placed automatically.
- Added deferred BaseLevel.request_area_transfer: validate unique destination ID, reject duplicate/same-area/shutdown requests, retain the player, clear transient movement/state, move Body to Arrival, reset interpolation, switch cameras, and restart the initial player state. GameHandler records current_area_id while retaining other session values. Pipe input uses ControllerHandler and requires active source area, grounded aligned feet, and enabled player controls.
- Entity theme application now resolves every child Sprite2D so multi-piece entities can use future texture overrides. No return travel, entry/exit animation, new sound, music transition, or per-cell endpoint editor was added.
- Verification: the 20-scene suite passed 19 scenes, including the new pipe transfer test. The grid fixture initially failed because it inspected TileSets before theme initialization; adding the fixture's theme initialization made its focused rerun pass cleanly. The new pipe test covers paint generation, collision support, alignment/airborne/control gates, deferred destination/camera transfer, velocity/FSM reset, session preservation, and shutdown. A rendered Forward+ fixture using real held Down input successfully transferred to Underground; before/after captures were visually inspected. Updated pipe, architecture, camera, theme, entity-layout, verification, settings, decisions, and README guides.

## 2026-11-02 - Full 2x2 pipe stamp and foreground coverage

- Replaced the cap-only pipe with all four existing cap/body sprites and 32x32 solid collision. Source 3 now renders a complete 2x2 atlas preview anchored at the top-left; one painted anchor still creates one entity. Added a generated preview texture and scripts/build_pipe_marker.gd to rebuild it from the original sprites. Existing painted anchors were not moved or replaced.
- Added BaseLevel/ForegroundObjects after Players at Z=0. Pipe visuals reparent there with RemoteTransform2D alignment, while physics/entity ownership stays in the area. Shutdown unlinks and frees the transferred visuals. The pipe now covers Mario inside its body without escaping the combined shadow or changing ordinary block draw order. Actual descent animation remains unimplemented.
- Verification: all 20 regression scenes passed without engine errors or warnings. Pipe tests now include 32x32 shape/marker dimensions, four-part presentation, foreground order, and cleanup. Forward+ pixel comparisons confirmed the marker matches runtime placement and the pipe fully obscures Mario inside it; the rendered check completed cleanly. Preview rebuild script also completed cleanly. Updated current pipe, architecture, shadow, authoring, settings, and decision documentation.

## 2026-11-02 - Named pipe endpoints and per-cell destinations

- Added AreaEndpoint markers with unique area-local IDs and future exit-direction metadata, keeping Arrival/arrival compatible. BaseArea exposes an Endpoints container; MainArea includes near_start and near_end example markers. Existing painted terrain, entities, and arrival markers were preserved.
- PipeEntrance now sends both destination_area_id and destination_endpoint_id. Source-area PipeRoute resources apply individual destinations by painted anchor cell before startup. This provides native Inspector authoring until the custom per-cell editor is built. One shared pipe scene supports multiple named destinations, including same-area named travel and configured return routes.
- BaseLevel rejects missing/duplicate/current targets, uses weak references and revalidation across deferred transfer, records current_endpoint_id alongside current_area_id in GameHandler, and requires releasing Down before another pipe activation. Scrolling cameras snap to reveal the endpoint within existing world bounds; fixed cameras retain their position. No entry/exit animation, new SFX, music policy, or automatic exit-pipe placement was introduced.
- Verification: full 21-scene suite passed without engine errors or warnings. New pipe_routing_test covers independent route save/reload, named/default destinations, duplicates/missing/deleted targets, same-area travel, camera repositioning, input reentry lock, and session preservation. Subsequent stronger direction-metadata and arrival-clamp assertions passed in a focused rerun. Updated current authoring, architecture, camera, verification, configuration, decision, and README documentation.

## 2026-11-02 - Animated pipe entry, sound, and handoff

- Added reusable PlayerPipeEnterState under scripts/states/player, owned/configured by Mario's PipeEnter node and referenced by BasePlayer. Entry locks controls, suspends player collision/gravity movement, centers over the opening, clears velocity, and descends at 60 pixels/second for 48/60 seconds. It hides the sprite after it passes below the opening and freezes source camera/clamp during the sequence. Timing is based on HandlePipeEntry/VerticalPipeEntry in the reference disassembly; Godot hiding/rendering/loading are deliberate adaptations.
- Interactive pipes now request a reserved animated trip rather than immediate relocation. The existing named-endpoint handoff runs after descent and revalidates source/destination. Invalid targets or state interruption cancel safely; exit/shutdown restore collision, visibility, and source position where appropriate. Direct scripted area transfer remains available.
- Assigned the supplied smb_pipe.wav to PipeEnter's entry presentation. Its imported stream reports looping, so the state uses a nonlooping runtime duplicate without changing import settings. BaseState retains the entry audio handle for ownership-safe cancellation. Tests verify one playback, nonloop mode, decoded amplitude, and the approximately 0.784-second clip duration; speaker output is not independently verified. No exit animation, fade, music policy, input binding, or existing painted route/cell change was added.
- Verification: final full 22-scene suite passed without engine errors or warnings. Expanded transfer coverage checks timed movement/hidden phase, collision restoration and sound; new pipe_entry_test covers ignored controls, camera freeze, once-only playback, invalid-target rollback, and shutdown. An initial synthetic fast-forward test produced intermittent audio cleanup warnings; using real physics-paced waits lets the clip finish before teardown and the final run is clean. Forward+ real-input captures of partial descent, hidden waiting, and destination arrival were visually inspected and completed cleanly. Updated current guides, settings, decisions, and README.

## 2026-11-02 - Unoccupied area runtime unloading and preserved progress

- User requested unoccupied areas unload and explicitly selected preserving progress. BaseLevel now prepares authored runtime templates, generates only MainArea at startup, and frees inactive runtime branches. Inactive area roots retain routing/configuration metadata and packed definitions, while layouts, physics collision, generated entities, cameras, and transferred pipe visuals are released. Editor-local authored content remains unchanged.
- At a hidden pipe handoff the destination runtime loads/restores, its camera is selected, and the previous area is saved/shut down/freed. Same-area endpoint travel retains its existing runtime. Entities are recreated on return rather than restarting terminally shut-down instances.
- GameHandler now owns copied, memory-only area snapshots keyed by level identity and area_id. Snapshots preserve TileMap cell data, logical block state, and removed marker entities. Bouncing saves its logical return state; used question blocks restore Inactive without replaying the bounce. BaseBlock retains a last logical snapshot for child-first tree-exit cleanup. Named registered levels preserve progress across level replacement; anonymous/standalone scopes are discarded at shutdown. Shared assets/templates remain cached; no VRAM-eviction or asynchronous-loading claim is made.
- Verification: all 23 regression scenes passed without engine errors or warnings. New area_streaming_test verifies actual inactive node/physics removal, weak references clearing, metadata endpoint resolution, repeated visits without duplicate pipe visuals/entities, used/removed block and tile progress, level replacement, and cache clearing. Theme, lower-area, and pipe-transfer fixtures now expect inactive runtime nodes to be absent. Forward+ pipe captures confirmed the destination stays unloaded throughout descent and source runtime is gone after handoff; the rendered check completed cleanly. Updated lifecycle/current guides, settings, decisions, README, and verification inventory. No project/Input Map/import parameters or existing authoring scene cells were changed.

## 2026-11-02 - Normal pipe ordering and entry-only player background priority

- Returned pipe Visuals to the entity's normal area WorldObjects hierarchy. Removed its visual reparenting, RemoteTransform2D, specialized visual shutdown, and the unused BaseLevel/ForegroundObjects container. Mario normally draws in front of pipe artwork just like other blocks.
- BaseLevel saves the Players sibling index and moves the group before Areas only while pipe entry is active. Completion, cancellation, and live state exit restore the prior order. Dying player/level teardown skips unnecessary sibling reordering. All contributing visuals remain Z=0 inside the shared shadow group; physical transforms, camera logic, collision, centering, input gates, and entry timing are unchanged.
- Verification: focused pipe entry/transfer tests passed with ordering/restoration assertions. Forward+ pixel comparisons verified Mario is visible over the pipe normally, only the portion outside the pipe remains visible during entry, and cancellation restores ordering. The broad suite passed 21 scenes; area-streaming/routing checks exposed saved near_start/near_end markers outside MainArea's Endpoints container. Restored their parents/names with positions and endpoint IDs unchanged; both focused reruns then passed. Final full-suite rerun was not performed. Updated current rendering, lifecycle, settings, and decision documentation.

## Sideways pipes and animated return - 2026-11-02

Added solid sideways mouth/body terrain pieces to both compatible theme TileSets, plus a complete 2x2 paintable sideways entrance inheriting the upright pipe scene. Generalized the player-owned pipe travel state for horizontal entry and directional emergence. AreaEndpoint now optionally animates exit to its final feet position; existing open-space arrivals and direct scripted transfer remain compatible.

TestLevel's secret-area return pipe at (14,11) targets main/pipe_return, emerging upward from the existing upright pipe at (57,9). Removed the two overlapping static junction cells from the return pipe footprint. Routing, source unload/progress preservation and camera ownership stay in BaseLevel; normal collision, controls and draw order restore at completion. Updated pipes, architecture, verification, decisions and scene-settings documentation. No Project Settings, Input Map or existing import parameters changed.

Verification: all 23 existing test scenes passed without engine errors or warnings; the additional sideways_pipe_test passed headlessly and under Forward+ D3D12. It checks real right-input activation, horizontal entry, source unload, upward emergence, final position, collision/draw-order restoration and both theme TileSets. Rendered entry and emergence screenshots were inspected. Git diff whitespace check passed (Git reported line-ending normalization notices). Subjective controller feel and exact NES frame-trace equivalence were not qualified. Only upright and left-facing entrance artwork is currently supplied; exit markers support all four directions. Music and screen fades remain future work.

## Pipe presentation and control timing reference check - 2026-11-02

Compared pipe routines and player animation/control dispatch against the linked SMB disassembly. Mario's PipeEnter now uses his existing walk animation/cadence for sideways motion, stops at the aligned sprite-left grid boundary and waits concealed. Vertical travel uses the standing pose. Endpoint Exit Distance defaults to 96 pixels, extending upward emergence to its complete controlled sequence instead of ending after only the sprite cleared the mouth. Normal states are no longer briefly started between travel phases. Upward exit faces right and does not replay the entry sound. A floating-point threshold prevents an extra locked tick at completion.

Preserved the user's moved sideways marker at (13,11) and static junction art. Restored the three named main-area endpoints under their intended Endpoints container after the editor saved them as flattened root nodes; their IDs/positions were unchanged. Updated pipe, verification, decisions and scene-settings documentation. No project/input/import settings changed.

Verification: all 24 headless regression scenes passed without engine errors or warnings. The strengthened sideways test additionally passed after adding exact assertions for the 80-tick side-entry boundary and 96-tick upward handoff. It checks walk texture cycling, aligned stopped position, no intermediate normal state, invisible early emergence, no exit sound replay, final collision/control restoration, held movement after completion and no buffered jump from locked input. Forward+ D3D12 preview ran successfully; entry and late-emergence screenshots were inspected. Whitespace check passed with line-ending normalization notices. Horizontal movement remains a constant-speed adaptation; special page-zero intro timing is configurable rather than selected automatically. Full NES fractional/frame-trace parity is not claimed.

## Restore pipe exit sound - 2026-11-02

Restored the standard PipeEnter activation sound during emergence at the user's request, superseding the entry-only sound suppression. Travel animation and control timing are unchanged. Updated the pipe guide, verification guide and decision record. The focused sideways pipe test passed, including exactly two sound starts across entry and emergence plus the existing timing checks. Replacing separate arrival markers with destination-pipe routing remains discussion only.

## Preserve vertical pipe entry position and facing - 2026-11-02

Removed emergence audio again at the user's request. Vertical entry now preserves the accepted horizontal position and facing instead of centering and turning right. Alignment gates, sideways travel, upward-exit facing and control timing are unchanged. Updated current pipe/verification guides and recorded the superseding decision. Focused pipe_entry, pipe_transfer and sideways_pipe tests passed without engine warnings/errors; entry coverage checks left-facing descent at X=110 and right-facing descent at X=114 around a mouth centered at X=112, including cancellation/shutdown. No project/input/import settings changed.

## Explicit shared transport and return pipe near stage start - 2026-11-02

Added BaseLevel.transport(player, destination, source = null), TransportDestination area/target resources, per-cell TransportPlacement configuration and TransportEntity/PlayerTransportState contracts. Reused the existing player/FSM, pipe scene, pipe travel state, camera handoff and area progress lifecycle. Pipe entities now call the shared API; the selected destination entity supplies its exit position/direction/presentation. Area metadata resolves exact targets while runtime entities are unloaded. Missing/duplicate/disabled/removed/stale destinations reject or cancel safely. Legacy PipeRoute resources, standalone spawns and scripted placement wrappers remain compatible.

Added an exit-only upright pipe at MainArea cell (4,11), ID stage_return, with final feet (80,176). The secret area's existing sideways return explicitly targets main/stage_return; the original main entrance still leads to lower/arrival. Removed the old pipe_return marker beside that original entrance. Existing stage artwork/cells are retained except for adding the new marker in a verified clear footprint. No new area/camera or project/input/import/shader setting changes. Current architecture, transport, pipe, area, entity-layout, state-machine, verification and scene-settings guides describe the final implementation.

Verification: all 25 regression scenes passed without engine errors or warnings. New transport_test saves/reloads per-cell resources and exercises a non-pipe presentation, moved target geometry, explicit selection, exit-only permissions, wrong/detached source/player handling, empty/missing/duplicate/stale IDs and removed destinations without loading them. Updated sideways_pipe_test verifies the actual secret return reaches the new start pipe without an adjacent marker, with preserved 80/96-tick timing, entry-only audio, collision/control/draw restoration and area unloading. Flat-floor/gap fixtures now remove authored stage obstacles so the added pipe does not redefine movement tests. A Forward+ D3D12 preview passed and start/entry/emergence/completion images were inspected. Whitespace check passed. Vines, a custom per-cell Inspector, asynchronous loading and disk persistence remain unimplemented.

## Secret return to the real PlayerSpawn - 2026-11-02

Changed the secret return destination to main/player_spawn, resolving the existing Players/PlayerSpawn marker directly rather than an exit pipe. Removed the temporary start return pipe and its placement configuration. Arrival now restores control and the main camera immediately after entry, with no emergence. Updated current transport/pipe guides, README, verification, decisions and scene settings. Kept pipe emergence coverage in an isolated fixture. Focused spawn_return, sideways_pipe, transport and pipe_entry tests passed without engine errors/warnings; the new test moves PlayerSpawn while MainArea is unloaded and confirms return follows it. Full suite was not rerun for this scoped change.

## Visual world-left/right editor guides - 2026-11-02

LevelCamera now runs editor-only guide drawing through @tool and Engine.is_editor_hint(). Bounds setters and transform notifications update labeled green/orange vertical lines at global World Left/Right, with a per-camera Draw World Bounds toggle. Existing follow/clamp calculations and configured bounds are unchanged. Updated camera and scene-settings documentation. Camera bounds/follow regression scenes passed without engine errors/warnings. A rendered tool-mode harness showed guides updating after property/transform changes; its custom editor teardown produced editor/RID cleanup warnings. A separate normal Forward+ editor startup/shutdown completed cleanly. No new project/input/import settings or runtime visuals.

## Reliability audit before death and UI work - 2026-11-02

Reviewed all Mario movement-state transitions, FSM lifecycle/input gates, camera integration, collisions, transport phases, area unloading/progress and shared session ownership. The baseline suite found the two sample endpoints saved under the level root again, breaking area-streaming/routing checks. Repaired their parents, retained Godot-generated IDs in BaseArea and used the native saved parent identity paths. Native editor-state save/reload checks preserve both endpoints and every painted layout across three cycles. Required inherited container names remain part of the project contract; arbitrary rename/reparent workflows are not qualified.

A new instrumented 44-case movement regression reproduced transition-only physics ticks when entering/cancelling Slide or handing Idle/Slide to passive falling, plus delayed first-input acceleration from Idle. Generalized PlayerState.continue_jump_physics into continue_physics and used it only before body integration. Landing, stopping and skid completion still return their next state after movement, avoiding double integration. Tests cover both directions with Run on/off, exactly one move_body call, first-tick acceleration, falling gravity, displacement matching velocity and camera movement. Shutdown from a state-change observer prevents further movement and detaches input.

Transport lifecycle tests reproduced stale session writes when a session observer replaces the level mid-handoff, and duplicate queued completion skipping emergence. Recheck ownership between notifications and before resuming travel; bind completions to a phase identity invalidated on disconnect/cancellation. Existing entry/exit timing, sound policy, direct PlayerSpawn return, collision restoration and per-cell routing remain unchanged. The generic transport test now records normal-state restart separately from later ordinary landing transitions. The skid fixture allows queued audio cleanup to complete before application exit; strict warning rejection is unchanged.

Verification: all 29 regression scenes passed without SCRIPT ERROR, ERROR or WARNING output. The new movement test also passed with Forward+ D3D12 rendering, and normal editor opening of TestLevel completed cleanly. After matching serialized endpoint identity paths to native output, focused scene-hierarchy, streaming and routing checks passed again. Whitespace and documentation link checks passed. Documentation covers the movement integration contract, transport callback ownership, scene identity and verification. No movement tuning, project/input/import/shader settings, death behavior or UI features were added. These checks establish automated behavior and cleanup coverage, not exact NES frame-trace equivalence or subjective controller/display pacing qualification. An already-open editor must reload the repaired scene before saving.

## Stop one-way camera drift during pipe-side hops - 2026-11-02

Reproduced rightward camera creep while holding Right into a pipe and repeatedly making short hops. In the diagnostic trace, the body oscillated across roughly 0.076 pixels of X while the camera accumulated about 1.98 pixels across four hops. The camera counted each positive half of collision-recovery jitter without undoing the negative half.

LevelCamera now counts only new forward territory beyond its furthest tracked target X. Retreating/retracing the same space cannot accumulate scroll; reset_target/snap_to_arrival reset that history, and follow-disabled cameras continue updating their baseline. Fractional steps, 80/112 scroll thresholds, world bounds, movement/collision values and interpolation settings are unchanged. The original four-hop trace now reports zero camera drift with the same body-position range.

Added camera_wall_jump_test for short, still-blocked hops from both sides at walk/run speeds, followed by full jumps that clear the pipe and resume normal rightward scrolling. Extended camera_follow_test with repeated backward/forward retracing and new-progress assertions. Hop input/sampling uses completed physics steps so a slow render frame cannot extend a tap; the existing exact sideways-pipe timing test now also counts completed physics steps and explicitly awaits deferred handoffs instead of conflating render waits with physics ticks.

Verification: all 30 regression scenes passed without engine errors or warnings. The pipe-hop regression also passed under Forward+ D3D12; rendered before/after views were inspected and background/pipe alignment remained stable. Whitespace check passed. Updated camera/verification guides and decision record. No Project Settings, Input Map, import parameters, collision geometry or player physics tuning changed. The fix addresses reproduced camera drift; exact NES frame-trace equivalence and all possible display-frame artifacts are not claimed.

## Theme soundtrack lifecycle and silent test areas - 2026-11-02

Added optional Music, Music Loop (default true) and Music Volume Db (default 0) to AreaTheme. Overworld selects assets/soundtrack/01. Ground Theme.mp3; Underground selects assets/soundtrack/02. Underground Theme.mp3. BaseLevelArea.enter_area/exit_area own an independent non-positional music player. Startup enters MainArea; committed cross-area travel exits/unloads the source before entering the destination. Preloading is silent, same-area travel keeps playing, and return visits restart the track. Unload, terminal level shutdown and tree removal stop/clean playback. Runtime stream copies enable loops without changing source/import settings; late completion from an old player cannot restart the current one.

Added per-area Music Enabled (default true) at the user's request. Disabled areas keep their theme artwork without a soundtrack, and toggling while active stops/starts playback. Missing music is silent. Automated non-music checks inherit silent_game/silent_level fixtures using this flag; the playable stage remains music-enabled. These fixtures avoid unrelated active MP3 streams at immediate application exit. A dedicated real-track test retains music-enabled startup, transport, same-area travel, toggling, settings, SFX separation and replacement coverage.

Verification: all 31 regression scenes passed without engine errors or warnings. area_music_test decodes both supplied tracks to nonzero samples, checks copied stream loop flags and unchanged imported streams, verifies source-stop-before-destination-start, silent preloading/disabled areas, no SFX interruption, runtime theme replacement and volume/loop overrides, level replacement during transport notifications, shutdown and tree-removal cleanup. Initial immediate-exit failures in older tests retained MP3/playback references; silent fixtures resolve that while the real-music test allows audio cleanup before quit. Documentation file links and whitespace checks passed. Updated area/theme/transport/pipe guides, architecture, README, decisions, verification and scene settings. No Project Settings, Input Map, audio buses or existing import parameters changed. Speaker/device output, crossfades, saved playback positions and death-specific music policy were not qualified or added.

## Remove example endpoint markers from the playable level - 2026-11-02

Removed near_start and near_end plus their unused PackedScene reference from TestLevel. The routing and native scene-hierarchy tests now create owned named endpoints through tests/fixtures/named_endpoints.gd; the hierarchy test first asserts that the playable Endpoints container is empty. Area-streaming checks return through the real player_spawn target. Updated current area/transport guides. Focused scene_hierarchy, pipe_routing, area_streaming and spawn_return checks passed without engine errors/warnings. The complete suite was not rerun for this scoped cleanup.

## Same-tick landing recovery over a stepped gap - 2026-11-02

Reproduced intermittent loss of running speed across a two-tile gap onto a sideways pipe one tile below the source platform. Feet could start above the pipe and cross its top in one physics step; correction previously waited until they were already below the top, allowing the diagonal side collision to cancel momentum first. CornerCorrection now handles that crossing immediately. The existing four-pixel penetration limit, real projected overlap, clearance checks and movement coefficients remain unchanged.

Added stepped_gap_test using actual brick/pipe entities at eleven subpixel starting phases in both directions, and extended corner_correction_test with same-tick crossings. The new regression passed headlessly and under Forward+ D3D12 rendering. The full 32-scene run passed 31 checks and exposed a pipe-entry test baseline assumption: descent was measured from pre-entry floor contact rather than the aligned pipe mouth. The test now explicitly checks mouth alignment and measures travel from that position; its focused rerun passed without errors or warnings. Thus all 32 checks passed across the suite and focused rerun. Whitespace check passed. No project/import settings, collision dimensions or movement tuning changed; interactive feel still merits playtesting.

## Record next death and entity-activity milestones - 2026-11-02

Documentation only: recorded the planned BaseLevel death lifecycle, below-viewport trigger, player-owned presentation, initial PlayerSpawn restart, and agreed reset_progress_on_death flag (default true). Defined its world-progress scope separately from score/lives/power-ups and noted snapshot ordering requirements. Recorded proposed off-camera suspension/disposal/deferred-activation policies, CPU versus memory implications, lifecycle/collision safeguards, open decisions and future checks. Added the plan to README and decisions. No runtime code, settings or scenes changed; feature tests were not run for this planning update.

## Complete supplied Underground artwork wiring - 2026-11-02

Mapped all 18 supplied Underground PNG counterparts in assets/themes/underground.tres, including all question-block animation/used frames and ten pipe sections. Updated Underground terrain and entity-marker textures; extended scripts/build_pipe_marker.gd to build exact-pixel 2x2 previews for both themes. Added the previously unused solid block as terrain source 11 in both themes, preserving existing IDs, collision definitions and painted cells. LowerArea already selects Underground and requires no scene override. Decorations retain Overworld fallback because no Underground decoration artwork was supplied; Mario remains unchanged.

Verification: matching source/replacement dimensions checked; expanded area_theme_test passed, covering all mappings, terrain collisions, both pipe entities, question animation and used state, themed markers, source isolation and cleanup. Focused sideways_pipe, question_block and area_streaming checks passed without engine errors/warnings. Godot editor import and an actual LowerArea Forward+ D3D12 render completed cleanly; the rendered room was inspected. Full-suite testing was not repeated for this artwork-only scope. Updated theme guide, README and verification coverage. No existing import parameters, Project Settings, physics tuning or level painting changed.

## Defer area music pending suitable soundtrack files - 2026-11-03

Removed area soundtrack playback, AreaTheme music fields/assignments and the per-area Music Enabled override at the user's request. Kept generic enter_area/exit_area occupancy lifecycle, transport/streaming behavior, entity SFX and unassigned soundtrack assets. Retained shared fixture paths without music overrides; area_music_test now verifies silent lifecycle entry, preloading, transfer and shutdown. Added docs/backlog.md with asset prerequisites, audible loop validation, proposed ownership, open audio/death policies and acceptance checks for future restoration. Updated current guides and the death plan; historical implementation records remain intact.

Verification: all 32 regression scenes passed without engine errors or warnings. Godot editor loading, documentation file links and whitespace checks passed. No Project Settings or existing import parameters changed. Music restoration remains deferred until suitable files are available.

## Pit death lifecycle, world suspension and progress-aware restart - 2026-11-03

Implemented BaseLevel.on_death and post-movement detection below the active camera bottom plus a 2px margin using the player's stable collision envelope. Death accepts once, blocks transport/camera tracking, suspends other entity gameplay and removes the off-screen player through terminal cleanup. Entity suspension gates FSM frame/physics/input/animation-finished paths and transitions, retains prior component physics flags for resumption, and allows cosmetic AnimationPlayer playback. Blocks reject hits while suspended. BasePlayer supplies an optional player-owned presentation contract; no visible Mario hit-death animation is assigned.

BaseLevel plays assets/soundtrack/smb_mariodie.wav on an independent one-shot runtime copy, so player removal cannot cut it off. Completion waits for presentation and sound, with missing-audio fallback and a bounded watchdog. GameHandler retains the loaded PackedScene and restarts at the real PlayerSpawn. Its global reset_progress_on_death=false preserves named-level world progress by default, superseding the per-level proposal. Shutdown saves the latest active-area snapshot before optional level-key clearing; inactive snapshots follow the same policy. No lives/counter deduction occurs. Coins are not implemented yet. General off-camera enemy activation/disposal and area soundtrack restoration remain deferred.

Verification: the 33-scene full run passed 32 checks and exposed the intentional continued-falling wide-gap fixture accessing a player now correctly removed by death. Disabled fall detection only in that fixture; its focused rerun passed. Expanded death_test passed under Forward+ D3D12, covering both cameras, partial/full visibility, duplicate/transport rejection, player cleanup/freeing, suspension with continuing animation, optional presentation, the real one-shot jingle through completion, global reset/preservation across areas, unchanged lives, PlayerSpawn restart and stale level ownership. Thus all 33 checks passed across the suite and focused reruns without remaining engine errors/warnings. Editor script loading, documentation file links and whitespace checks passed. Test audio diagnostic references are released and queued cleanup allowed before exit. No Project Settings, Input Map or existing import parameters changed. Audible speaker output and exact NES frame-trace equivalence were not qualified. Updated README, architecture, death guide, plans/backlog, decisions, settings and verification.

## Reference-informed pit cutoff depth - 2026-11-03

At the user's request, moved pit death two tiles farther below the camera by changing BaseLevel fall_death_margin from 2 to 34 pixels. Small Mario now triggers after feet pass viewport bottom +48, approximately translating the reference's 32px drawing envelope and vertical-page threshold. Player cleanup remains immediate at detection; sound and progress-aware restart behavior are unchanged. Extended death_test to check below-screen survival through the new boundary and death just beyond it in both area cameras. The focused death regression passed without errors/warnings; full-suite tests were not repeated for this tuning-only change. Updated death guide/settings; whitespace check passed.

## Persistent 8x8 HUD and screen layer - 2026-11-03

Added scenes/ui/ui.tscn under Game as a CanvasLayer sibling of LevelContainer. Its ScreenContainer reserves space for future transition screens beneath one persistent HUD. Added an 8px BMFont definition over the supplied alphabet texture, shared HUD Theme, reference-positioned static player/score/coin/world/time labels and nearest-filtered 8x8 coin animation from the supplied Overworld atlas. Frame durations adapt the reference's bright/medium/dark/medium palette cadence (24/8/8/8 ticks at 60Hz). No live value bindings or area-themed HUD switching were added. Existing level reloads leave the HUD intact; world camera/shadow/suspension do not affect it.

Verification: all 34 regression scenes passed without engine errors/warnings. hud_test verifies glyph advances/grid, static values, coin playback and timing, mouse pass-through, persistence across camera/area/level changes and transition layering. Forward+ D3D12 gameplay and black transition previews were rendered and visually inspected; text/coin remained crisp and aligned. Editor loading, documentation file links and whitespace checks passed. Updated README, architecture, UI guide, decisions, settings and verification. No existing import parameters, Project Settings, gameplay values or scene painting changed. Transition content was exercised with a test overlay; actual transition screens remain future work.

## One shadow behind world, HUD and foreground player - 2026-11-03

User clarification requires one combined foreground mask, with Mario above UI and all shadows behind foreground. Added Game/SharedShadow with render-only CanvasItem routing for LevelContainer, screen-space UI and Players, preserving logical scene parents and physics ownership. Game/UI becomes a camera-compensated Control with interpolation disabled locally; frame_pre_draw uses the final camera canvas transform. The level's authored shadow material drives the persistent compositor while its nested runtime group is disabled; standalone level previews retain the original group/material. Pipe travel temporarily routes Players below world artwork and restores foreground order on completion. Shader tuning and gameplay physics remain unchanged.

Verification: the 35-scene full run passed 34 checks; hud_test initially queried its render transform before headless synchronization. Explicit render sync in that test resolved the assumption, and the focused rerun passed. All 35 checks therefore passed across the suite and rerun without remaining errors/warnings. Forward+ D3D12 pixel assertions verify player-over-HUD occlusion, undarkened opaque HUD/world foreground, HUD-cast shadow, fractional-camera stability, pipe mode and level replacement. Actual gameplay/Mario-over-HUD and transition renders were inspected; rendered sideways pipe travel passed. Documentation links and whitespace checks passed. Updated UI/shadow/architecture guides, README, decisions, settings and verification. No Project Settings, import parameters, player motion values or level painting changed. CanvasLayer/alternate-Z contributors and dynamically transformed player containers require separate qualification; target-device profiling remains pending.

## Stabilize HUD during camera speed changes - 2026-11-03

Following reported fragmentation, moved the persistent Game render canvas to screen space (CanvasLayer layer 0). UI no longer counter-moves with the camera: its transform remains identity. The compositor submits the final viewport camera matrix only to world/player render roots and disables additional interpolation on those individual proxy RIDs; native descendant-body interpolation and all physics transforms remain unchanged. Existing combined shadow, player-over-HUD order and pipe draw routing are preserved. No shader tuning, camera thresholds, movement values, Project Settings or import parameters changed.

Added hud_scroll_test for physics-driven acceleration/braking at independent render rates. Initial whole-image comparisons also counted clouds moving through transparent HUD gaps; the final test compares every fixed foreground glyph pixel, excludes the animated coin and explicitly skips pixel assertions headlessly. The original isolated/manual camera test was insufficient to qualify scrolling. Final Forward+ D3D12 scrolling checks passed at 45 and 144 FPS; a 120 FPS check also passed during development. Rendered HUD, shared-shadow overlap, pipe-side camera hops and sideways pipe travel checks passed. Full-suite run passed 35 of 36 scenes, with one bonk_contact assertion failing at X=72; its focused rerun passed without code changes. That intermittent fixture failure is recorded rather than treated as a reproduced renderer physics defect. All scene checks therefore have passing evidence across suite/focused runs, but the full run was not uniformly green. Documentation file links and whitespace checks passed. Updated UI/shadow/architecture guides, decisions, settings and verification. User playtesting remains necessary to confirm the reported display artifact is resolved on their setup.

## Shared clock for cosmetic palette animation - 2026-11-03

Added CosmeticAnimationClock under existing GameHandler, shared CosmeticAnimationCycle resources and SynchronizedAnimation adapters for AnimationPlayer/AnimatedSprite2D. One clock advances per physics tick and notifies resource/offset groups only on phase changes. Registration immediately samples current phase, so late-loaded/themed objects join the global 24/8/8/8 cycle. HUD coin uses an always-enabled adapter; question Active binds an adapter through BaseState and releases it before bounce/used presentation. Entity shutdown and tree exit unsubscribe; empty groups release references. Cosmetic phase continues through gameplay suspension, death, area/level changes and session clearing. Local player/action animation stays independent. Future world coins can reuse the component; no coin entity/pickup/counter functionality is added.

Verification: all 37 regression scenes passed without engine errors/warnings. New animation_clock_test covers exact phase boundaries/wrap, late Underground joins, suspension, bounce/used ownership, terminal cleanup and clock continuity. Its Forward+ D3D12 branch spawned a block mid-cycle and verified agreement with the HUD during rendered updates. Existing HUD/question/death tests now assert sampled phase rather than independent native playback. Documentation file links and whitespace checks passed. Updated clock guide, current UI/block/state/lifecycle guides, architecture, README, decisions, settings and verification. No Project Settings, new autoload registrations, existing import parameters or movement tuning changed.

## Reference-derived grounded Run release - 2026-11-03

Implemented the requested same-direction grounded release rule: RunAction retains a 10-tick countdown loaded while running, BasePlayer decrements it once before FSM physics, and release ticks 1-9 retain the run profile before the effective walk cap applies on tick 10. HorizontalMovement now clamps only the directional side it accelerates toward; neutral braking, Slide and AirMovement retain ownership of their cases. Existing caps/coefficients remain unchanged. Run preparation does not advance time during same-tick state handoffs. A re-press reloads the timer, while a jump on the expiry tick retains fast air momentum. Higher-priority level caps still apply. This scopes source parity to the retention/cap rule, not every fixed-point or friction-history branch.

Verification: all 38 regression scenes passed without engine errors/warnings. New run_release_test checks both directions, exact timer boundary and velocity, re-press, neutral/slide cases, effective-cap precedence, Idle-to-Move preparation and expiry-tick jump behavior. It also passed under Forward+ D3D12 at a 144 FPS cap with 60Hz physics. Updated the existing movement expectation for retained Run and reset timer history between independent manually teleported handoff cases. Displacement assertions use the existing 0.1px contact-recovery tolerance; timer/speed assertions remain exact. Documentation file links and whitespace checks passed. Updated movement, decisions, settings and verification. No Project Settings, imports, input bindings, camera tuning or movement coefficients changed.

## Global transition lifecycle - 2026-11-03

Added GameHandler-owned TransitionCoordinator and persistent TransitionScreen. Startup and death restart use quick black, loading splash, quick black, gameplay; pipes use quick black only. Quick phases hide HUD and player so destination/theme swaps are covered. Work starts after a rendered cover acknowledgement, with configurable 12-tick quick and 147-tick card minima, gameplay/input suspension and cancellation-safe restoration. Preserved immediate loading compatibility and progress semantics. Changed suspension snapshots to weak references so freed scene/audio nodes cannot leave invalid typed keys. Splash world/lives values remain placeholders; no threaded disk loader was added.

Verification: all 39 regression scenes passed without engine errors/warnings. Forward+ D3D12 transition_test passed with black-cover pixel assertions and quick/splash screenshots. Updated transition, UI, transport, pipe, death, architecture, settings, decisions and verification documentation. No Project Settings, input bindings or existing asset import settings changed.

## Neutral ground braking and airborne history - 2026-11-03

Corrected RunAction's neutral profile to select friction from speed and retained running history instead of whether Run remains held. Both release orders now preserve gradual reference-derived braking without an overspeed walk clamp. Retained the B-only low-speed stop and facing-mismatch multiplier. Passed running history explicitly into Jump and passive-fall AirMovement capture; neutral air momentum and directional braking remain separate from ground friction. Added both-direction release-order, low-speed history and air reversal assertions. Clarified that the original blanks background/sprite output rather than drawing an overlay. No Project Settings, imports or input mappings changed.

Verification: the full 39-scene run passed 37 scenes and exposed two obsolete friction expectations in air_movement_test and slide_test. Updated those expectations for the corrected neutral behavior, separated immediate skid modifier cleanup from the following Idle profile tick, and reran both successfully. Thus all 39 scenes have passing evidence across suite/focused runs; the original full run itself was not uniformly green. run_release_test also passed under Forward+ D3D12 at a 144 FPS cap. Whitespace checks passed. Exact fixed-point parity and subjective movement feel remain unqualified.

## High-refresh camera pacing investigation - 2026-11-03

Inspected physics follow, interpolation and shared render routing after an intermittent hitch report on a 240 Hz monitor. Added an opt-in tools/diagnostics/frame_pacing_probe scene for sixty-second normal-play CSV capture or controlled automatic traversal. It is not attached during ordinary gameplay and does not modify project settings. A temporary probe found interpolated camera agreement within about 0.000062 logical pixels. The checked-in automatic probe captured 2,400 frames over ten seconds at a 240 FPS cap (median 4.167 ms, p99 4.628 ms, max 4.888 ms). A five-second normal-game startup/playable-mode smoke capture also passed without engine errors. These off-screen host render measurements did not reproduce the reported hitch and do not establish physical monitor pacing. Added capture instructions and an open backlog item; no gameplay fix or full-suite rerun is claimed.

## Underground HUD coin and ledge-camera follow-up - 2026-11-03

Mapped the supplied Underground 24x8 HUD coin atlas through AreaTheme.texture_overrides. Added persistent HUD theme subscriptions and private SpriteFrames/AtlasTexture artwork updates, retaining the global clock phase, regions and cadence. Missing artwork falls back to Overworld; level reload restores its active theme. No Input Map, import or Project Settings changes were made. Updated UI/theme/animation/transition guides and the theme inventory to nineteen mappings.

Investigated the report that camera hitches cluster around jumps onto pipes/blocks. New ledge_camera_test passed 72 controlled Jump-state contacts at block/pipe widths, walk/run speeds, both directions and multiple contact phases/depths under Forward+ D3D12 at a 240 FPS cap. Each retained one horizontal step and the expected camera displacement. This is static geometry coverage, not a reproduction of the intermittent rendered hitch or every real entity interaction. No movement or camera fix is claimed. Extended the opt-in pacing capture with body displacement, native sweep displacement, velocity, floor contact and state; a three-second rendered capture passed.

Verification: the full forty-scene run passed thirty-eight scenes. area_theme_test initially expected eighteen mappings; after updating the expected inventory to nineteen, its focused rerun passed. bonk_contact_test failed at X=72 during the suite and passed its unchanged focused rerun; intermittent fixture behavior remains unresolved. Thus all forty scenes have passing evidence across suite/focused runs, not a uniformly green full run. Extended hud_test passed headlessly and rendered at a 240 FPS cap, checking Underground/fallback/reload, resource isolation and phase preservation; its Underground screenshot was inspected. Documentation local links and whitespace checks passed.

## Regression failure investigation and clean verification - 2026-11-03

Resolved the intermittent bonk fixture failure by moving actual character sweeps from a render-frame continuation into a physics callback, preserving every existing edge/seam assertion. The original test reproduced X=72 failure at 240 FPS; the corrected version passed eight headless stress runs across 45/60/144/240 FPS caps and a rendered 240 FPS run. The Underground theme inventory expectation now includes the nineteenth mapping. No gameplay collision rules were relaxed.

Investigated additional post-PASS nonzero exits rather than ignoring them. Windows recorded native access violations (0xC0000005); an empty scene with project autoloads reproduced one failure in thirty launches. Changed GameHandler to load TransitionCoordinator at runtime, breaking its static script dependency back through GameHandler/BaseLevel. The empty-scene probe then completed one hundred launches without failure. Removed unsuccessful teardown-wait experiments. The runner now prints failing engine exit codes and still rejects all nonzero exits.

The subsequent complete forty-scene run passed without engine errors, warnings or nonzero exits. A final rendered 240 FPS check exposed the transition fixture's render-frame timeout (180 frames = 0.75 seconds) expiring before its 0.8-second pipe entry. Changed the timeout to physics ticks; the updated transition test passed headlessly and rendered at 240 FPS. Documentation UTF-8/file-link and whitespace checks passed; corrected one mixed-encoding superscript in the movement guide. The intermittent user-visible camera hitch remains unconfirmed and separate from these fixture/shutdown issues. No Project Settings, input mappings or existing asset imports changed.

## Shared sound-effect balancing - 2026-11-03

User requested consistent levels for jumping, skidding and the death jingle. Measured all five active decoded recordings and applied non-destructive playback gains through assets/audio/sound_effect_mix.tres: common -3 dB plus jump 0, bump -4, pipe -1.5, skid -3.5 and death -5 dB trims. Skid measurement uses the repeatedly retriggered first 100ms. BaseEntity and BaseLevel death playback share the mix; private one-shot copies retain source-path identity through SoundEffectMix.one_shot_copy. Original files/import settings, pitch, durations, skid cadence, cancellation rules and gameplay timing remain unchanged. Added editable mix guidance and before/after local audition previews. Existing user edits to Underground theme and transition screen were left untouched.

Verification: sound_mix_test passed headlessly and under Forward+ D3D12 at a 240 FPS cap, checking effective gains, nested source identity, duration/loop preservation, pitch, cancellation, repeated skids, pipe-state copies and death audio. The complete 41-scene run passed forty scenes; scene_hierarchy_test printed PASS but exited with a native access violation (-1073741819). Its unchanged focused rerun passed with exit zero. This means the earlier dependency correction did not eliminate every native shutdown failure; tracked a separate open follow-up rather than claiming a clean full suite. Automated gain checks are not subjective listening qualification. Documentation links/encoding and whitespace are checked separately. No Project Settings, Input Map, existing imports, source recordings or audio buses changed.

## Named transition definitions and Cover removal - 2026-11-03

User authorized removing the Cover node and preparing the coordinator for future transition types without implementing those screens yet. Removed the fullscreen ColorRect and extracted the existing user-authored intro layout into scenes/ui/transitions/level_intro.tscn, preserving its bitmap theme. TransitionScreen is now a generic Control presentation host. Named TransitionDefinition/TransitionStage resources configure initial hold, background, timed scenes, HUD visibility and expected level replacement. Shipped area/level definitions retain 12-tick quick phases and the 147-tick intro. Existing callers keep their IDs; the coordinator no longer branches on level identity or Card node paths. Runtime configuration is isolated from shared assets and snapshotted per request. Unknown/duplicate/invalid registrations are rejected; invalid presentation roots and initialization-time cancellation restore state safely.

Blanking hides world/player/HUD and temporarily selects the renderer's clear color; it saves/restores the prior runtime value on success, failure, cancellation and detach. This process-wide default assumes one active Game and does not write Project Settings. Additional viewport policies, game-over flow, menu input and session decisions remain deferred. No new transition type beyond area/level was shipped.

Verification: expanded transition_test passed headlessly and under Forward+ D3D12 at a 240 FPS cap, exercising arbitrary registered presentations, timing/HUD/background, active snapshots, resource isolation, custom replacement permission, rejection, cancellation during scene initialization, existing loading/pipe/death sequences and black pixels with no Cover node. Quick and intro screenshots were inspected. The full 41-scene run passed forty scenes; scene_hierarchy_test again printed PASS then exited with native access violation -1073741819. The full run remains failed; the existing native-shutdown backlog item remains open. No movement, camera, input bindings, imports or persisted Project Settings changed. Existing SFX work and unrelated user theme edits remain in the workspace.

## Remove the imposed transition background - 2026-11-03

Corrected the interpretation of the request to remove Cover: removed the temporary renderer clear-color override as well as definition/stage background_color properties. Gameplay/HUD visibility, named transition types and presentations remain. Updated the current guides and superseding decisions. Rendered transition_test passed at a 240 FPS cap with a deliberately nonblack background, confirming unchanged background pixels and existing lifecycle/cancellation behavior. Screenshot assertions account for 8-bit color quantization. No project settings changed.

## Rename the connected stage and add an independent test screen - 2026-11-03

User requested renaming the existing test stage to 1-1 and creating a separate one-area, one-screen test level for later start-menu background use, without connecting it. Moved the existing stage to scenes/levels/1-1.tscn and renamed its root to 1-1, preserving every other serialized value including its UID, painted layouts, two areas, bounds and transport placements. Updated Game.initial_level and established regression fixtures/direct loads to keep using that stage.

Created scenes/levels/test_level.tscn as a direct BaseLevel sibling with a distinct UID, one Overworld MainArea, fixed camera (128,120), bounds 0/256, spawn (48,208), ground columns 0..15 at rows 13/14, and empty decorations, entity markers and transport placements. Reused the existing palette/resources for editor painting. The new scene is not referenced by Game, menus, transport routes or regression fixtures; F6 supports standalone preview/testing. Start-menu integration remains deferred. Updated current guides, preserving older historical names in past entries. No Project Settings, Input Map or imports changed.

Verification: exact serialized comparison confirmed the original stage changed only its root name; source UID retained and new test UID distinct. Reference scan confirmed no consumer points to the new sandbox. Native save/reload preserved its one-area 32-cell floor. Rendered standalone startup placed Mario on the floor with no Game/current-level attachment; screenshot inspected. Full 41-scene suite passed forty scenes; area_theme_test printed PASS then exited with native access violation -1073741819, matching the tracked shutdown issue. All other scenes, including transitions, death, pipes and hierarchy, passed. The full run remains failed. Documentation UTF-8/local links and whitespace checks passed.

## Single-player title flow without a demo - 2026-11-03

Implemented the user's requested first title milestone. GameHandler creates TitleScreen and immediately loads its exported TestLevel background without a startup transition. Mario is visible but gameplay-suspended, the background level's physics callback is disabled, and ControllerHandler remains available for menu input. TestLevel's direct F6 behavior is unchanged. The title contains only 1 PLAYER GAME using the existing white HUD Theme and the supplied 8x8 Overworld cursor; alphabet-alt is reserved for later copyright text. No demo, two-player menu, logo or additional title text was added. Existing HUD remains visible with its current placeholders.

Added GameFlow DETACHED/TITLE/STARTING/PLAYING ownership in GameHandler. Start accepts one request, consumes confirmation, hides the menu, clears session/progress after title-background shutdown and runs the existing level transition into 1-1. Success frees title UI and enables gameplay; cancelled recovery is deferred with weak Game ownership so closing a Game cannot recreate UI or mutate children during tree removal. Game.start_with_title defaults to true; direct gameplay fixtures explicitly opt out. User authorized control bindings: added start for Enter/keypad Enter and any-device gamepad Start/Menu (button 6), leaving existing actions and unbound Select intact. Held Enter cannot become a Jump on reveal. No black background/clear-color override, audio, physics or renderer setting changes were introduced.

Verification: title_test passed headlessly at 60/240 FPS caps and rendered under Forward+ D3D12 at 240, covering immediate startup, no demo, suspended Mario, white font/cursor, keyboard/raw controller Start, duplicate rejection, session reset, held-input consumption, fresh Jump, cancellation and detach. Screenshot inspected. The full 42-scene run had thirty-nine clean passes; controller_primary_test and death_test printed PASS then exited with native access violation -1073741819, and title_test printed PASS with a playback-resource cleanup warning. Updated the title fixture to let its verified one-shot Jump finish before player destruction; subsequent focused title checks passed without warnings. The full run remains failed and no clean rerun is claimed. Existing native shutdown tracking remains open. Documentation/UTF-8/local links and whitespace were checked separately.

## Title cursor follows the background area theme - 2026-11-03

Mapped the canonical Overworld title cursor through the active background area's AreaTheme, adding the supplied Underground cursor as the twentieth texture override. TitleScreen binds on startup/level/area changes and responds to the new BaseLevelArea.area_theme_changed signal after a selected theme is applied. Returning to Overworld or a null/missing mapping resets to the canonical cursor. The white menu font remains independent, and subscriptions are disconnected on exit. No background scene theme, input, Project Settings or imports were changed.

Verification: focused title_test and area_theme_test passed headlessly without engine errors/warnings; rendered title_test passed under Forward+ D3D12 at a 240 FPS cap. Coverage includes both presets, initial Underground binding, runtime selection, null/fallback, shared-resource isolation, retained white text and existing Start/cancel/cleanup behavior. Underground screenshot inspected. No full-suite rerun was performed for this focused artwork change; prior native shutdown limitations remain recorded above.

## Opt-in entity controller input - 2026-11-03

Implemented the requested first activity milestone only. BaseEntity.controller_input_enabled defaults false and synchronizes actual ControllerHandler subscriptions on initialization, live toggles, suspension/resume and shutdown, without duplicates. BasePlayer and PipeEntrance scenes explicitly opt in; Mario and sideways pipes inherit the choice. Player movement/Run/Jump and pipe entry polling honor the same capability; dead players cannot reconnect. Blocks retain normal collision/hit reactions. Tick scheduling, buffered off-camera suspension, enemy spawners and disposal remain planned. No measured net-memory claim is made; entities remain allocated. No Project Settings, Input Map or imports changed.

Verification: new entity_input_test passed headlessly and rendered under Forward+ D3D12 at a 240 FPS cap, covering default block/entity opt-out, explicit player/pipe opt-in, actual event delivery/connection counts, duplicate prevention, toggles, suspension, polling and terminal cleanup. The initial full run exposed the movement-handoff counting fixture replacing Mario's script and losing its scene controller flag; preserved that authored flag alongside the existing sprite/animation references, and all 44 handoff cases passed. Final full 43-scene run passed forty-two scenes; area_streaming_test printed PASS then exited with native access violation -1073741819. The run remains failed; the tracked shutdown issue is unresolved. Title, player controls, pipes, death, transitions and the new input test passed. Documentation UTF-8/local links and whitespace checks passed.

## 2026-11-03 - BaseArea camera activity and enemy spawner foundation

Implemented area-owned buffered activity using each area camera, with 64/96-pixel wake/sleep margins. Resident entities preserve instances, collision and progress while frame/physics/input/cosmetic work sleeps. Gameplay and activity gates are independent; synchronized animation resamples on wake. Added reusable EnemySpawner with one actor, terminal offscreen cleanup and reentry rearming, without placing enemies in shipped levels. Main paths: scenes/levels/areas/base_area.gd, scenes/entities/base/base_entity.gd, scenes/components/presentation/synchronized_animation.gd, scenes/entities/spawners, tests/entity_activity_test.*. Focused lifecycle assertions pass; full regression results are recorded in verification.md. Linear centralized scans and enemy-specific behavior/persistence remain limitations. No Project Settings/Input Map/import settings changed.

## 2026-11-04 - Shared player status and live UI

Added GameHandler-owned PlayerStatus for score, coins, lives and Small/Super/Fire form, with typed update methods, bounds and change-only notifications through the existing session signal. Legacy session keys route to the same owner. HUD score/coins/stage/time and intro stage/lives now read shared values; title adds TOP- with live six-digit top score in the existing white font. New games reset player status while retaining top score in memory. Area travel and current death restart preserve player status; loading an attempt resets level time/stage defaults. Only Small Mario exists; rewards, life loss/game over, countdown, transformations and top-score promotion/disk saving remain deferred. Added player_status_test and updated HUD assertions; final verification is recorded in verification.md. No Project Settings/Input Map/import changes were made.

## 2026-11-04 - Palette assets grouped under assets/palettes

Moved the complete Overworld (Palette 1) and Underground (Palette 2) folders to assets/palettes/overworld and assets/palettes/underground. Updated scenes, TileSets, animation resources, theme override keys/values, script constants/build paths, tests, current guides and font/import paths. Preserved current artwork byte-for-byte (including uncommitted Underground edits), existing import UIDs and semantic parameters; refreshed path-dependent import caches. Shared assets/themes and assets/tileset resources remain in place. Historical path descriptions above are retained as history. Verification results are recorded in verification.md.

## 2026-11-04 - GDScript readability cleanup and HUD theme subscription

Reviewed runtime lifecycle/input/status/theme code and applied safety-checked gdformat formatting across all 111 scripts; 94 files changed. Expanded compact branches, normalized indentation/operator spacing and line wrapping, separated methods/declaration groups and property blocks. Added .editorconfig GDScript defaults, gdformatrc and a development-only gdtoolkit pin, with commands in code-style.md. Syntax-tree/comment checks confirm 106 format-only scripts preserve their pre-cleanup behavior; HUD, GameHandler and their two UI tests additionally contain the targeted lifecycle fixes; transition_test extracts two equivalent callbacks into a named helper to avoid a gdformat/Godot indentation incompatibility.

Reproduced a stale HUD coin after live area-theme changes by removing the test's manual refresh calls. Fixed the missing theme-signal binding and added old-area disconnection assertions. Default lint findings fell from 416 to 135; remaining declaration-order, long diagnostic lines, repeated test loads and coordinator complexity are documented as follow-up, without suppressing rules. Existing standalone F6 death restart and native-shutdown backlog items remain open. Final regression results are recorded in verification.md. Existing user artwork/scene edits were preserved; no Project Settings, Input Map or import parameters changed.

The cleanup run also exposed a stale title assertion after the sandbox gained painted blocks. Title gameplay suspension now includes all existing background entities, preserving cosmetic animations; the regression checks suspended behavior rather than forcing the authored layout empty. No painted scene data was changed.

## 2026-11-04 - Group playable levels by world

User requested worlds > world 1 > 1-1. Moved the stage unchanged to scenes/levels/worlds/world 1/1-1.tscn, preserving its scene UID, paint data and byte-for-byte content. Updated Game, stage-derived fixtures, test load/path assertions and current documentation. Shared base/area scenes and the title sandbox stay in their existing locations. Historical old-path descriptions are retained. No gameplay or Project Settings changes were made.

## 2026-11-04 - Death reduces shared lives

Connected accepted BaseLevel.on_death to GameHandler.set_lives(current - 1), with duplicate/reentrant protection and a post-signal ownership/shutdown guard. The existing loading-intro subscription displays the new counter. Expanded death coverage for both progress policies, invalid/duplicate requests, zero-life respawn, live intro values and synchronous replacement from a lives observer. No life deduction occurs in restart itself; game over remains deferred and new-game defaults stay unchanged. Updated current death/status/transition guides and README; executed results are recorded in verification.md.

## 2026-11-04 - Game over and single-level progress ownership

Added GAME_OVER flow, a timed game_over definition/card and one-shot supplied jingle, optional bounded presentation completion, explicit shutdown-before-clear and safe title return. Reserve lives now start at 2 and display 3, with zero still playable and -1 ending the run. GameHandler stores only the selected level's area snapshots; different levels clear after old shutdown, same-level death/areas retain, and stale instances cannot overwrite a later visit. Added a Start release gate and corrected external transition-cancellation flags. Added game_over_test and level_progress_test, updated status/death assertions, and documented current ownership/limits. No new autoload, Project Settings, Input Map, background override or source-audio/import changes were introduced. Final checks are recorded in verification.md.


## 2026-11-04 - Two-pass shared shadow experiment

After the user reported no drops with the effect disabled, replaced Game's CanvasGroup blur with a transparent foreground capture, horizontal alpha pass and vertical/composite pass. Retained the original Gaussian weights, sharp foreground, shadow tuning, input/physics scene ownership and diagnostic toggle. Added padded logical-resolution buffers, same-frame/numerical image checks and opt-in legacy/two-pass/off profiling with viewport timings/compilation counts. Standalone/editor levels retain the original reference shader. Updated shadow, frame-pacing, architecture and settings guides. Local rendered comparisons show lower GPU time with extra CPU cost; the reported hitch was not reproduced automatically and needs user playtesting. Full regression and pre-change audio-warning comparison are recorded in verification.md.


## 2026-11-04 - Reference edge skids and title-owned progress cleanup

Restored KeepOnscr's inward-input exception so clamped screen-edge reversal skids retain momentum. Solid-wall contact explicitly stops velocity into the surface, while Slide preserves its collision-frame pose and resolves the stop on the next tick. Added live collision/edge coverage and updated boundary expectations. Moved cache disposal out of game-over retirement and flow-specific loading into common show_title after outgoing shutdown; the card retains the final snapshot, including before a same-scene TestLevel-to-title return. Game detach preserves the final snapshot rather than applying game-over-specific cleanup. Updated lifecycle/camera guides and progress/game-over regressions. Settings, bindings, physics rate and renderer configuration were unchanged by this milestone.


## 2026-11-04 - Remove duplicate 1-1 scene

User approved removing scenes/levels/1-1.tscn after duplicate scene paths caused editor boundary changes to differ from Game's loaded stage. Verified serialized paint data matches the canonical scenes/levels/worlds/world 1/1-1.tscn and preserved the removed file in ignored validation storage before deleting it. The world-folder scene retains its UID, corrected secret_exit route, World Right=2624 and existing unsmoothed camera configuration. No runtime references point to the removed path. Close any old editor tab without saving it again; future edits use the canonical scene.


## 2026-11-04 - Stage completion foundation and Warp mode

Added Game's ordered Stages list, GameHandler stage index/COMPLETING flow and BaseLevel.on_complete lifecycle. Stage progression retains player/session status, resets the departed visit after final shutdown, and uses existing destination intros; the last or an unlisted stage returns through common title entry and a short finish transition. Added explicit-destination Warp mode with the requested destination intro retained, and no completion fanfare implemented yet. Reused coordinator suspension/cancellation/ownership and preserved title background freeze after restoration. Added completion integration coverage, migrated Game/fixture scene configuration, and retained the non-exported initial_level compatibility API. No triggers or timer countdown were added; timer work is next before ending triggers. Executed checks are recorded in verification.md.


## 2026-11-04 - Full run reset on common title entry

User requested that the shared back-to-title callback clear all run state, retaining only in-memory top score. _show_title_now now calls the existing clear_session after outgoing shutdown instead of clearing only level progress. clear_session also resets pending startup target and stage index. Startup captures its requested scene locally before reset so alternate-stage launches still work. Player status, custom session and progress reset on both final-stage and game-over returns; top score and authored stage/configuration data survive. Updated current guides and return-path regressions. No bindings, imports or Project Settings changed.


## 2026-11-04 - Mario Dead state and visible death motion

Wired the supplied 16x16 mario-dead.png and MarioDeadState into the existing present=true death lifecycle. The state holds 16 ticks, launches with nominal reference death velocity/gravity, ignores controls/collision and finishes after its full sprite passes the active camera bottom. BaseLevel retains jingle, world suspension, exactly-once life loss, cleanup and respawn/game-over ownership. Added main/lower area and final-attempt presentation coverage; updated the older death-test title-lives assertion to the already accepted full title reset. No gameplay trigger or input binding was added. Test scene preview instructions and current ownership/limitations are in death.md; executed outcomes are in verification.md.

## 2026-11-04 - Level timer and timeout lifecycle

Added idempotent BaseLevel.on_level_start after intros, a 24-active-tick countdown, a complete interval at 000, and timeout routing through animated death then TIME UP before lives/game over. GameHandler.load_level remains the sole starting-value initializer. Added per-level Timer Enabled and disabled TestLevel digits while retaining TIME. Preserved the shared world/HUD animation clock without resetting its phase. Added timer regression coverage; outcomes are recorded in verification.md. No settings/bindings/import changes or ending triggers.

## 2026-11-04 - Fixed flagpole and reusable manual climbing

Added BaseClimbable, player Motion/Climbing and script-based PlayerClimbState with a concrete Mario-owned Climb state and supplied two-frame animation. Added one 2x11 paint marker and a fixed assembly with normal solid collision on the palette tileset block base. Reused area theme/activity and shutdown behavior; the surface detects contacts through signals with no controller subscription or frame/physics polling. Nominal speeds and side timing follow the disassembly; manual flagpole control intentionally tests the vine-style foundation before future forced descent/completion. No authored stage painting, ending trigger, score/fanfare, bindings or Project Settings changes. See climbing.md and verification.md.

## 2026-11-04 - Retain flagpole attachment at the base

Replaced the temporary automatic bottom release with a motion clamp that preserves Climb and its attachment. A later ending controller must explicitly change state; death/transport/removal still clean up normally. Updated climbing regression and current guide. Reference investigation distinguishes forced flagpole descent from vine top-of-screen autoclimb/area transport; no upper-bound or vine transport behavior was changed. This supersedes the bottom-release behavior in the initial climbing milestone.

## 2026-11-04 - Climbing horizontal input and presentation

Clarified the requested controls: inward input switches sides, outward input releases to Move/passive falling, and a held switch direction cannot eject Mario on the next tick. Side swaps reset interpolation without leaving Climb; neutral/blocked movement freezes the current climb pose instead of repeatedly seeking the first frame. Release integrates normal motion on the same tick. Added physics/render-frame and state-transition assertions through middle/top/base side switches and both outward release directions. No settings or bindings changed.

## 2026-11-04 - Reliable shaft capture and initial idle pose

User reversed manual ejection: horizontal input no longer releases climbing. Stopped/blocked climbing again selects its first pose. Replaced feet-only capture with a thin shaft/body-envelope sweep before/after actual player movement, using queryable Area2D layer 8 and no solid shaft collision or entity polling. This catches base-block crossing and landing-edge contact without relying on delayed overlap notifications, and clears suppression on actual separation. Added dedicated capture regressions. This supersedes outward release and last-pose freeze from the previous climbing input milestone. No Project Settings or bindings changed.

## 2026-11-05 - Castle decorative parts and ending reference plan

Added Castle parts source 15 to Overworld and Underground decoration TileSets using the supplied 64x32 atlases, omitting empty (0,0) and preserving old source IDs. No level painting or collision was added. Updated existing theme regression for 16 sources and multi-cell atlas coordinate compatibility. Recorded proposed reference ending phases and explicit endpoint/player-removal exceptions; no ending sequence, scroll lock, fanfare or progression behavior was implemented.

## 2026-11-05 - Level-owned flagpole ending and covered title return

Implemented reusable ending presentation and scripted Mario state, common completion claim/finish lifecycle, owner-scoped camera lock, coordinated flag/Mario descent, timed dismount, normal-profile automatic walk, and player shutdown/removal at the independently configured castle endpoint. Added ticketed Score/Fireworks hooks that complete immediately by default and block progression while overridden work is pending. Wired supplied flagpole SFX and stage-clear music outside the player lifetime. Added final delay/music gate and retained existing stage-list/title cleanup. finish now has a quick outro and hides newly created title UI until its background is revealed; no black cover added. Expanded integration coverage for callbacks, cancellation, source loss, external replacement and title concealment. Actual reward conversion/firework visuals remain deferred. Run outcomes are in verification.md.

## 2026-11-05 - Silent sliding and visible post-presentation pause

Removed Mario Slide's Lost Levels-style SFX export, repeat/cleanup code, scene binding and unused mix trim; retained the MP3 asset for possible later use. Movement and skid pose logic are unchanged. Reference inspection confirmed six 21-frame interval ticks and concurrent event-music gating. The existing 126-tick timer elapsed during the music because score/fireworks hooks currently finish immediately. Per the requested visible delay, its count now starts only after both hooks and music complete, giving a full roughly 2.1 seconds before the finish transition. Documented this deliberate ordering difference and updated focused regressions. No settings, bindings or imports changed.

## 2026-11-05 - Balance ending audio with the shared mix

Measured the new flagpole and stage-clear WAVs against existing jump/death recordings, then added their previously missing stream trims to the shared mix: -2 and -3 dB respectively. The unchanged master makes effective gains -5 and -6 dB. Extended the existing mix regression to cover source/copy identity and actual non-positional ending players. No sample processing, timing or import changes.

## 2026-11-05 - Preserve high flagpole grabs

Found that flagpole attachment clamped feet to 24 pixels below the top tile and that discovery omitted the top 12 pixels of the tile. Flagpole-specific upper bound is now eight pixels below tile origin, discovery covers the full ball metatile, and vertical contact uses the reference small-Mario side-probe height. The shared sweep remains for base/landing/fast-crossing reliability. Added high-ball/above-ball and real running-jump checks and exercised a highest-position grab through the ending handoff. No jump physics, artwork or authored stage placement changed.

## 2026-11-05 - Flag contact rendering

Corrected flagpole horizontal capture to the reference X bands while retaining continuous swept contact and the high-ball bound. Reproduced foreground loss in a rendered flag-contact overlap fixture with pipe ordering false: the old compositor showed none of Mario's 139 opaque sprite pixels, while reasserting render draw indices preserved all 139. Render parents remain cached and the pipe-specific behind-world route is retained. No sprite pixels or palette resources were edited.

An experimental position-before-gravity airborne update increased the full-speed apex from 77.5 to 82.5 pixels. The user found the height excessive during playtesting and requested reverting it; previous jump and passive-fall integration was restored. The rendering correction remains. No Project Settings, bindings or import settings changed.

## 2026-11-05 - Combine airborne timing with post-motion landing checks

After the earlier jump-only experiment was reverted, reproduced both user-provided benchmark jumps and found corner correction mixed pre-motion vertical depth with projected horizontal reach. Implemented position-before-gravity airborne motion together with post-motion landing-depth rejection. Launch/gravity constants and authored layouts remain unchanged. Retained physical-edge fallback probes after removing them caused a one-tile gap momentum regression; inset probes remain first. Added an isolated six-position benchmark and explicit over-depth rejection coverage, and updated the handoff regression for zero-speed passive falls. This supersedes the earlier rollback as the current implementation. Verification and remaining reference limits are recorded in docs/verification.md. No Project Settings, Input Map, import or Git operations were performed.

## 2026-11-05 - Preserve the reference falling-gravity selection

Confirmed VerticalForceDown is explicitly written during player entrance setup and jump initialization, then reused by FallingSub without being cleared on landing. JumpAction now retains this profile after jump exit; passive Move falls apply it through a temporary modifier. New players and committed transport arrivals initialize the reference $28 entrance force. No air-steering or active-jump tuning changed. Added five-profile, override/weight, cleanup, successful-landing retention and area-reset checks; existing jump benchmarks and gap regressions remain. See docs/verification.md for the actual validation scope. No Git operations were performed.

## 2026-11-05 - Silent timer-to-score ending phase

Replaced the flagpole presentation's no-op Score hook with TimeScoreStep: one remaining timer unit becomes 50 points per physics tick after endpoint retirement, without waiting for stage-clear music and without counting audio. GameHandler remains the value owner and the existing HUD signals render each update. The contact-time snapshot is preserved; disabled/zero timers skip conversion, and completion/cancellation/level replacement stop callbacks through the ticket and weak owner guards. Fireworks remains a placeholder and the existing final hold is unchanged. Added end-to-end conversion coverage and retained the ending audio-tail scenario with a short counter. No Project Settings, Input Map, audio imports or Git operations changed.

## 2026-11-05 - Promote the final run score on title return

Common GameHandler title entry now compares the outgoing score with top_score after stage shutdown and before clear_session resets the run. Higher scores replace the app-session record; ties/lower values preserve it without duplicate record notifications. Time-conversion points are included, and the title's existing binding displays the result. Direct resets/new-game initialization do not independently promote records; no disk persistence is added. Added title-return, time-bonus and game-over regression assertions. No Git operations were performed.

## 2026-11-05 - Flagpole height reward and popup

The flagpole ending selects the reference reward tier on first contact, shows the world-space atlas popup, and awards the points once at descent completion. The popup rises during descent and is freed on cancellation. Focused headless checks passed for flagpole ending, time conversion and popup mapping. The rendered ending passed and showed the 2000 popup beside the shaft with the corresponding HUD score.

## 2026-11-05 - Paintable castle and rooftop flag

Replaced the 21 castle decoration tiles in 1-1 with the collision-free Castle (5x5) entity stamp at (201,8). The presentation binds that castle and the configured flagpole by cell in the same area. The castle owns the preserved doorway position and the flag sprite. After time conversion, the presentation raises the flag one pixel per tick for 31 ticks, then starts the Fireworks hook. Headless and rendered ending and time-conversion checks passed. The rendered ending confirmed the flag above the roof, and the regression covered the full raise while castle activity was suspended.

## 2026-11-05 - Paintable world coins

Added a 16x16 Coin entity stamp to both area palettes. The coin uses the shared 48-tick cosmetic clock and the area theme selects its atlas. Headless placement checks passed in both areas, and headless and rendered clock checks verified synchronization with the HUD coin and question blocks. Pickup behavior remains a separate milestone.

## 2026-11-05 - World coin rewards

World coin pickup awards 200 points and increments the coin count. At 100 coins the count resets and a reserve life is awarded. Coin and extra-life sounds share a non-positional voice with reference 1 UP priority. Focused area, death, and player status tests passed. The area test verifies rollover, sound selection and protection, and no duplicate rewards after restoration.

## 2026-11-05 — Palette atlas consolidation

- Migrated terrain, scenery, blocks, pipes, world coins, castle art, flagpole parts, and Mario walk/climb frames to the supplied sheets. Removed 77 superseded PNGs and their import sidecars.
- Preserved saved tile coordinates, source IDs, collision data, theme overrides, and animation timing. Updated the pipe and flagpole paint-preview builders.
- Verification: Godot 4.7.2 imported the migrated resources, both preview builders ran, and the area theme, animation clock, walking, climbing, sideways pipe, and question block regressions passed headlessly.

## 2026-11-05 — Unused asset cleanup

- Removed the two unassigned area tracks, the retired skid effect, both unwired Goomba sprites, and two ground texture wrappers superseded by the terrain TileSets. Kept editable Aseprite sources for active artwork.
- Removed the stale ground texture override and restored the PNG extension used by the HUD verification capture.
- Verification: Godot import and headless area theme, HUD, death, and game-over checks passed. Game-over reported two ObjectDB instances at exit.

## 2026-11-05 — Grouped tile painting sources

- Grouped pipe, bush, hill, and cloud pieces by family in both palettes. Kept the existing paintable tile inventory and separate entity stamps.
- Remapped 253 painted cells in 1-1 and Test Level to the grouped sources while preserving their positions, artwork, and collision definitions.
- Verification: the headless area theme regression passed with grouped sources and matching collision data.

## 2026-11-05 — Solid ground painting source

- Grouped seven Ground and Stone cells into Solid ground in both palettes with full-tile collision. Remapped existing solid-block placements.
- Verification: area theme and jump benchmark regressions passed headlessly.


## 2026-11-06 - Level-owned death sequence

- Extracted presentation, suspension, jingle, timing, and cancellation into LevelDeath. BaseLevel retains lifecycle acceptance and player retirement. GameHandler retains restart and game-over routing.
- Death and Game Over passed before and after extraction. Audio, transition, and climbing checks passed. Several runs reported ObjectDB leak warnings. The timer test stopped at its existing Test Level timer configuration assumption before exercising timeout.


## 2026-11-06 - Level timer extraction

Moved the countdown phase and expiry signal into LevelTimer. BaseLevel retained gameplay gating and timeout death routing. Restored the untimed sandbox. The timer regression passed, including TIME UP and both respawn and game-over paths.


## 2026-11-06 - Area transport extraction

Moved trip resolution, entry and exit state, and transition callbacks into the level-owned AreaTransport child. BaseLevel kept the public transport API and commits player placement, active area, and camera.


## 2026-11-06 - Game flow extraction

Moved title operations into TitleFlow and restart, TIME UP, Game Over, and stage handoff into StageFlow. GameHandler retained the public API, flow state, session, and active level ownership. Title, stage completion, death, timer, transition, ending, and player status checks passed. Several headless runs reported ObjectDB leak warnings.

## 2026-11-06 - Question-block coin rewards

Question blocks now award one coin and 200 points on bounce entry through GameHandler. The effect under scenes/entities/blocks/question uses the dedicated block-coin sprite and the shared score popup. The editor add-on under addons/question_block_contents exposes Coin for each selected question-block cell. Existing layouts use the default directly, so per-cell storage is deferred until another reward is available.

Godot 4.7.2 headless editor startup loaded the enabled add-on. The focused question-block, area-theme, area-streaming, and sound-mix scenes emitted PASS. The full regression run produced 60 PASS markers. The strict runner returned a failure because 29 scenes reported ObjectDB leak warnings on the console at shutdown. Interactive editor and Mesen comparisons were not performed.

## 2026-11-06 - Remove the question-block contents dropdown

Removed addons/question_block_contents and its project.godot registration while the reward authoring workflow is reconsidered. Updated the setup, testing, backlog, and entity-layout guides. The question-block regression emitted PASS in Godot 4.7.2 headless with four ObjectDB leak warnings at exit. Interactive editor verification was not performed.

## 2026-11-06 - Block Rewards editor preview

Added addons/block_rewards to let authors click a painted question block and preview Coin without looking up coordinates. The add-on uses the existing EntityLayout and stores no overrides. The script check and headless editor startup succeeded. Interactive click and overlay placement checks were not performed.

## 2026-11-06 - Stationary 1-Up sandbox milestone

Painted a 1-Up spawner at (8, 12) on the TestLevel EntityLayout. The spawner uses BaseLevelArea camera activation, creates a stationary PowerUp, and records collection. The item uses the area theme, grants one life and plays the shared 1-Up cue, then frees itself. Movement, offscreen disposal and block release remain future steps.

The 1-Up, entity activity and area theme regressions emitted PASS in Godot 4.7.2 headless. The 1-Up check reported two ObjectDB leaks at exit. Existing missing palette resources prevented running the sandbox directly in the working tree. Verification used an isolated copy with those resources supplied from HEAD.

## 2026-11-06 - Mushroom movement and offscreen removal

Added the Mushroom movement layer under scenes/entities/powerups. The 1-Up walks right at launch, falls under gravity, and reverses against walls. BaseLevelArea compares the live item's bounds to the existing camera cleanup region. PowerUp frees the item when it is fully outside, without granting a reward or reporting collection. The placement stays spent for the current area load. Existing collection persistence still applies. The sandbox's painted 1-Up at (8, 12) was restored.

The focused 1-Up regression passed in Godot 4.7.2 headless. It checks landing, reversal, pickup and popup, partial visibility at the boundary, disposal and no same-visit respawn. Motion is initial tuning and was not compared in Mesen.

## 2026-11-06 - Level spawn limits

Added a category-based spawn limit to BaseLevel and assigned the painted 1-Up spawner to power_up. The limit is one live item. A waiting spawner stays eligible and can activate when the previous actor exits the tree. The 1-Up and entity activity regressions passed headlessly. The 1-Up regression used two painted placements to verify waiting and activation after offscreen cleanup.

## 2026-11-06 - Skip blocked painted spawns

Changed EntitySpawner in scenes/entities/spawners/entity_spawner.gd to spend its attempt at camera activation, even when a full category or another failure prevents spawning. This replaces the earlier waiting rule so freeing a slot cannot cause a power-up to appear late on screen. The two-placement regression in tests/one_up_test.gd passed in Godot 4.7.2 headless. It verified that the second mushroom stayed absent after the slot freed and after the camera left and returned.

## 2026-11-06 - Question-block 1-Up release

Configured the leftmost lower question block of the second multi-block cluster in 1-1 at (106, 9) to release the shared 1-Up scene. PowerUp rises one tile before movement and collection begin. BaseLevel replaces the previous live power-up on a block release. Painted spawners keep the skip rule. The editor overlay previews the authored reward. Godot 4.7.2 headless editor import and focused question-block and 1-Up checks passed. The question-block check reported four ObjectDB leaks at exit. Rendered emergence and Mesen timing were not checked.

## 2026-11-06 - Mushroom falling and emergence fidelity

Mushroom uses the NES downward force of 61/256 pixel per frame squared at nominal 60 Hz and applies it after movement. The project retains its 300 px/s fall cap and Godot terrain collision. PowerUp reveals one row per four nominal frames and clips the sprite to the block's fixed top edge during the rise. The question-block and 1-Up headless checks passed. The question-block check reported four ObjectDB leaks at exit. Rendered comparison in Mesen remains open.

## 2026-11-06 - Paint question-block rewards

Added a brush to addons/block_rewards. Authors choose 1-Up or Coin and click the existing question block in the viewport. The scene saves the assignment through the area property and editor undo history. Godot 4.7.2 headless editor import loaded the add-on. Interactive input, save, and undo were not verified.

## 2026-11-06 - Outlined hidden question blocks

Added a Hidden Question Block stamp to all three EntityLayout palettes and painted one at (8, 8) in TestLevel. The scene uses the bottom-right atlas outline, an underside query, and the regular question-block bounce, rewards, and used state. The reward brush accepts both block stamps. Godot 4.7.2 headless editor import and the bonk regression passed. The regression compared stopping position and vertical response with a regular bonk, verified side and top pass-through, and landed on the used block. The test reported ObjectDB leak warnings at exit. Rendered playtesting remains open.

## 2026-11-06 - Goomba movement foundation

Added BaseEnemy and Goomba scenes under scenes/entities/enemies, the shared walking state under scripts/states/enemies, and theme overrides for the supplied artwork. A temporary Godot 4.7.2 headless fixture verified Walking, animation, themed art, terrain landing, and wall reversal. The area-theme regression passed. Painted spawners, enemy cleanup, stomp and side contact remain separate steps.

## 2026-11-06 - Painted Goomba spawners

Added the Goomba Spawner stamp to all three entity palettes and painted a sandbox example at (11, 12). Both enemy spawn paths use the same level limit. SpawnableEntity now owns shared offscreen removal. Godot 4.7.2 headless editor import, enemy_spawn_test, entity_activity_test and one_up_test passed. The spawn fixture verifies five active enemies, independent power-up capacity, bottom-edge cleanup, and no delayed spawn for either blocked placement type. In-game enemy contact remains a later step.

## 2026-11-06 - Goomba movement and enemy contact

Checked the Goomba walking speed and gravity against the NES disassembly and retained 30 px/s walking speed, about 858 px/s² gravity and a nominal 180 px/s fall cap. Added enemy overlap handling in BaseEnemy and reversal in the shared Walking state. Godot 4.7.2 headless enemy spawn, entity activity and 1-Up checks passed. The enemy test verified both Goombas turned on contact and stayed grounded. Godot collision and fixed-point NES behavior have not been compared frame by frame in Mesen.

## 2026-11-06 - Goomba placements in 1-1

Painted four individual Goombas and six two-Goomba groups on the MainArea EntityLayout in 1-1. The placements come from E_GroundArea6. Individual markers use the encoded columns and rows. Pair markers use the nominal camera-right position, 48 pixels before the encoded trigger column, and spawn members 24 pixels apart in one activation pass. The area still uses the project camera buffer and five-enemy cap, so activation timing and slot availability can differ from the original. Defeat persistence for pair members remains a later step.

Godot 4.7.2 headless enemy spawn, scene hierarchy, and 1-Up checks passed. The enemy check verified the authored counts and pair spacing. In-game timing has not been compared in Mesen.

## 2026-11-06 - Goomba interactions and enemy placement grid

Moved the painted Goombas in TestLevel and 1-1 to EnemyLayout, added stomp and harmful contact, and shared block-hit detection between Goombas and mushrooms. Goomba defeat frees the actor after its presentation and is never saved. Added the defeat event and hit handlers for future shell, fireball and star sources. The enemy spawn, bonk contact, question block, 1-Up, scene hierarchy, area theme, death and jump benchmark scenes emitted PASS in Godot 4.7.2 headless. Several scenes reported ObjectDB leaks at exit. Rendered feel and NES frame timing remain unverified.

## 2026-11-06 - Stomp sound and block-bump defeat

The stomp synthesis now follows the NES per-frame volume sequence and writes the pitch timer low byte on frame 8 while retaining the original sweep setting. A block-bumped Goomba flips, moves away from Mario, and falls through terrain until offscreen cleanup. The previous half-second deletion timer now applies only to the squash. Enemy spawn, sound mix and question block checks emitted PASS. The enemy and question block checks reported ObjectDB leaks at exit. In-game listening and frame comparison in Mesen remain open.

## 2026-11-06 - Goomba combat bounds and Mario rebound

Separated Mario contact from Goomba terrain and enemy contact. The Goomba combat area is 10×6 and small Mario has a 10×12 enemy hurtbox. These sizes follow the NES bounding-box offsets. The enemy checks player contact every other physics tick. A descending overlap squashes the Goomba and sets Mario's Y speed to -240 px/s without changing X speed or position. The enemy regression verifies a harmless graze and the exact rebound. Death and 1-Up checks also emitted PASS. Godot overlap timing has not been frame-matched against Mesen.

## 2026-11-06 - Enemy marker alignment and spawn clearance

Corrected EnemyLayout texture_origin from (4, 4) to (-4, -4), aligning each 16×16 preview with its 8×8 placement cell's top-left. Moved 1-1's enemy markers down one 8-pixel row so all sixteen live Goombas start with an 8-pixel gap to their supporting surface. Horizontal positions and pair spacing remain as authored. The enemy regression queried actual terrain and pipe colliders for every member and verified no initial overlap and the 8-pixel gap. Enemy spawn and scene hierarchy checks emitted PASS headlessly. The enemy check reported two ObjectDB leaks. Editor screenshot comparison was not performed.

## 2026-11-06 - Mushroom pickup bounds and block bump

Changed the mushroom pickup to a 12×12 rectangle one pixel above sprite center, following the NES power-up box offsets. Pickup uses Mario's separate contact area. Terrain still uses the 14×16 Godot body. A block hit launches the mushroom at -180 px/s and sends it away from Mario at its walk speed. The 1-Up, enemy spawn and question-block checks emitted PASS. The question-block check reported ObjectDB leaks at exit. Exact terrain probe and edge-contact timing remain unverified in Mesen.

## 2026-11-06 - Flagpole presentation motion ownership

Moved the descent stop, 24-tick dismount, four-pixel nudge and doorway arrival to scripts/levels/endings/flagpole_ending.gd. The existing player state now adapts climb and walk mechanics at the original player physics priority. Flagpole ending, time score and level completion emitted PASS in Godot 4.7.2 headless. Flagpole ending and level completion each reported two ObjectDB leaks at exit. Rendered playtesting remains open.

## 2026-11-06 - Flagpole presentation phase two

Removed the FlagpoleEnding player state and scene wiring. FlagpoleEndingPresentation now directs the existing Climb and Move states through a scripted physics callback on BasePlayer. Mario supplies his normal walk animation and cadence. The presentation clears the callback at the doorway or on cancellation. Flagpole ending, time score, climbing and level completion emitted PASS in Godot 4.7.2 headless. The flagpole check reported two ObjectDB leaks at exit. Rendered playtesting remains open.

## 2026-11-07 - Gameplay pause and dedicated cue

Added GameHandler-owned PauseController with Start pause/resume, SceneTree freezing, normal-gameplay eligibility, release consumption for Enter's shared Jump binding, and standalone F6 support. SoundHandler generates the reference pause sequence on a dedicated Always-processing, non-positional player at default gain. Shutdown, session reset, and leaving Playing clear pause. No project settings or bindings changed. Affected paths: scripts/handlers/pause_controller.gd, game_handler.gd, sound_handler.gd, scenes/levels/base/base_level.gd, tests/pause_test.*, and the current setup/architecture/testing guides. See pause.md for the walkthrough and deliberate audio-resumption difference from NES behavior.

Godot 4.7.2 headless pause, title, transition, sideways-pipe, and animation-clock regressions reached PASS. Pause reported two ObjectDB leaks, transition two, and animation-clock seven. Focused script formatting completed. Full suite, rendered playtest, physical controller testing, and Mesen listening comparison were not performed.

## 2026-11-07 - Pause during level presentations

Simplified PauseController eligibility at the user's request: only title screens and active TransitionCoordinator operations block pause, with an existing non-shutdown level required. Removed player/death/pipe/completion gates. GameHandler no longer clears pause on Completing flow; accepted screen transitions clear it explicitly. Existing presentation timing already follows pausable processing, so no separate animation pause machinery was introduced. Updated scripts/handlers/{pause_controller,game_handler,transition_coordinator}.gd, pause regression and integration fixtures, and setup/architecture/pause documentation.

Pause, death, sideways-pipe, flagpole-ending, and transition regressions reached PASS headlessly in Godot 4.7.2. Integration checks freeze/resume actual pipe entry and emergence, the death wait, flagpole descent, castle walking, and the score phase. Pause reported two ObjectDB leaks; flagpole ending reported two. Rendered playtesting and the full suite were not performed.

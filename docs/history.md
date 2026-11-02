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

- Renamed the project display title and README to QuickGame-Godot2D (Platformer), superseding the earlier game-specific title. Updated the introduction to explain the multi-game tutorial scope. Retained historical names and game-specific technical attribution. Workspace folder, resource paths, and gameplay are unchanged.
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

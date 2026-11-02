# Design decisions

The initial entries were reconstructed on 2026-11-01 from this project's conversation and current files. They are not a record of exact edit times. Status distinguishes implemented choices from proposals.

## D001 â€” 16Ã—16 world grid and integer display scaling

Status: implemented.

Use 16Ã—16 tiles and sprites, a 256Ã—240 logical viewport, and a 768Ã—720 initial window. Render the viewport at integer scale to keep pixels consistent. The camera remains at 1Ã— zoom. Window shapes that do not fit an integer scale can leave borders. Configuration was explicitly approved by the user. See [settings](settings.md).

## D002 â€” Level and character inheritance

Status: implemented.

TestLevel inherits BaseLevel. Mario inherits BasePlayer, which inherits BaseEntity. Each concrete character owns its concrete states; common player-state behavior lives in scripts. BasePlayer does not select Idle on behalf of every player. This replaces the earlier implementation where BasePlayer owned Idle.

## D003 â€” Shared entity root with specialized physics children

Status: implemented; retained for the first horizontal movement implementation (D010).

BaseEntity extends Node2D so characters and non-character objects can share a scene base while using different physics children. BasePlayer has a CharacterBody2D child. The tradeoff is that entity-root position and physical-body position can diverge. A character-root approach is an alternative to discuss, not an approved migration.

## D004 â€” Node-based state machine with inherited state scripts

Status: implemented.

Each entity has a separate machine and state instances. Only the active state receives manually forwarded hooks. State references are instance-owned, avoiding the shared static references found in the earlier demo. Transition validation, nested-transition rejection, and post-entry signals make behavior explicit. Node-based states add files and references; simple objects need not have concrete states.

EntityState supplies presentation settings. PlayerState supplies one Controls Enabled flag. The user explicitly removed movement/jump-specific permission flags: each concrete state decides which inputs it accepts.

## D005 â€” Global game and controller handlers

Status: implemented.

Use approved autoloads under `scripts/handlers/`. GameHandler owns level loading and global session context. ControllerHandler supplies input intent and events; states interpret them. This creates deliberate global dependencies and currently supports one shared input source. Saved session data means in-memory data, not disk persistence.

## D006 â€” Interactive blocks are entities

Status: terrain cleanup implemented; static entities planned.

Brick and question-block textures are reserved for future static entities. Their TileSet entries and placed block cells were removed while retaining the image assets. The floor remains tiled terrain.

## D007 â€” Explicit application and level lifecycle

Status: proposed, not implemented.

The discussed initialize/start/stop/dispose contract should separate node readiness from deliberate gameplay activation. Current code still spawns and starts machines through `_ready()`. Hook names, failure behavior, shutdown order, and any common GameScene base must be settled before implementing that contract.

## D008 â€” Documentation accompanies every change

Status: superseded by D009 on 2026-11-01.

Keep current implementation guides, architectural decisions, settings records, and a dated change history. Update them alongside each change. Preserve previous decisions when superseded and record the replacement. Repository instructions are in `AGENTS.md`.

## D009 â€” Document significant work rather than every edit

Status: adopted 2026-11-01 at the user's clarification; supersedes D008.

Update documentation for important milestones, major implementations, architectural decisions, and deliberate settings changes. Routine edits, small fixes, and internal refactors need no individual documentation/history entry unless they materially change documented behavior. Keep current guides accurate and group significant work into meaningful history entries. Settings changes still require prior approval and a settings record.

## D010 â€” State-driven composition actions and horizontal movement

Status: implemented 2026-11-01.

Use Idle and Move for the first grounded behaviors. Walking and eventual running share a movement state; a separate Air state is planned for rising, falling, and ledge departures. Do not apply a jump impulse automatically on entering Air. At this decision's implementation, Run, Jump, Air, and slide were absent; D011 and D012 subsequently add Run and Slide.

Add reusable action nodes, starting with HorizontalMovement. It computes horizontal velocity only; Mario's state supplies input intent and calls body movement once per physics update. BasePlayer owns the component reference and facing helper. Move accelerates, reverses, and brakes; it returns to Idle only after horizontal input and momentum reach zero. This provides future reuse without creating empty action frameworks for unimplemented abilities.

Retain the existing child-body arrangement for this scoped change; use Body for movement and sound parenting. No root migration is made. Gravity and camera following are outside this milestone, so Mario stays at constant height and can leave the fixed view.

Common presentation options move onto BaseState, including enter/exit sounds, optional exit animation, and lifecycle signals. Machine-owned activation/deactivation wrappers preserve these effects when hooks are overridden. Custom actions use hooks or signals; exit animations do not delay transitions. Actual animation and sound resources remain unassigned.

## D011 â€” Shared motion values, Run modifier, and static Idle

Status: implemented 2026-11-01; extends D010.

Replace action-owned tuning with per-player MotionValues. Actions and future levels/states can supply named, prioritized overrides without resetting each other's changes. Body remains authoritative for velocity through a proxy. Run modifies shared values rather than becoming a movement state. The user approved secondary bindings; no other display/import settings changed.

Idle uses a static sprite pose, not an animation. Shared state options can stop playback and select a frame. Physics fidelity is now an explicit goal; [movement](movement.md) records initial coefficients, source provenance, and remaining differences. Gravity/jump values are deferred until their context-dependent rules are implemented rather than introducing an unused universal gravity constant.

## D012 â€” Slide as a grounded reversal state

Status: implemented 2026-11-01; extends D010/D011.

Use a Mario-owned Slide state and a reusable Slide action for opposing-direction skidding. Entry preserves momentum and applies a priority-300 named modifier; physics brakes toward zero and clears low residual speed. Exit removes only its own modifier. Releasing opposite input or resuming the old direction cancels Slide. Low-speed reversals finish directly in Move. A crouching slide is a different unimplemented behavior.

Correction on 2026-11-01: release-to-cancel was a bug and has been replaced. Neutral input now retains Slide until stopping; only actively resuming the original travel direction cancels it. The source separates visual skid selection from continued directional input. Existing stopping/fixed-point approximation limits remain documented in the movement guide.

The selected parameters and remaining fidelity boundaries are documented in movement.md. Keep presentation independent through the standard state hooks. Current Slide uses the existing static frame without new art. Do not claim exact original physics until update-order and fixed-point trace comparisons exist.

## D013 â€” One velocity-driven walk/run animation

Status: implemented 2026-11-01.

Use the user's three separate walking PNGs in one external Animation resource, authored as a looping discrete texture track. Mario owns the library and WalkAnimation action. Move selects the loop and updates cadence from actual velocity; Run still only changes motion parameters. Preserve Idle and Slide as static textures, and restore playback speed when leaving Move. This extends D010's action composition and replaces Move's temporary static pose.

The movement guide records source-based cadence bands and timer-phase differences. No movement coefficients, input bindings, project settings, or custom import settings change for this milestone.

## D014 â€” Profile-based Jump, Air, and gravity weight

Status: implemented 2026-11-01.

Add reusable Jump and Gravity action nodes and per-player editable gravity, weight, and fall-speed values. Jump explicitly applies an impulse only when grounded; Air entry alone never jumps. Use one Air state for rising, falling, and landing. The user supplied its static sprite. Ground states perform vertical contact updates even when Idle. Primary input remains the existing binding and adds a physics-tick fresh-press snapshot; no new settings are required.

Weight defaults to one and multiplies gravitational acceleration only. It is a gameplay extension, not a simulation of physical mass or an original-game feature. Jump holds a temporary gravity profile until Air exits; release selects stronger gravity after the minimum rise. Full original air control, fixed-point trajectories, buffering, coyote time, and respawning remain outside this implementation. See jumping.md for provenance and verification.

## D015 â€” Independent air control preserves skid-jump context

Status: implemented 2026-11-01; extends D014.

Capture grounded facing and speed/history before removing Slide, then use AirMovement's own modifier. Braking depends on facing versus travel, not just current input versus velocity. Neutral air input coasts; held reversal continues braking without a grounded skid cutoff. Air cleanup reveals existing ground/level values. Fast-history capture remains a documented proxy rather than a full original latch implementation. No project/input/import settings changed.

## D016 â€” Component folders reflect responsibility

Status: implemented 2026-11-01; replaces the earlier broad Actions grouping.

Separate ongoing Motion behavior (HorizontalMovement, AirMovement, Gravity), state-invoked Actions (Run, Jump, Slide), and Presentation (WalkAnimation). Shared MotionValues stays a sibling data node. Mirror this organization in reusable component folders and rename non-action classes to Component. Preserve script UIDs and update scene/script/test references. This is an organizational refactor, not a change to physics, state processing, input, or settings. The complete inherited scene tree is in architecture.md.

## External references

These are study resources, not specifications or claims that our architecture exactly matches them:

- [The Shaggy Dev: Godot 4 state machines](https://shaggydev.com/2023/10/08/godot-4-state-machines/) â€” similar node-based hooks and transitions.
- [GDQuest: finite state machines](https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/) â€” alternatives and tradeoffs.
- [Celeste's selected public source](https://github.com/NoelFB/Celeste) â€” platformer behavior in C#/Monocle, not a complete Godot project.

## 2026-11-01 â€” CanvasGroup for the level shadow trial

Implemented CanvasGroup on BaseLevel to combine all normal child CanvasItems for a single silhouette without a second viewport or reparenting gameplay nodes. This preserves spawning paths and the current camera/physics world. The backdrop stays outside the group; opaque full-screen children, CanvasLayers, clipping, and other screen-reading effects require care. See level-shadow.md. Revisit the composition if those rendering requirements grow.


## Terminal shutdown and current scene ownership â€” 2026-11-01

Implemented the shutdown portion of D007; separate activation/loading/disposal phases remain proposed. GameHandler shuts down the old level before removing it. BaseLevel shuts down descendant entities. BaseEntity disconnects callbacks, deactivates its state without exit presentation, and stops playback/updates. Shutdown is terminal and idempotent; ordinary machine stop/start remains restartable. Tree-exit cleanup is a fallback, not a substitute for deliberate shutdown before removal. Custom exit hooks own cleanup; standard exit effects are suppressed.

Superseding the earlier sibling data-node placement, Motion now carries MotionValues directly. Mario states refresh Run before grounded takeoff checks. Current architecture.md and state-machine.md describe the implemented contracts.


## TileMap-authored entity generation â€” 2026-11-01

Implemented a generic EntityLayout marker layer and per-level ID-to-scene dictionary. Generate BaseEntity scenes once before player startup rather than requiring manual placement. This supports solid blocks, detection-only entities, and decorations without forcing collision into the spawner. Markers remain available for editor painting and are hidden at runtime. Entities retain lifecycle and shadow ownership. Activation-on-demand and streaming are deferred. See entity-layout.md.


## Theme folders before theme selection â€” 2026-11-02

Implemented overworld/underground/castle artwork folders beneath tileset, interactibles, and enemies. Current environment artwork is overworld/palette 1. Shared TileSet definitions remain outside theme folders, and gameplay scenes/scripts remain shared. Runtime theme selection and theme-specific texture/animation binding are deferred for discussion; current resources explicitly reference overworld art. See level-themes.md.


## Theme-first artwork organization â€” 2026-11-02

Supersedes the earlier theme-folder decision's category-first layout at the user's request. Group tileset/enemies/interactibles beneath Overworld (Palette 1), Underground, and Castle. Shared TileSet definitions remain under assets/tileset; runtime theme selection remains deferred. See level-themes.md.


## Jump presentation versus passive falling â€” 2026-11-02

Supersedes the shared Air-state design: Jump starts from a successful Jump action and persists until landing. Move covers ground travel and passive falling, sharing air physics components with Jump but retaining walking presentation. Idle/Slide fall into Move. Physical floor contact remains authoritative for jump permission and landing; state membership alone does not grant floor contact.


## Base-scene ownership cleanup â€” 2026-11-02

BasePlayer owns shared Body/AnimationPlayer, Motion, and Actions; Mario owns the Presentation container and WalkAnimation. Empty inherited state machines remain valid future behavior extension points. BaseLevel uses explicit owned node paths instead of recursive name discovery; preserve those contracts when regrouping scenes. This supersedes the earlier temporary support for arbitrary spawn/layout nesting. No gameplay or visual tuning changed.


## 2026-11-02 â€” Shared level layout grid

BaseLevel owns a Layouts group containing DecorationLayout, GroundLayout, and EntityLayout. Ground is a shared base responsibility; concrete levels assign TileSets and paint cells. The group uses a tool script to reset local transforms and require 16x16 square cells in the editor and runtime. This favors consistent tile/entity alignment over independent layer transforms. Move the level root to relocate the whole stage. Grid enforcement changes TileSet cell dimensions/shape, not atlas texture regions or painted cell data; shared TileSets must follow this contract.

## 2026-11-02 — Offensive hits and two-state block activation

Question blocks use the existing FSM with Active and Inactive. Offensive actions send EntityHit context; blocks decide acceptance in their current state. Mario enables the reusable Bonk action; BasePlayer leaves it disabled by default. Inactive entry owns the bounce, preventing unrelated Active exits from triggering reactions. The used sprite appears immediately and duplicate hits are rejected throughout the reaction. Bounce moves only presentation: stable collision is an intentional simplification of the reference's temporary moving block/metatile handling. No item system or brick-breaking rules are introduced.

## 2026-11-02 — Explicit block reaction phase

Supersedes the earlier two-state question-block decision: QuestionBlock now uses Active -> Bouncing -> Inactive. The reusable BouncingBlockState owns reaction processing, inherited entry presentation/events, natural-completion notification, and cleanup. Bricks use the same Bouncing script but return to Active. Inactive has no bounce responsibility. The used sprite still appears as soon as a question block accepts a hit. Future item spawning and reaction effects can attach to Bouncing entry; they are not implemented here.

## 2026-11-02 - Planned per-cell entity editor

Status: planned; not implemented. The user chose a custom editor tool for configuring individual painted entity cells (option 2), rather than requiring a separate marker tile for every contents variant.

Intended workflow: paint a question block in EntityLayout, select that cell, and choose its contents through an editor dropdown. Store the configuration with the level, keyed by grid coordinate; TileSet custom data continues identifying the entity type. The spawner will apply per-cell configuration before adding the entity to the scene tree. This allows identical question-block markers to have different contents without changing their shared TileSet definition.

Before implementation, define defaults, validation, undo/redo, and what happens to configuration when cells are erased, replaced, or moved. The editor tool, per-cell storage, and item spawning remain future work.

## 2026-11-02 - Area-owned themes without palette shaders

Supersedes the shared level-layout ownership for TestLevel: each BaseLevelArea now owns its own Layouts and generated WorldObjects, camera, arrival marker, and selected AreaTheme. BaseLevel retains shared player ownership and coordinates generation/shutdown. The main and lower areas share the same BaseArea scene foundation. Their painted world positions remain unchanged.

AreaTheme selects compatible TileSets and explicit entity texture overrides. Missing variants fall back to the source artwork. Terrain/marker IDs and collisions stay compatible; entity state behavior is reused rather than duplicated per palette. Entity animation resources are copied before remapping texture keys, and BaseState resolves static textures through the entity theme. Mario remains independent of environment themes. Themes apply at authoring/startup; runtime theme replacement, pipe travel, music changes, and global active-area state are not implemented.

## 2026-11-02 - First paintable pipe entrance

Use a BaseEntity-derived, upward-facing two-tile cap as the interactive entrance, while static pipe bodies remain paintable terrain. A single EntityLayout marker identifies the opening's left cell. It reads existing ControllerHandler Down intent and validates active-area ownership, ground support, alignment, and enabled player controls. BaseLevel owns deferred transfer by unique destination area_id, player transient-state reset, camera selection, and GameHandler current_area_id session bookkeeping. Shared game state stays in GameHandler. This first slice targets LowerArea's Arrival marker directly; paired exits, animated travel, return routing, and music policy remain future work.

## 2026-11-02 - Complete pipe footprint and foreground occlusion

Supersedes the cap-only entrance authoring: one source-3 marker now previews and spawns a complete 2x2 pipe. Store a single top-left anchor and render its whole footprint, preserving existing entity-generation semantics. Pipe artwork is transferred to level-owned ForegroundObjects with RemoteTransform2D tracking; its entity and collision remain area-owned. Explicit shutdown cleans the transferred artwork. Same-Z draw ordering keeps the shared CanvasGroup shadow and allows the pipe to obscure Mario, without changing ordinary block/player ordering. Descent animation remains a separate future milestone.

## 2026-11-02 - Named endpoints and per-cell pipe routes

Supersedes routing solely to an area's Arrival marker: resolve an Area ID + Endpoint ID pair. Arrival remains the default for existing entrances. Additional AreaEndpoint markers under Endpoints identify player-feet positions and future emergence directions. Source-area PipeRoute resources keyed by painted anchor cell let one shared pipe scene serve independent routes; the custom click-cell editor remains deferred. Same-area named destinations and return routes are supported without animation.

BaseLevel revalidates unique IDs and weak targets before deferred movement, records the destination IDs in GameHandler, snaps scrolling cameras to reveal arrivals, and locks further pipe activation until Down is released. These prevent arbitrary duplicate selection, stale-node transfer, clamping back to an old camera view, and held-input warp loops.

## 2026-11-02 - Stateful animated pipe entry

Supersedes immediate transfer for interactive pipe entities: reserve and validate the route, enter the concrete player's reusable PipeEnter state, then perform the existing deferred handoff only after descent. BasePlayer exports the state reference without owning concrete state nodes. Normal movement/input/collision and source-camera updates are suspended during entry. State exit owns reversible collision/visibility/audio cleanup; only a committed transfer skips restoring the source position. Missing targets or shutdown cannot leave the player invisible or non-colliding. The direct transfer API remains immediate for scripted routing. No exit animation or fade is introduced.

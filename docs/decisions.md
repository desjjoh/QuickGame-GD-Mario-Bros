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

## 2026-11-02 - Active-area runtime unloading with preserved progress

The user requested unoccupied areas unload and explicitly chose preserving progress on return. Keep lightweight area roots, endpoint/configuration metadata, and packed authoring definitions, while freeing inactive runtime branches (including tile collision, actors, and cameras). Load/restore only at handoff, then save/shut down/free the source. Same-area routing keeps its existing runtime.

GameHandler owns memory-only progress keyed by level/area: tile data, logical block state, and removed marker entities. Capture logical reaction outcomes instead of replaying Bouncing states. New instances receive progress before FSM startup. Templates/theme assets remain cached; full asset eviction and asynchronous streaming are outside this milestone.

## 2026-11-02 - Temporary player background priority

Supersedes the always-foreground pipe-artwork decision. Pipes use normal world hierarchy/draw order and Mario draws in front during ordinary gameplay. BaseLevel owns a reversible draw-order change during pipe entry: move Players before Areas and restore its prior index on completion/cancellation/state exit. This changes rendering without reparenting live entities or changing Z bands, preserving lifecycle, physical transforms, and the shared shadow. Remove the no-longer-needed ForegroundObjects and pipe RemoteTransform2D.

## Directional pipes and emergence - 2026-11-02

Supersedes the earlier deferred-emergence limitation. Reuse the existing PipeEntrance scene/script with an inherited sideways variant, and the concrete player-owned PipeEnter state for entry and exit. AreaEndpoint Animate Exit is opt-in so open-space arrivals remain compatible; position means final feet position and Exit Direction controls emergence. Direct scripted transfer remains immediate. BaseLevel owns both phases, routing, camera handoff and temporary draw order; GameHandler continues owning shared session/progress data. Sideways entry requires grounded wall alignment and right input. Reentry locks until directional input is released.

## Reference pipe presentation and control ownership - 2026-11-02

PipeEnter uses an optional walk animation/cadence reference supplied by the concrete Mario scene for horizontal travel. Vertical travel retains a static pose. Keep the FSM in travel ownership across area handoff; do not start the normal state between entry and emergence. Exit Distance is endpoint configuration, defaulting to 96 pixels. Collision and controls restore at completion, with normal processing on the next physics tick. Input during travel is not buffered. The entry-only sound is suppressed on emergence. This supersedes the previous sprite-height-only exit duration and per-emergence sound.

## Pipe exit sound preference - 2026-11-02

Supersedes the entry-only audio choice above: the user wants the pipe sound on both entry and exit. Use the standard state activation sound for both phases; keep nonlooping playback and existing travel/control timing. Destination-pipe routing instead of separate arrival markers is under discussion and is not implemented.

## Vertical entry pose and silent emergence - 2026-11-02

User preference supersedes exit audio restoration and the earlier automatic-centering choice: vertical entry retains the accepted horizontal position and facing while descending. Keep the alignment/input gates and travel/control timing. Emergence is silent again; upward exit still uses its existing destination position and right-facing pose. Destination-pipe routing remains discussion only.

## Shared explicit transport and entity-owned arrivals - 2026-11-02

Supersedes pipe-to-adjacent-marker routing for new painted pipe authoring. BaseLevel.transport takes the current player, a TransportDestination (area/target IDs) and optional TransportEntity source. Area-owned TransportPlacement resources configure each painted anchor's ID, destination and permissions. Metadata stays resident while the entity is unloaded; the loaded destination entity supplies arrival geometry and PlayerTransportState. The coordinator handles travel phases, cameras, progress and unloading without implementing pipe/vine motion. A non-pipe test presentation exercises this contract; vines themselves remain unimplemented.

Keep ordinary spawn markers and existing scripted/PipeRoute callers compatible. Explicit Transport Points take precedence over legacy route fields. Never select a nearby alternative for missing/duplicate targets. The secret return now targets a distinct exit-only pipe near the stage start, with no separate pipe_return marker. The native resource array is the initial per-cell editor; a custom painting Inspector remains deferred.

## Return directly to PlayerSpawn - 2026-11-02

User preference supersedes the temporary start exit pipe: main/player_spawn is a reserved transport destination that resolves the real level Players/PlayerSpawn marker. No duplicate spatial marker or copied position is stored. Arrival restores normal play immediately after source entry finishes, without emergence. Remove the temporary return pipe and placement; retain isolated pipe-to-pipe regression coverage.

## Movement ticks and transport callback ownership - 2026-11-02

Generalize the jump-only same-tick handoff into PlayerState.continue_physics for every pre-integration movement transition. Keep post-integration transitions as ordinary FSM state returns; do not globally auto-run destination state physics, which would duplicate landing/stop movement. Guard the handoff against observer-triggered terminal shutdown.

Bind each deferred transport completion to a monotonically changing phase ID. Disconnect/cancellation invalidates queued callbacks before another phase begins. Recheck level ownership between session notifications and stop old transport work if a handler replaces/shuts down the level. This preserves existing gameplay while making the lifecycle safer for future death/UI observers. Repair the saved endpoint hierarchy and persist native base-area scene identities; retain an editor-state round-trip regression.

## Count new forward progress for one-way scrolling - 2026-11-02

Supersedes summing every positive frame-to-frame X displacement. Retain the furthest target X until an explicit camera reset/arrival, so collision-recovery oscillation and retracing previously covered ground cannot accumulate camera scroll. Follow-disabled cameras continue refreshing their baseline. Keep fractional movement, 80/112 thresholds, camera limits and interpolation settings unchanged. This fixes a reproduced pipe-side hopping drift without modifying player collision or physics tuning.

## Theme music belongs to occupied area lifecycle - 2026-11-02

Store soundtrack selection, loop and volume on AreaTheme; let BaseLevelArea.enter_area/exit_area own the actual AudioStreamPlayer. BaseLevel loading does not imply entry: activate only after a committed handoff and camera selection, stop the old area before starting the new one, and leave same-area transport playing continuously. Level shutdown and tree exit provide cleanup. Runtime stream copies provide loops without changing imports. Player SFX remain separate.

Music Enabled is a per-area override, default true, so test rooms can keep their palette theme without music. Missing tracks are silent. Return visits restart tracks; playback position is not part of saved area progress. Non-music regression fixtures disable music using this override, while a dedicated real-track test covers lifecycle and reentrant level replacement. No new global handler, audio bus or project settings are introduced.

## Planned fall death and entity activity - 2026-11-02

Agreed direction, not implemented: BaseLevel will coordinate a guarded on_death lifecycle, initially triggered only by falling below the active viewport. Concrete players own presentation; GameHandler owns session/world progress. Death is distinct from terminal shutdown. Add BaseLevel.reset_progress_on_death, default true, to select clearing versus retaining this level's block/collected-world-coin progress at restart; ordinary area travel remains persistent. Session counters and power-up/life/checkpoint rules are separate. Reference fall timing/audio still require investigation.

Off-camera activity is a separate proposed milestone: always-active, reversible suspension, terminal disposal and deferred activation policies, with camera margins and explicit persistence rules. Suspending saves processing; freeing saves memory. Do not replace current whole-area unloading or add unnecessary physics callbacks to static blocks. See the [implementation plan](death-and-entity-activity-plan.md) for ownership, open choices and verification checkpoints.

## Defer area soundtrack until suitable assets are ready - 2026-11-02

At the user's request, supersede active theme soundtrack playback for now: remove playback implementation, theme music properties/assignments and per-area Music Enabled configuration. Retain generic enter_area/exit_area occupancy hooks, entity SFX and unassigned audio assets. Keep shared test fixture paths, removing only music overrides; the previous music test now checks silent lifecycle behavior. Restore music only after suitable files are supplied and the [detailed backlog](backlog.md) is addressed. Fall death remains independent of soundtrack restoration.

## Pit death ownership and global world-progress policy - 2026-11-03

Supersedes the planned BaseLevel reset_progress_on_death=true setting: use GameHandler.reset_progress_on_death=false globally, preserving world progress by default. Do not deduct lives. BaseLevel coordinates optional presentation, world gameplay suspension, level-owned death audio and deferred restart; off-screen players immediately shut down/free. Preserve cosmetic animation, a deliberate difference from some reference enemy animation freezes. Generic suspension gates FSM callbacks while retaining state and collision for solid world objects; terminal shutdown remains separate. Save the active snapshot through shutdown before optionally clearing the level key, then reload at the real PlayerSpawn. Area soundtrack restoration and general off-camera spawning/disposal remain deferred. See [death lifecycle](death.md).

## Persistent screen-space HUD - 2026-11-03

Use a Game-owned CanvasLayer outside LevelContainer so every stage and future transition screen shares one HUD. ScreenContainer holds future screen content below HUD. Use a BMFont definition over the supplied alphabet texture instead of painting text into a TileMap or changing the PNG import type. Keep an 8px layout and native glyph advance, with static scene-authored values for this milestone. Adapt reference palette timing to the supplied three-frame Overworld coin atlas; area-specific UI variants and data binding remain deferred. See [UI](ui.md).

## Unified foreground shadow and player-over-HUD ordering - 2026-11-03

User clarification supersedes the independent CanvasLayer HUD: all world/UI/player foreground pixels must form one shadow, with Mario in front of HUD. Game owns a persistent SharedShadow CanvasGroup and UI becomes a camera-compensated Control. RenderingServer routing preserves logical gameplay hierarchy while ordering world, UI and player; pipe travel retains behind-world ordering. Disable the nested level composite only at runtime under Game, retaining base-scene standalone previews and per-level material authoring. Avoid duplicated shadow passes and physics reparenting. Rendered pixel assertions establish the overlap contract; see [shared shadow](level-shadow.md).

## Keep shared composition in screen space - 2026-11-03

Following reported moving-HUD fragmentation, replace inverse camera compensation on UI with a fixed Game CanvasLayer at layer 0. SharedShadow and UI stay in screen space; submit the final camera transform only on world/player render roots before draw. Disable additional interpolation on those proxy RIDs without changing descendant body interpolation or physics. This retains one shadow and player-over-HUD order, avoiding camera counter-motion on glyphs. Whole-image comparisons can include legitimate moving clouds through transparent UI gaps; the regression compares fixed foreground glyph pixels separately.

## Shared cosmetic phase sampling - 2026-11-03

Use one physics-tick clock as a child of existing GameHandler, with shared cycle resources and phase-change subscriptions instead of separate animation starts or per-object timers. Preserve the existing 24/8/8/8 phase durations. HUD coin continuously samples; question Active enables synchronization and releases it before bounce/used presentation. Keep the clock running through death suspension, area changes, reloads and session clearing. Theme artwork remains local. Future coins reuse the component; local action animation remains independent. No extra autoload registration is required. See [animation clock](animation-clock.md).

## Grounded run-release retention and directional clamp - 2026-11-03

At the user's request for closer reference movement, replace gradual same-direction run-to-walk slowing with a 10-tick per-player retention countdown and one-sided directional cap. BasePlayer advances the timer before FSM physics exactly once, matching DecTimers ordering; RunAction preparation reloads/selects profiles without advancing time. Retain run speed on released ticks 1-9, then clamp to effective walking speed on tick 10. Keep neutral braking, Slide and AirMovement ownership; higher-priority overrides remain effective. Full fixed-point/friction/animation-latch parity remains outside this scoped rule. See [movement](movement.md).

## Global covered transition lifecycle - 2026-11-03

Keep transition coordination under existing GameHandler and screen presentation in persistent Game. Cover must render before loading begins; work completion and physics-frame minima both gate reveal. Area swaps use full black including HUD to conceal theme changes. Level startup/respawn brackets a HUD-visible splash with two quick black phases. Use reference-derived defaults of 12 quick ticks and 147 card ticks, with explicit limits on exact NES timing claims. Preserve immediate load_level compatibility and opt out existing timing fixtures; test the enabled path separately. See [transitions](transitions.md).

## Neutral braking independent of Run - 2026-11-03

Select grounded neutral friction from speed and retained running history, following ChkRFast, rather than the held Run modifier. Carry that history explicitly into Jump and passive falling. Keep air neutral momentum and opposite-input braking; releasing Run alone does not impose an air speed cap. Preserve continuous Godot velocity rather than introducing a fixed-point integrator in this correction. See [movement](movement.md).

## Transition blanking and black background clarification - 2026-11-03

Use explicit world/player/HUD visibility changes plus an opaque full-viewport ColorRect to adapt the original display-blanking presentation to Godot. The original disables PPU background/sprite output; our cover is a presentation background and does not replace streaming, change area background colors or emulate PPU registers. Quick phases hide HUD; the intermediate splash shows HUD over black. Preserve reference-derived minimum timing as a deliberate adaptation, not an exact original frame trace. See [transitions](transitions.md#black-screen-original-and-godot-implementation).

## Area-themed HUD coin artwork - 2026-11-03

Reuse AreaTheme.texture_overrides for the supplied Underground HUD coin atlas instead of adding a second theme system. HUD owns private SpriteFrames/AtlasTexture resources and remaps canonical Overworld atlas references on area/level changes; no animation restart or clock reset occurs. Keep region layout/cadence and missing-art fallback. Quick transitions already hide HUD during area changes. See [UI](ui.md).

## Runtime coordinator dependency and deterministic regression sweeps - 2026-11-03

Create TransitionCoordinator by runtime script loading under GameHandler, keeping the transitions member dynamic to break the static script dependency back through GameHandler/BaseLevel. Empty-scene autoload stress changed from one native shutdown failure in thirty launches to zero in one hundred after this change. Keep normal lifecycle ownership and reject every nonzero engine exit in validation. Run bonk collision fixtures in physics callbacks so their sweep delta matches production rather than render cadence. Do not relax collision assertions or add retries to mask failures.

## Non-destructive SFX balance - 2026-11-03

Use a shared editable gain Resource for entity effects and level-owned death playback. Match relative source levels using measured active energy and the actual repeated skid burst, then tune by listening. Preserve recording dynamics, pitch and existing cancellation/lifecycle timing; do not permanently normalize source files or change import settings. Preserve original source identity on private one-shot copies so each path receives the same intended trim. See [audio](audio.md).

## Named transition definitions and display blanking - 2026-11-03

At the user's request, supersede the earlier ColorRect blanking decision: remove Cover and use hidden world/player/HUD with a temporary RenderingServer default clear color, restoring the previous value on all terminal paths. This does not modify Project Settings and assumes one active Game; future additional viewports need an explicit clear-color ownership policy. Extract the current intro into a Control scene and describe area/level holds, HUD visibility and expected replacement in Resource definitions. Keep lifecycle/cancellation shared, register unique named types, snapshot active configuration, and avoid hardcoded Card nodes or level-name presentation/replacement branches. Do not add game-over screens or session flow yet.

## Preserve the existing transition background - 2026-11-03

User clarified that removing Cover also meant removing the imposed black background. This supersedes the temporary clear-color portion of the preceding transition decision. Remove all renderer clear-color writes and background-color definition/stage properties. Hide gameplay as before and render presentation scenes against the existing viewport background. Named types, stages, timing and lifecycle ownership remain.

## Separate the connected stage from the test/menu sandbox - 2026-11-03

Rename the existing stage to 1-1, retaining both areas, painted data, scene UID and transport behavior. Keep Game and established regression fixtures pointing to that stage. Create the new TestLevel as a direct BaseLevel sibling with one fixed-screen Overworld area; do not derive it from the large stage or inherit its second area/routes. Reuse the entity palette and basic floor for testing, while leaving decorations/markers empty. Start-menu integration remains deferred per the user's instruction.

## GameHandler-owned title without a demo - 2026-11-03

Create TitleScreen and its TestLevel background through GameHandler, with explicit TITLE/STARTING/PLAYING flow and no transition on application boot. Suspend title Mario without disabling ControllerHandler; F6 testing of the background retains normal controls. Use the white HUD font for 1 PLAYER GAME, the supplied cursor, and no demo, second-player option or additional title text. Keep alphabet-alt for later copyright display. Start uses existing level presentation into 1-1 and initializes a fresh session. Consume confirmation input, reject repeated requests and defer failed/cancelled recovery using weak Game ownership to avoid rebuilding UI during tree removal. Menu presentation emits intent; session and loading decisions remain in GameHandler.

## Explicit entity controller capability - 2026-11-03

Default BaseEntity controller access to false; opt player and interactive pipe scenes in explicitly. Synchronize actual global signal connections on initialization, property changes, suspension and shutdown rather than dispatching events into every static block. Gate player/pipe direct polling through the same capability, and prevent dead players reconnecting. Keep per-state input controls separate from entity eligibility. This first step does not change frame/physics scheduling, free placed objects or implement enemy spawners. No measured memory/performance claim is made beyond removing unnecessary input subscriptions/dispatch.

## Buffered activity belongs to BaseArea - 2026-11-03

User specified area ownership because unoccupied area runtimes already unload. Use the area camera and two editable margins (64-pixel activation, 96-pixel deactivation), centralized weak registrations and geometry bounds rather than a global manager or notifier on every object. Preserve placed-object instances/collision/progress; independently gate activity and gameplay suspension. EnemySpawner alone owns disposable actors, with reentry rearming to avoid repeated respawning near one spawn point. This adapts reference offscreen policies rather than claiming exact NES thresholds. Initial implementation scans registered objects; optimize further only with measurements.

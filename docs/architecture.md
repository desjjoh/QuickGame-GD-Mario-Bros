# Architecture

## Ownership

| Owner | Responsibility |
| --- | --- |
| Game | Registers its LevelContainer and initial level with GameHandler |
| GameHandler | Replaces levels; holds current game/player/session values and persistent-in-session area progress |
| BaseLevelArea | Owns area metadata/templates and loads/frees its runtime layouts, world objects, and camera |
| AreaTheme | Selects compatible TileSets and entity texture replacements with fallback |
| BaseLevel | Generates area entities, spawns the player, coordinates deferred area transfer/cameras, updates bounds, composites the shadow, and shuts down entities |
| BaseEntity | Owns its state machine, callback forwarding, exclusive sound effects, and terminal shutdown |
| BasePlayer | Owns the physical body, AnimationPlayer reference, movement/actions, facing, and ceiling response |
| Mario | Supplies sprites, collision override, concrete states, animation library, and WalkAnimation component |
| BaseBlock | Supplies a solid 16x16 body and sprite with a top-left grid origin |
| QuestionBlock | Owns Active/Bouncing/Inactive states, one-shot hit activation, used artwork, and a sprite bounce |
| ControllerHandler | Samples one global controller's input intent |

## Scene composition

```text
BaseEntity
\-- StateMachine

BasePlayer [inherits BaseEntity]
+-- Body [CharacterBody2D]
|   +-- CollisionShape2D
|   \-- AnimationPlayer
+-- Motion [MotionValues script]
|   +-- HorizontalMovement
|   +-- AirMovement
|   +-- Gravity
|   \-- CornerCorrection
\-- Actions
    +-- Run
    +-- Jump
    +-- Slide
    \-- Bonk

Mario [inherits BasePlayer]
+-- StateMachine: Idle, Move, Slide, Jump, PipeEnter
+-- Body: small collision override, Sprite2D, walk animation library
\-- Presentation
    \-- WalkAnimation

BaseBlock [inherits BaseEntity]
+-- Body [StaticBody2D]
|   \-- CollisionShape2D
+-- Sprite2D
\-- Presentation
    \-- Bounce
```

Presentation is owned by Mario rather than an empty container on BasePlayer. BasePlayer owns its Body/AnimationPlayer reference; Mario supplies its animation library. Empty inherited state machines are intentional and valid for blocks and the generic player. They are extension points, not extra independently processing states.

```text
BaseLevel [CanvasGroup]
+-- Areas
|   +-- MainArea [BaseLevelArea]
|   |   +-- Layouts [fixed 16x16 grid]
|   |   |   +-- DecorationLayout
|   |   |   +-- GroundLayout
|   |   |   \-- EntityLayout
|   |   +-- WorldObjects
|   |   +-- Arrival [default endpoint]
|   |   +-- Endpoints [named markers]
|   |   \-- Camera2D
|   \-- LowerArea [same area foundation, Underground theme]
+-- Enemies
\-- Players
    \-- PlayerSpawn
```

BaseLevel owns an Areas container with a reusable MainArea foundation; TestLevel adds LowerArea. Each area selects an AreaTheme, supplies painted cells, and owns its compatible TileSets, generated WorldObjects, and camera. BaseLevel's entity_layout/world_objects properties refer to MainArea for convenience; generation processes each area when its runtime loads. These MainArea convenience properties return null while MainArea is unloaded. Players remain level-owned and normally draw after all area content, including pipes. During transport entry and emergence, their group draws before Areas and is restored on arrival/cancellation. Layout groups enforce identity local transforms and 16x16 square cells. All contributing visuals remain Z=0 so the shared shadow sees their combined silhouette. See [area themes](level-themes.md).

Scene inheritance is BaseLevel -> TestLevel, BaseEntity -> BasePlayer -> Mario, and BaseEntity -> BaseBlock -> BrickBlock/QuestionBlock. AlternateBrickBlock inherits BrickBlock and overrides only its sprite texture. Scripts follow the corresponding inheritance; concrete blocks use BaseBlock directly and QuestionBlock and BrickBlock supply shared block-state scripts. States inherit BaseState -> EntityState -> PlayerState -> Mario's concrete state scripts. Shared PlayerState lives under scripts/states/player/.

## Startup and shutdown

1. Godot creates GameHandler and ControllerHandler autoloads.
2. Game registers itself and LevelContainer, then asks GameHandler to load the initial level.
3. Areas apply their theme TileSets; BaseLevel unloads inactive runtime branches, restores/generates the starting area's EntityLayout under its WorldObjects, assigns visual_theme and saved progress before startup, then spawns Mario under Players.
4. BaseEntity initializes the machine and presentation callbacks, starts the initial state, and subscribes to input.
5. GameHandler records the player and emits level_changed.

Startup uses synchronous scene instantiation and _ready(). Asynchronous loading, separate activation phases, a GameScene superclass, and pooling/restart contracts are not implemented.

Before replacement, GameHandler calls old_level.shutdown(), then removes and queues the level for deletion. BaseLevel shuts down descendant entities. Entity shutdown disables updates, disconnects input and animation callbacks, deactivates the active state without standard exit presentation, and stops animation/audio. Cleanup hooks and signals still run. Shutdown is terminal and idempotent; tree exit is a fallback. Explicitly shut down an entity before independently removing it. Extend shutdown with super.shutdown() and keep subclass cleanup safe against repeated calls. See [state machine](state-machine.md).

## Movement and presentation

The physical Body is a child of the entity root. Movement, camera targeting, interactions, and sound parenting must use Body's world position rather than the stationary root. The feet are the body origin. BasePlayer has a generic 16x16 shape at (0,-8); small Mario overrides it with an 11x14 rectangle at (-0.5,-7), while his sprite remains 16x16 at (0,-8). This approximates terrain probes rather than reproducing every NES foot/enemy collision test.

Motion carries shared defaults and named priority modifiers through MotionValues. Body remains authoritative for velocity. Components do not process independently: states coordinate their use. Actions contains Run, Jump, Slide, and Bonk; Motion contains continuous physics and corner correction; Mario's Presentation contains animation cadence.

Idle, Move, and Slide refresh Run before checking deliberate takeoff. Move handles grounded travel and passive falling. It freezes the current walk pose and loop phase when unsupported and resumes velocity-based cadence on landing. Jump begins only from a successful grounded Jump action and keeps its pose through ascent/descent until landing. Both unsupported paths use AirMovement, with cleanup on landing/exit. Holding input during a fall does not enable a midair jump.

BasePlayer.move_body() applies bounded corner correction, integrates body movement, and handles solid-ceiling bumps. States do not call body movement a second time. Horizontal camera-edge clamping runs after player physics. See [movement](movement.md), [jumping](jumping.md), [corner correction](corner-correction.md), and [camera](camera.md) for values and approximation limits.

Each entity plays one sound effect at a time; jump, bump, skid, and state effects replace one another. Different entities have independent channels. Skid uses repeated short bursts while grounded and sliding. Stopping a previous skid cannot stop a newer jump sound.

## Level content and assets

The main test area has 944 pixels of horizontal space, ground top Y=208, PlayerSpawn=(48,208), and initial camera center=(128,120). Its world bounds are 0/944 with right-only tracking. LowerArea currently sits at (896,240), with a disabled fixed camera centered at world (1024,360). Painted transport entities use explicit area/target IDs within or between areas. BaseLevel.transport coordinates entry, destination loading, camera handoff and emergence. Destination pipes supply their exit geometry without adjacent markers. Upright and inherited left-facing entrances share travel behavior. Pit death and PlayerSpawn restart are implemented; visible hit-death presentation, lives and checkpoints remain future work.

GroundLayout renders solid terrain directly. DecorationLayout renders collision-free bushes, hills, and clouds directly on the same 16x16 grid. Each area's EntityLayout is a collision-free authoring layer: its entity_id custom data maps through Entity Scenes to actual BaseEntity scenes under WorldObjects. It hides at runtime. Each spawned entity owns its own collision, detection, and behavior; the spawner does not impose solid collision. See [entity layout](entity-layout.md) and [question block](question-block.md).

Environment art is theme-first under assets/Overworld (Palette 1) and assets/Underground (Palette 2). Shared TileSet resources stay under assets/tileset. Player art stays under assets/player/mario (small); audio stays under assets/sfx. Area themes select compatible TileSets and entity artwork at startup; live theme changes remain deferred. See [level themes](level-themes.md).

## Verification and limits

See [verification](verification.md) for the complete test command and scope. Movement remains an approximation of the reference: fixed-point arithmetic, original countdown phases, several collision probes, and update ordering are not cycle-accurate. Gameplay input represents one global controller; session values are memory-only. Enemies, rewards, brick breaking, runtime themes, and checkpoints/game over remain future milestones. Pit death now restarts the level at PlayerSpawn; see [death lifecycle](death.md).

TransportEntity inherits BaseEntity and supplies entry eligibility, a destination resource, opening geometry and a PlayerTransportState. PipeEntrance implements this contract with 2x2 solid collision and the existing ControllerHandler input/ground/alignment checks. Future transport types can provide their own state. BaseLevel.transport validates explicit area/target IDs, coordinates loading and cameras, and records current_area_id/current_target_id in GameHandler. Shared session state is preserved.

PlayerPipeEnterState inherits PlayerTransportState. The level waits for travel_finished before each deferred handoff/completion. Painted TransportPlacement resources stay resident with area metadata; runtime pipe entities provide final feet position, exit direction and distance after loading. No separate arrival marker is required for a pipe target. Legacy spawn endpoints remain compatible. See [transport](transport.md) and [pipes](pipes.md).

Only the occupied area keeps runtime nodes. Inactive roots retain endpoint/configuration metadata and packed definitions for routing; runtime layouts, entities, camera, and collisions are freed. GameHandler preserves used/removed block and tile progress for recreation. All areas remain editable in the local scene. See [area lifecycle](areas.md).

Area music is deferred pending suitable sound files; see the [music restoration backlog](backlog.md#restore-area-music-when-suitable-sound-files-are-available). Area entry/exit hooks remain available; entity SFX are unchanged.

BaseLevel owns pit-death detection and world suspension. BasePlayer owns optional presentation and terminal cleanup; GameHandler restarts the loaded level and applies its global reset_progress_on_death policy (default false). Death audio is level-owned and separate from deferred area soundtracks. See [death lifecycle](death.md).

Game also owns UI (a screen-space Control) and SharedShadow. The compositor combines world, UI and foreground player into one shadow using render-only routing; logical gameplay parents remain intact. HUD survives level replacement and draws above ScreenContainer transition content, while Mario normally draws above HUD. Game is a fixed CanvasLayer; its 8x8 UI stays at identity while only world/player render roots receive the camera matrix; see [UI](ui.md) and [shadow composition](level-shadow.md).

GameHandler also owns a single CosmeticAnimationClock child. Shared cycle resources drive HUD coin and Active question-block presentation through phase-change subscriptions, independent of entity gameplay suspension and local player/action animation. Late-loaded objects join the current phase; shutdown unregisters them. See [animation clock](animation-clock.md).

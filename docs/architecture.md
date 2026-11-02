# Architecture

## Ownership

| Owner | Responsibility |
| --- | --- |
| Game | Registers its LevelContainer and initial level with GameHandler |
| GameHandler | Replaces levels; holds current game, level, player, and in-memory session values |
| BaseLevelArea | Owns area layouts, generated world objects, arrival marker, camera, and selected theme |
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
+-- Players
|   \-- PlayerSpawn
\-- ForegroundObjects [pipe visuals]
```

BaseLevel owns an Areas container with a reusable MainArea foundation; TestLevel adds LowerArea. Each area selects an AreaTheme, supplies painted cells, and owns its compatible TileSets, generated WorldObjects, and camera. BaseLevel's entity_layout/world_objects properties refer to MainArea for convenience; generation processes every area. Players remain level-owned and draw after ordinary area content; ForegroundObjects then draws pipe visuals over players. Layout groups enforce identity local transforms and 16x16 square cells. All contributing visuals remain Z=0 so the shared shadow sees their combined silhouette. See [area themes](level-themes.md).

Scene inheritance is BaseLevel -> TestLevel, BaseEntity -> BasePlayer -> Mario, and BaseEntity -> BaseBlock -> BrickBlock/QuestionBlock. AlternateBrickBlock inherits BrickBlock and overrides only its sprite texture. Scripts follow the corresponding inheritance; concrete blocks use BaseBlock directly and QuestionBlock and BrickBlock supply shared block-state scripts. States inherit BaseState -> EntityState -> PlayerState -> Mario's concrete state scripts. Shared PlayerState lives under scripts/states/player/.

## Startup and shutdown

1. Godot creates GameHandler and ControllerHandler autoloads.
2. Game registers itself and LevelContainer, then asks GameHandler to load the initial level.
3. Areas apply their theme TileSets; BaseLevel generates each area's EntityLayout under its WorldObjects, assigning visual_theme before startup, then spawns Mario under Players.
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

The main test area has 944 pixels of horizontal space, ground top Y=208, PlayerSpawn=(48,208), and initial camera center=(128,120). Its world bounds are 0/944 with right-only tracking. LowerArea currently sits at (896,240), with a disabled fixed camera centered at world (1024,360). Painted PipeEntrance entities support travel to named endpoints within or between areas, including active-area and camera selection. Pipe entry animates before the destination handoff; exit animation, death, and respawn remain unimplemented.

GroundLayout renders solid terrain directly. DecorationLayout renders collision-free bushes, hills, and clouds directly on the same 16x16 grid. Each area's EntityLayout is a collision-free authoring layer: its entity_id custom data maps through Entity Scenes to actual BaseEntity scenes under WorldObjects. It hides at runtime. Each spawned entity owns its own collision, detection, and behavior; the spawner does not impose solid collision. See [entity layout](entity-layout.md) and [question block](question-block.md).

Environment art is theme-first under assets/Overworld (Palette 1) and assets/Underground (Palette 2). Shared TileSet resources stay under assets/tileset. Player art stays under assets/player/mario (small); audio stays under assets/sfx. Area themes select compatible TileSets and entity artwork at startup; live theme changes remain deferred. See [level themes](level-themes.md).

## Verification and limits

See [verification](verification.md) for the complete test command and scope. Movement remains an approximation of the reference: fixed-point arithmetic, original countdown phases, several collision probes, and update ordering are not cycle-accurate. Gameplay input represents one global controller; session values are memory-only. Enemies, rewards, brick breaking, runtime themes, and respawn remain future milestones.

PipeEntrance is a BaseEntity with solid 2x2 pipe collision. It requests BaseLevel area transfer through ControllerHandler input and alignment/ground checks. The level owns camera selection and records current_area_id/current_endpoint_id in GameHandler; other shared session state is preserved. See [pipes](pipes.md).

Animated pipe entry is coordinated by BaseLevel and the concrete player's assigned PlayerPipeEnterState. It suspends normal player movement/collision and source camera updates, then uses the existing named-endpoint transfer after descent. Cancellation and shutdown restore temporary state.

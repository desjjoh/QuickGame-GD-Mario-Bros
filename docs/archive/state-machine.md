# Entity state machine

Every BaseEntity scene contains a StateMachine instance. Its direct children are states. BaseEntity initializes and starts it in `_ready()` after the children and exported node references are available. Empty machines are valid; machines with states need an Initial State assigned in the Inspector.

The script inheritance hierarchy is `BaseState Ã¢â€ â€™ EntityState Ã¢â€ â€™ PlayerState`, with MarioIdleState, MarioMoveState, MarioSlideState, and MarioJumpState as concrete specializations. The shared PlayerState script lives in `scripts/states/player/`. BasePlayer has no concrete state nodes; Mario owns Idle, Move, Slide, and Jump under `scenes/player/mario (small)/states/`. State scenes can be added later when states share meaningful child-node structure.

## Inspect Mario

Open `scenes/player/mario (small)/mario.tscn`. Expand StateMachine and select Idle. The Inspector exposes processing switches, presentation options, and control permissions. At runtime, use the Remote scene tree to inspect the spawned Mario and its machine's current state.

Mario starts in static Idle. ControllerHandler's horizontal intent triggers Move, whose Animation Name is `walk`. Select Motion (which carries MotionValues) to tune walk defaults, Actions/Run for run overrides, and Mario's Presentation/WalkAnimation for velocity-based cadence. Idle stops playback and selects its standing texture without an idle animation. The Jump action has a takeoff sound; state enter/exit sound slots remain unassigned. Jumping, passive falling, and gravity are implemented; see [jumping](jumping.md). See [movement](movement.md) for movement values and animation timing.

Opposing input at speed triggers Slide. Its entry/exit hooks apply/remove the Slide action's modifier, and its physics hook brakes through the velocity proxy. Idle and Slide select static standing/skid textures. Move selects the first walking texture on entry and then its looping AnimationPlayer texture track cycles through all three poses. A null Sprite Texture preserves the existing texture. Facing flips remain controlled by movement. See [movement](movement.md) for thresholds, cancellation, and source-fidelity limits.

## Add a state

1. Add a Node directly under StateMachine and attach a script extending PlayerState (or EntityState for non-player entities).
2. Give it a unique node name and configure its exported properties.
3. Override the hooks you need: `enter()`, `exit()`, `update(delta)`, `process_physics(delta)`, `process_input(event)`, or `animation_finished(animation)`.
4. Return `state_machine.get_state(&"OtherState")` from an update/input/animation hook to transition; return null to remain in the current state.

`enter()` and `exit()` are synchronous and must not await or initiate another transition. The machine rejects nested transitions while either hook runs. Same-state requests do not restart a state. Returned destinations must belong to the same machine. States are registered once during initialization; runtime state registration is not implemented.

The machine calls BaseState's `deactivate()` and `activate()` wrappers. Override `enter()` and `exit()`, not the wrappers. The sequence is:

1. Old state's `exit()` hook, optional exit animation/sound, then `exited` signal.
2. Assign the destination state.
3. Apply its sprite properties and optional animation/sound, call `enter()`, then emit `entered`.
4. Emit `state_changed(previous, current)`.

Additional actions can run in the hooks or be connected to the `entered`/`exited` signals. These run synchronously within the transition guard: do not initiate another transition from them. `stop()` deactivates once and clears the active state; `start()` selects the initial state again. Entity startup starts the machine immediately. Entity shutdown calls machine.shutdown(): a terminal stop that runs cleanup and signals without exit presentation, and rejects subsequent start/change-state requests. If requested from an enter/exit hook, shutdown completes after that guarded transition unwinds. Ordinary stop()/start() remains restartable.

## Processing and presentation

The entity forwards frame and physics callbacks to the machine. ControllerHandler input events are opt-in through BaseEntity.controller_input_enabled (default false); BasePlayer and interactive PipeEntrance scenes enable it. Suspension, opt-out and shutdown disconnect input; eligible resume reconnects once. See [entity activity](entity-activity.md). The machine calls only the active state's enabled hooks. States use disabled process mode to prevent independent engine processing, but their methods are called manually. Frame/physics switches affect state hooks only; they do not disable collisions, animations, or other components. Keep physics movement in `process_physics()` and presentation updates in `update()`.

BaseState owns sprite visibility, frame selection, offset, tint, optional enter/exit animation names, and enter/exit sound streams. Stop Animation On Enter supports static poses; Sprite Frame = -1 preserves the current frame. EntityState remains an inheritance extension point. Enter effects run before `enter()` so overriding the hook cannot skip them. Sprite values are reapplied on entry, not restored on exit. Horizontal offsets mirror with facing by default; BasePlayer refreshes them when facing changes. Sprite node position is separate from the per-state offset, preserving the feet-based origin.

A blank animation name leaves playback unchanged. Missing animations produce a warning. Exit animations are immediate cues, not awaited transition sequences: the next state's enter animation can replace them immediately. Finished-animation events go to the currently active state; check the animation name before acting.

Sound streams are optional, non-looping one-shots. BaseEntity creates an AudioStreamPlayer2D under its effects parent and queues it for removal when finished. BasePlayer uses Body as the parent to follow physical movement. Each new effect immediately stops the previous effect for that entity. Different entities retain independent channels. Shutdown suppresses standard exit presentation, rejects new effects, and stops active audio; custom exit hooks must keep presentation separate from cleanup. Audible output and resource looping must be checked when actual sound assets are supplied.

The entity exposes optional sprite and AnimationPlayer references in the Inspector. Nonvisual entities can leave them empty. Subclasses overriding BaseEntity's engine callbacks must call `super` to preserve machine initialization and forwarding.

## Controls

PlayerState defines Controls Enabled. It gates state input forwarding; controller_controls_available also requires the entity controller capability and active lifecycle before movement/Run/Jump polling. Individual states decide which actions they accept. Idle and Move call `prepare_horizontal_motion()` to update Run and read held intent during physics updates. Move treats disabled controls as zero intent and brakes; disabling controls does not forcibly zero velocity. Gameplay events come from ControllerHandler's `_unhandled_input()` so UI can consume events first. Held inputs are sampled globally on physics ticks, before normal entity physics, through existing UI actions and the approved secondary binding for Run. Held-input polling does not observe UI event consumption: UI must gate gameplay consumers through their entity/state availability or disable ControllerHandler when appropriate. Title keeps global menu input active while suspending its background player. Disabling it clears the held snapshot immediately.

## Global handlers

GameHandler and ControllerHandler are autoloads under `scripts/handlers/`. GameHandler owns level replacement, references to the active game/level/player, and session values via `set_session_value()` and `get_session_value()`. Session values survive level replacement but are in memory only. `clear_session()` clears them explicitly. Game attaches its level container and requests the initial level; BaseLevel still owns player spawning. Levels run independently with F6, but a standalone level is not registered as GameHandler's active level. Call level replacement outside physics callbacks; callers responding to physics events should defer it.

ControllerHandler exposes directional strengths, `input_primary`, `input_secondary`, `input_start`, `input_select`, `get_axis()`, and the `input_received` signal. Secondary is bound for Run; Start is bound for the single-player title, while Select remains unassigned. Unassigned or missing actions read false without querying nonexistent bindings. All held inputs clear when the handler is disabled. States access this shared input source instead of polling Godot Input themselves. It currently represents one global controller, not separate local-player devices. No input buffer or remapping UI is implemented.

## Verification

See [verification](verification.md) for the complete regression runner, coverage, logs, and limits. All test scenes load normal project autoloads. State tests cover ownership, routing, presentation, and terminal shutdown; gameplay tests exercise synthetic controller input through real physics callbacks.

## Block hit states

EntityState.receive_hit defaults to rejection. BaseBlock routes EntityHit messages to its current state. ActiveBlockState accepts a configured upward maneuver and transitions to reaction_state. BouncingBlockState rejects additional hits and owns bounce startup, advancement, and exit cleanup. Its return_state is Inactive for question blocks and Active for bricks. Question-block Inactive uses EntityState's default rejection and presentation exports without processing updates.

Connect Bouncing's inherited entered signal for reaction hooks; its Enter Sound Effect setting can supply state-entry audio. bounce_completed fires once on natural completion before transition, never on shutdown/interruption. exited is a cleanup notification and can also occur on shutdown. No item spawning or extra audio is currently wired. See [question block](question-block.md).

## Controlled pipe entry

Mario owns PipeEnter using PlayerPipeEnterState, which inherits the shared PlayerTransportState contract. BasePlayer exports the concrete reference; TransportEntity supplies the appropriate state for a source/destination. BaseLevel.transport reserves and validates explicit target IDs, freezes camera/clamp updates during travel, and commits deferred phase transitions on travel_finished. Normal states do not activate between entry and emergence. State exit restores collision/visibility; uncommitted exit also restores position and stops entry audio. BaseState retains the entry audio handle for ownership-sensitive cleanup. The legacy descent_finished signal remains available on PipeEnter. See [transport](transport.md).


## Area unload and logical state

Area unload captures logical progress before entity shutdown and frees the instances. Returning constructs new entities and applies restore_area_state before FSM startup; it does not restart shut-down machines. BaseBlock saves Active/Inactive, resolving a Bouncing state's return_state to avoid replaying one-shot reactions. GameHandler owns the snapshots. See [area lifecycle](areas.md).

## Movement handoff versus completed movement

PlayerState.continue_physics transfers an unconsumed physics tick to another state through the normal FSM lifecycle. Only pre-movement transitions use it. Landing and other transitions after move_body return a state without running another movement step. Terminal shutdown or a state changed by an observer stops the handoff. See [movement ownership](movement.md#physics-ownership-across-state-changes).

States may optionally reference Synchronized Animation for cosmetic cycles. Activation enables the component after enter presentation; deactivation disables it before exit, giving the next state full sprite ownership. This samples the global clock rather than independently playing a timeline. Entity shutdown also disables descendant synchronization components. See [animation clock](animation-clock.md).

Area activity now supplies an independent suspension gate alongside gameplay suspension. Sleeping pauses frame/physics callbacks, input and cosmetic sampling; waking resumes the same state without activate/deactivate hooks and cannot undo death/title/transition suspension. This does not yet schedule away resting-state BaseEntity callbacks inside the camera activity region. See [entity activity](entity-activity.md).

# Entity activity

## Implemented: controller input is opt-in

BaseEntity exports Controller Input / Controller Input Enabled, default false. Ordinary bricks, question blocks and other entities therefore do not subscribe to ControllerHandler.input_received. BasePlayer and PipeEntrance scenes explicitly enable the capability; derived player/sideways pipe scenes inherit it. New interactive entities can opt in in their scene Inspector.

The capability is independent of the active state's input_enabled/controls_enabled settings. BaseEntity connects eligible entities after initialization, prevents duplicate connections, updates the subscription when the property changes, disconnects during gameplay suspension and reconnects only when still enabled on resume. Shutdown permanently prevents reconnection. BasePlayer additionally rejects controller access after death.

Direct held-input polling also obeys the capability. PlayerState.controller_controls_available combines the state's Controls Enabled with entity availability; horizontal/Run/Jump reads use it. Pipe entrance eligibility and polling check can_read_controller_input before reading controller intent. Custom entity polling must use the same helper. This does not disable the global ControllerHandler or title-menu input.

This removes unnecessary per-input dispatch and retained signal subscriptions. Entity nodes, state machines, collisions and shared artwork remain allocated. No quantified net-memory saving is claimed; meaningful instance-memory reduction would require freeing/deferred spawning, which the input opt-in change alone does not provide. Buffered activity and spawner ownership are described below.

## Area-owned camera activity

BaseLevelArea owns registration and one centralized physics pass, after BaseLevel updates its camera. No global activity handler or per-entity visibility notifier is added. Only the occupied area's runtime is loaded; area exit suspends its registered entities and unload clears registrations with the runtime branches. Players remain the level's responsibility and are excluded.

In the area Inspector, Camera Activity exposes Activation Buffer (64 pixels / four tiles) and Deactivation Buffer (96 pixels / six tiles). Sleeping entities wake when their geometry intersects the smaller camera region; awake entities sleep beyond the larger one. Deactivation is clamped to at least the activation distance. These editable defaults are modern hysteresis choices, not exact NES constants. The [reference disassembly](https://gist.github.com/1wErt3r/4048722) uses offscreen bounds and enemy-specific erasure exceptions; this project preserves its buffered approach with explicit scene ownership.

The region uses the area's own centered, unrotated Camera2D world position, logical viewport size and zoom, matching current level cameras. Custom camera offsets, rotation or smoothing require extending this calculation. Entity bounds combine cached collision-shape and sprite references using their current global transforms, so moving child bodies count even when the entity root stays still. Call refresh_activity_geometry after adding/replacing geometry, or override get_activity_rect for specialized entities. Registration happens once during BaseEntity readiness; the area prunes dead weak references. The centralized pass still scans registered entities each physics tick; spatial partitioning and large-stage CPU/memory benchmarks remain future work.

Placed blocks and pipes remain instantiated, with collision and logical state intact. Off-camera activity disables their frame/physics callbacks and those of existing descendants, disconnects controller input, freezes AnimationPlayer/AnimatedSprite2D playback speed and unsubscribes shared cosmetic animations. Wake restores previous callback/speed settings and samples the current shared animation phase. No enter/exit state hooks, rewards or sound events replay merely because the camera moves. Existing short one-shot audio is allowed to finish.

Activity suspension is independent of gameplay suspension used by death, title and transitions. Effective state-machine/physics/input suspension lasts while either gate is set; waking cannot override a gameplay freeze. Cosmetic animation can continue during gameplay suspension while on camera. Custom components added while already asleep must adopt their owner's activity policy before enabling callbacks. Collision layers/shapes and process_mode are not disabled for sleeping placed objects.

Resting blocks inside the activity region still receive BaseEntity callbacks, although their state hooks are disabled. State-driven engine callback scheduling is a separate optimization; this milestone targets off-camera work.

## Enemy spawner foundation

Instance scenes/entities/spawners/enemy_spawner.tscn under an area's WorldObjects. Position its marker and assign Enemy Scene to a non-player BaseEntity-derived scene. The spawner has no independent update callbacks; BaseArea drives it. A fresh instance inherits the area theme before readiness and is placed at the spawner origin.

An enabled, armed spawner creates at most one actor within the activation region. The actor is shut down and queued for disposal when its geometry leaves the outer region or it has shut down itself. Disabling the spawner disposes its actor. After disposal/death, it cannot immediately create another while the camera remains nearby. With Respawn On Reentry enabled (default), the spawn point must leave the outer region and reenter the inner region to rearm; false means one attempt per loaded area visit. Area unload releases actors with their spawner. Existing actors retain death/transition suspension, and fresh spawning is blocked while the parent level is shut down, dying, transitioning or not processing physics (including title backgrounds).

This is a reusable foundation, not enemy AI or defeated-enemy persistence across area reloads. No enemy spawners are painted/placed in the shipped levels. Enemy placement rules, enemy-specific respawn policies, pooling and persistent defeat records remain future work. Placed blocks never use this disposal path.

## Verification

entity_input_test checks default entity/block opt-out, explicit player/pipe scene opt-in, actual signal delivery/counts, duplicate prevention, runtime toggles, suspension/resume, polling gates and dead/shutdown cleanup. Existing controller, movement, pipe, death and title tests provide gameplay integration coverage. CPU time and retained memory have not been benchmarked for a large stage.

entity_activity_test checks actual callback counts, input availability, hysteresis, stable placed-object identity/state, live sleeping collision, shared cosmetic phase on wake, independent suspension gates, moving-child enemy disposal, reentry rearming and runtime-unload cleanup.

## Painted power-up spawners

The 1-Up Spawner stamp creates an EntitySpawner when the area loads. On its first eligible camera activation, the spawner attempts to claim a power-up slot from BaseLevel. The level currently allows one live power-up. If two markers activate in the same camera pass, the first checked claims the slot. A blocked or failed attempt spends that placement's attempt for the current area load. Clearing the slot or moving the camera away and back cannot trigger a late spawn.

Collection and offscreen disposal free the mushroom and release its slot on tree exit. Only collection records consumption, subject to the placement and level progress rules. An area reload creates a fresh placement unless saved progress marks it consumed. The separate EnemySpawner still follows its own reentry policy. Enemy and fireball limits and question-block power-up release remain future work.

## Painted Goomba spawners

The Goomba stamp uses EntitySpawner with the enemy category. It attempts once when its marker enters the camera activation region. Five live enemy slots are shared with EnemySpawner and are independent of the power-up slot. If an attempt fails, the marker stays empty for the rest of the area load. Live Goombas free themselves after their full bounds leave the cleanup region. A successful legacy EnemySpawner can still rearm according to its authored reentry policy.

## Goomba pairs in 1-1

The Overworld EntityLayout includes Goomba Pair Spawner. A pair uses one marker and attempts both members in the same camera pass, 24 pixels apart. Each Goomba takes one enemy slot. If only one slot is free, the second member is skipped for that area load.

When the pair marker activates, both members start walking together as long as their bounds intersect the outer camera buffer. This keeps the rear Goomba from waiting for its own bounds to enter the inner activation buffer.

## EnemyLayout and defeat

Paint enemies in EnemyLayout on its 8×8 grid. The migrated markers in TestLevel and 1-1 retain their world positions. The marker uses the same activation boundary and cap as before. Defeat and offscreen cleanup both release the live slot when the actor exits. Enemy defeats are not saved, so enemy placements get a fresh attempt on area reload or death restart.

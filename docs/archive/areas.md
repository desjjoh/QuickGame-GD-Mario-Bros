# Area runtime lifecycle

Only the occupied area's runtime content remains loaded. Area roots, Arrival/Endpoints markers, theme/transport configuration, and packed authoring definitions remain available as lightweight routing metadata. Inactive areas free their tile layers, collision objects, generated entities, camera, and other authored runtime branches; they are not merely hidden or paused.

## Entry and exit lifecycle

BaseLevel calls `enter_area()` only when an area becomes occupied, after loading content and selecting its camera. It calls `exit_area()` through unload and on level shutdown; tree removal is a cleanup fallback. Entry/exit are idempotent and maintain is_active. Loading a destination for validation does not activate it.

Area music is currently removed pending suitable sound files. Areas create no soundtrack player, and themes expose no music configuration. Entity sound effects remain independent and enabled. See the [music restoration backlog](../backlog.md).

## Editor and runtime

The local editor scene still contains every area's full editable Layouts and camera. BaseLevel is not a tool script, so runtime unloading does not alter the saved stage. In the running game's Remote tree, inactive area roots retain Arrival and Endpoints but have no Layouts, WorldObjects, or Camera2D. Their runtime_loaded flag is false, their root is hidden, and processing is disabled.

At startup BaseLevel captures each area's authored runtime branches as PackedScene templates before generating marker entities. It removes inactive runtime branches and loads MainArea. Only that area's entities are generated. Shared player ownership stays on BaseLevel.

During pipe entry the source remains loaded while Mario descends; the destination remains unloaded. Painted transport IDs are retained as per-cell metadata without keeping their entities alive. At the hidden handoff, BaseLevel validates the explicit destination metadata, recreates/restores its runtime, resolves the destination entity and its exit position, selects its camera, saves the old area's progress, shuts down its entities and frees its runtime branches. The result is one loaded area after the transaction. Same-area transport does not reload its existing runtime.

Pipe artwork remains a child of its entity and is freed naturally when its area unloads. Every unloaded entity explicitly shuts down its FSM, sounds, and input subscriptions before being freed. Returning creates new instances rather than restarting terminally shut-down entities.

## Progress ownership

The user selected preserving progress on return. GameHandler owns area snapshots through store_area_progress/get_area_progress, with one selected level scene identity and a dictionary keyed by area_id. Loading another logical level replaces that store. Data is copied at the API boundary and stays in memory; no disk save system is implemented.

Current snapshots retain:

- Painted/runtime cell data for the area's TileMapLayers.
- Logical block states, including used question blocks.
- Removed marker-generated entities, so they do not respawn on return.

A Bouncing block saves its logical destination state, not the temporary bounce. Thus a consumed question block restores directly to Inactive without replaying the bounce, while an ordinary brick returns Active. BaseBlock retains its last logical snapshot during terminal cleanup so tree-exit ordering cannot erase progress before the level captures it.

BaseEntity.capture_area_state and restore_area_state are extension hooks for future entity types. Restore is called before the entity enters the tree. These hooks should return plain progress data rather than Node references. Future enemies/items must define their own persistence rules; arbitrary actor velocities, animation phases, and manually authored entity state are not automatically preserved.

Named registered level scenes retain snapshots across same-level instance recreation. Loading a different level discards the old visit; returning later starts fresh. Anonymous fixtures and standalone levels use instance-scoped keys discarded on terminal shutdown. GameHandler.clear_session clears cached progress; rebuilding an already loaded world's contents is a separate operation.

## Loading limits

This unloads runtime nodes and physics, not every shared asset resource. Packed definitions, themes, TileSets, and shared textures remain cached for reconstruction and routing. It does not promise full VRAM eviction, disk streaming, asynchronous loading, or zero-cost activation of very large areas. Areas are authored before startup; dynamic area registration is not implemented.

## Verification

area_streaming_test verifies inactive physics has no floor collision, inactive nodes and entity instances are actually freed, endpoints remain resolvable, and repeated visits do not duplicate actors or pipe artwork. Used/removed blocks and tile edits survive visits and level replacement; clearing stored progress is also checked. The pipe entry/rendered checks verify that the destination is still unloaded during descent and the source is unloaded after handoff.

## Inherited scene identity

BaseArea's authored nodes retain Godot-generated unique scene IDs. The playable level keeps Endpoints empty. Routing and scene-hierarchy tests create their own near_start/near_end fixtures under MainArea/Endpoints, with level ownership so native saves retain them. Do not strip unique_id, parent_id_path or editable-instance metadata when editing scene files. scene_hierarchy_test performs three native editor-state save/reload cycles and checks endpoint parents and every painted layout byte array. If Godot already has the older malformed scene open, reload it before saving; in-memory editor state must pick up the repaired hierarchy. Keep the required Layouts, WorldObjects and Endpoints container names; the project uses these paths directly. Stable IDs are serialization metadata, not permission to rename/reparent these inherited containers arbitrarily. The regression verifies native serialization, not every possible editor reparent/undo workflow.

Game over always clears the level store after the old level's final shutdown snapshot. Area travel preserves it. This supersedes the former multi-level cache; see [game over and progress](game-over.md).

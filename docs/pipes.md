# Pipe entrance and one-way area travel

The first pipe entity is an upward-facing 32x32 (2x2 tile) solid pipe. It inherits BaseEntity and uses the four existing pipe-top/body textures. Its scene is scenes/entities/pipes/pipe_entrance.tscn. Static pipe terrain remains available for pipes that do not support travel.

## Painting

1. Select TestLevel/Areas/MainArea/Layouts/EntityLayout.
2. Choose source 3, Pipe entrance (2x2).
3. Paint one stamp at the top-left cell. It shows the full 2x2 pipe in the editor and creates one complete entity. Leave its four-cell visual footprint clear of other entity markers.
4. The stamp supplies both cap and body rows; no separate pipe-body painting is required.
5. Run the level, stand centered on the opening, and hold Down.

The marker uses a generated 32x32 preview assembled from the four original sprites. Its 2x2 atlas region and texture origin align the preview with the runtime pipe. EntityLayout stores one anchor cell; this remains one entity rather than four independently spawned tiles. No example markers were painted automatically. Existing terrain, markers, and decoration cells are unchanged.

The marker's entity_id is pipe_entrance and TestLevel maps it to PipeEntrance. Both area-theme marker TileSets expose the same source ID. Its scene's defaults are Destination Area Id lower and Destination Endpoint Id arrival. Existing painted pipes retain that destination unless overridden by their area's Pipe Routes array.

## Rendering and maintenance

Pipe physics and entity ownership stay under the area's WorldObjects. During startup the pipe reparents its Visuals node into BaseLevel/ForegroundObjects, which draws after Players. A RemoteTransform2D keeps the visuals aligned with the pipe. All visuals retain Z=0 within the existing CanvasGroup, preserving the shared shadow. This covers Mario as PipeEnter moves him down into its body while other blocks retain their normal draw order. Shutdown unlinks and frees the transferred visuals.

The preview texture at assets/tileset/previews/pipe_entrance.png is an exact packing of the existing four sprites, not new artwork. If those sprites change, rebuild it with Godot's console executable using --headless --path . --script res://scripts/build_pipe_marker.gd, then let Godot reimport it. Runtime visuals continue using the original four sprites, allowing individual theme texture replacements.

## Activation

PipeEntrance reads the existing ControllerHandler Down snapshot. It requires the level's active area to own the entrance, a live grounded player, enabled PlayerState controls, Down greater than 0.5 without opposing Up, feet within 4 pixels of the opening center, and feet within 1 pixel of the opening's top. Input bindings are unchanged. Holding either Left or Right blocks entry, including both simultaneously. Existing horizontal momentum alone does not block it after those inputs are released. Automatic centering on accepted entry is retained by user preference. Side contact, jumping over a pipe, and standing off-center do not activate it.

The entrance asks BaseLevel.request_pipe_entry to validate and reserve its destination, then start the player's assigned PipeEnter state. The route is identified by area_id and endpoint_id. BaseLevel validates both IDs are unique and that no transfer is pending. Missing/ambiguous IDs and requests during shutdown are rejected. Same-area travel to a different named endpoint is supported; the legacy default arrival is only for changing areas. A request for the already active endpoint is rejected. The validated destination is weakly referenced and revalidated before deferred transfer, so deleting or renaming a target cancels travel safely. The final handoff is deferred until after descent finishes and outside the current physics callback. The immediate request_area_transfer API remains available for scripted relocation; pipe entities use the animated entry path.

## Transfer

BaseLevel retains the existing player object, exits its transient state without exit presentation, clears velocity, places its moving Body at the resolved endpoint marker, and resets body interpolation history. It disables other area cameras, enables the destination camera, resets its target/history, records active_area, and restarts the player's initial state. GameHandler stores current_area_id and current_endpoint_id in its session dictionary; other session values are preserved. Initial level startup records MainArea too. Standalone F6 levels do not overwrite an unrelated registered game's session.

Scrolling cameras snap to reveal the arrival endpoint within their world bounds, resetting right-only tracking history for the explicit relocation. The existing level clamp follows the selected camera, and LowerArea's camera remains fixed. Further pipe entry is locked until Down is released, avoiding held-input loops between linked pipes. Player appearance is independent of area themes. Entity texture resolution now handles all child Sprite2D nodes, so multi-piece pipe artwork can use future theme replacements too.

Pipe travel now animates entry with the supplied sound, then cuts to the destination after Mario is hidden. It does not animate emergence, change music, spawn an exit pipe, or add a screen fade. Return routes can be configured by area and endpoint; the same entry sequence works for those routes, while visual emergence is still pending. Endpoints identify positions independently of physical pipes. No item/power-up state is moved into the player scene.

## Entry animation and sound

Mario owns StateMachine/PipeEnter using the reusable scripts/states/player/pipe_enter_state.gd script. BasePlayer exposes a Pipe Enter State reference; each concrete player supplies its own state node and presentation. Mario uses his idle texture, stops the walking animation, disables controls/input callbacks, and assigns smb_pipe.wav as Enter Sound Effect.

After validating entry, BaseLevel reserves the route. PipeEnter centers the body over the opening, clears velocity, temporarily removes its collision layer/mask, and directly advances downward without normal movement or gravity. The source camera and screen clamp stay frozen during the sequence. The foreground pipe conceals the sprite; it is also explicitly hidden once its top has passed below the opening, preventing reappearance beneath the short pipe while the timer continues.

The [reference disassembly](https://gist.github.com/1wErt3r/4048722), HandlePipeEntry and VerticalPipeEntry, sets a $30-frame change-area timer, queues the pipe sound, sets background sprite priority, and moves Y by one pixel per frame. At nominal 60 Hz this project's Entry Speed is 60 pixels/second and Entry Duration is 48/60 = 0.8 seconds. Duration is kept long enough for the sprite to become hidden. Godot foreground ordering, explicit sprite hiding, collision suspension, and a camera cut adapt those rules rather than reproducing NES rendering/loading timing.

When descent finishes, the level revalidates source/destination, commits the state, restores collisions/visibility during state exit, moves to the destination, switches/snaps its camera, and restarts normal player state. Releasing Down remains necessary before another entrance can activate.

Invalidated targets, source removal, or an interrupted state cancel the reserved transfer. State exit restores the pre-entry position, collisions, visibility, and stops its own entry audio; ordinary controls resume where appropriate. Level shutdown performs cleanup without restarting the player. BaseState now retains the AudioStreamPlayer2D returned by entry presentation so the entry state can clean up its own sound without stopping an unrelated replacement effect.

The imported pipe WAV reports looping, so the state duplicates the stream and disables looping on the runtime copy. The asset and its import settings remain unchanged. Playback is exclusive through BaseEntity's existing sound channel. The clip is approximately 0.784 seconds long; tests verify nonzero decoded amplitude and one-shot mode, not physical speaker output.

## Named endpoints

Each BaseArea includes Arrival (endpoint_id arrival) as its backward-compatible default and an Endpoints container for additional markers. Drag scenes/levels/areas/area_endpoint.tscn under the target area's Endpoints, position it at the desired player-feet location, and give it a unique name such as middle_exit. Endpoint Id overrides the node name if provided; otherwise the node name is its ID. IDs are case-sensitive and unique within their area, so different areas can reuse an endpoint name.

Exit Direction stores Up/Down/Left/Right for the future emergence animation; it does not animate or change player facing yet. TestLevel supplies MainArea/Endpoints/near_start at (48,208) and near_end at (880,208) as initial examples. These are position markers, not automatically generated exit pipes. Move them to the intended openings when authoring routes.

## Different routes for painted pipes

Until the custom click-a-cell editor is implemented, use the native Inspector:

1. Select the area containing the painted entrance (for example Areas/MainArea).
2. Expand Pipe Routes and add a new PipeRoute resource.
3. Set Cell to the entrance's top-left EntityLayout grid coordinate, not its pixel position.
4. Set Destination Area Id (main or lower in TestLevel) and Destination Endpoint Id (for example near_end or arrival).
5. Add a separate resource for each independently routed entrance. If you move a painted marker, update its route's Cell too.

For example, one source-area cell can target main/near_start while another targets main/near_end. Routes are scoped to their source area, so the same cell coordinate in another area can have a different destination. Overrides are applied before the pipe enters the scene tree. An unconfigured pipe retains its scene defaults; duplicate route entries at one cell report a configuration error and skip that pipe. The planned per-cell editor can later edit this data without changing routing behavior.

The transfer API is request_area_transfer(area_id, endpoint_id = &"arrival"). Its original one-argument form remains supported.

## Verification

pipe_transfer_test paints an independent entrance fixture and checks 32x32 support/geometry, full marker size, foreground draw order and cleanup, alignment, airborne/control rejection, duplicate/missing/same-area requests, deferred destination placement, velocity/FSM reset, camera selection, GameHandler session preservation, and shutdown. Visual timing and pipe animations remain future work.

pipe_routing_test checks independent per-cell routes after save/reload, named and default destinations, same-area exits, exit-direction metadata, duplicate/missing/deleted targets, camera repositioning without clamp displacement, input reentry lock, and persistent session preservation.

pipe_entry_test additionally verifies input suppression, constant descent, source-camera freeze, once-only sound, invalidated-target rollback, and shutdown cleanup. pipe_transfer_test checks the full timer, hidden phase, nonlooping decoded audio, and restored state/collision at arrival using real physics-paced waits.

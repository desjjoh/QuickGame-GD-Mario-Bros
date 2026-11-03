# Level transport

## Ownership and API

`BaseLevel.transport(traveler, destination, source = null) -> bool` coordinates travel for its current player. TransportDestination is a Resource with Area Id and Target Id. Both must identify one exact destination; there is no proximity search or automatic pipe pairing. The bool means the request was accepted, not that deferred travel has completed. Only one request may be pending. Completion callbacks carry their phase identity; cancellation or a phase change invalidates previously queued notifications, so duplicate entry completion cannot also complete emergence.

```gdscript
var destination := TransportDestination.create(&"main", &"player_spawn")
level.transport(player, destination, source_entity)
```

The source is a TransportEntity, which inherits BaseEntity. It supplies eligibility, entry position/direction and a PlayerTransportState. With no source, transport skips entry presentation and performs a deferred handoff; an entity destination still supplies its normal exit presentation.

PlayerTransportState inherits PlayerState and supplies the shared configure/commit_transfer contract plus travel_finished signal. Concrete states own motion, input/collision suppression and reversible cleanup. PipeEnter implements this contract. Future vines can supply another transport entity/state without adding vine motion to the level. No vine behavior is implemented yet.

The level owns validation, phase coordination, loading/restoring destination content, camera selection, source saving/unloading, temporary player draw order, and restarting normal play after exit. GameHandler retains shared session state/progress and records current_area_id/current_target_id. current_endpoint_id remains a compatibility alias for the target ID.

## Configuring painted entities

Select the source area in TestLevel and expand **Transport Points**. Add a TransportPlacement resource for each painted transport anchor you need to configure:

| Property | Purpose |
| --- | --- |
| Cell | EntityLayout top-left grid coordinate, not pixels |
| Target Id | Unique name within this area, used by incoming routes |
| Destination | TransportDestination Resource: Area Id and Target Id |
| Entrance Enabled | Whether this entity accepts entry |
| Exit Enabled | Whether other transports may arrive here |
| Exit Distance | Controlled emergence distance; default 96 pixels |

These are per-cell resources on the area, not shared TileSet data and not separate spatial markers. Two pipes painted from the same tile can have different IDs/routes. If you move the painted anchor, update its Cell; keep its Target Id and incoming destinations unchanged. Its live entity supplies the opening position/direction, so no arrival marker needs moving. A custom click-a-cell Inspector remains planned; the native resource array is the current authoring interface.

A destination pipe can be exit-only. Routes are directional: setting A's destination to B does not implicitly link B back to A. Ordinary area Arrival and named AreaEndpoint spawn markers remain valid destinations for open-space arrivals; pipes do not need markers beside them. Target IDs share a namespace with standalone endpoint IDs within each area. The reserved main-area target `player_spawn` resolves directly to the level's existing Players/PlayerSpawn marker, with no emergence presentation; do not use that ID for a painted entity. Moving PlayerSpawn moves this destination automatically.

## Loading and validation

Area roots retain TransportPlacement resources, standalone spawn metadata, and lightweight painted-anchor identities while runtime nodes are unloaded. Validate IDs and metadata before starting source entry. At handoff, revalidate, load the destination, restore progress, resolve the actual target entity and ask it for exit geometry/state. Only after resolving the target does the level commit movement, select its camera, unload/exit the source, and enter the destination. Area entry/exit maintain occupancy; soundtrack playback is deferred (see [backlog](backlog.md)). Missing target entities after loading cancel travel and unload the newly loaded destination.

Missing/duplicate areas or IDs, empty IDs, disabled exits, removed target entities, invalidated definitions, wrong player ownership and concurrent requests are rejected. Duplicate Cell configurations are authoring errors and skip spawning that entity. Deleting a target or changing metadata during travel cannot silently choose another destination. Cancellation restores the source position/collision/visibility; interruption/shutdown use the existing lifecycle cleanup. Session observers can synchronously replace or shut down a level: transport stops publishing old IDs when ownership changes and does not restart the old player afterward.

The destination area is authoritative for its target's position. Generic transport does not carry hardcoded pipe coordinates. Area loading is synchronous; this is runtime-node unloading, not asynchronous loading or full texture eviction. See [area lifecycle](areas.md).

## Test stage route

| Entity | Placement | Destination / behavior |
| --- | --- | --- |
| Main secret entrance | MainArea cell (57,9), ID secret_entrance | lower / arrival; descends then arrives at the existing open-space spawn |
| Secret-area return | LowerArea cell (13,11), ID secret_return | main / player_spawn; resumes normal play at the level spawn |

The former pipe_return marker and temporary start return pipe are removed. The near_start/near_end example markers are also removed from the playable stage; tests create their own standalone endpoints when needed. Return uses the existing main area and camera. The source area unloads after handoff and previous block/tile progress is restored on return.

## Compatibility

Existing `request_pipe_entry(pipe)` delegates to transport. Existing PipeRoute resources and destination_area_id/destination_endpoint_id scene overrides remain supported when no explicit TransportDestination is assigned. Prefer Transport Points and destination Resources for new authoring; their settings take precedence.

`request_area_transfer(area_id, endpoint_id = &"arrival")` remains a deferred placement wrapper without emergence, preserving existing scripted callers. `can_enter_pipe()` forwards to `can_transport()`. active_endpoint remains available for standalone AreaEndpoint arrivals and is null for entity targets; use active_target_id for general routing.

## Verification

transport_test saves/reloads configured resources and exercises a non-pipe test entity/state, exact and moved target geometry, one-way permissions, duplicate/missing/stale rejection, wrong player ownership, preserved session data and removed destinations while unloaded. sideways_pipe_test uses an isolated pipe-to-pipe fixture to preserve animation, sound, control timing, camera/draw order and unloading coverage. spawn_return_test verifies the playable secret return follows the actual PlayerSpawn even when moved while MainArea is unloaded, restoring normal control without an exit pipe or emergence. Existing routing/entry/streaming checks cover legacy compatibility and lifecycle behavior.

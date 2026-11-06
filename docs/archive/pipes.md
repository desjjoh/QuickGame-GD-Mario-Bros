# Pipes and area travel

## Painting pipes

GroundLayout provides solid, non-interactive pipe pieces in both theme TileSets. Source IDs 1-6 retain their existing meanings; 7/8 are the sideways mouth top/bottom and 9/10 are the horizontal body top/bottom. Underground currently falls back to the supplied Overworld pipe art.

EntityLayout provides complete 32x32 pipes: source 3 is upright (`pipe_entrance`), source 4 is left-facing (`sideways_pipe_entrance`). Paint one stamp at the top-left anchor and leave its four-cell footprint clear of other markers and solid terrain. Each stamp creates one entity with four sprites and one StaticBody2D. SidewaysPipeEntrance inherits PipeEntrance's scene, collision and script; it overrides textures, entry orientation and default destination.

The generated previews pack the original pixels. Rebuild both with Godot's console executable: `--headless --path . --script res://scripts/build_pipe_marker.gd`, then let the editor reimport them. Runtime sprites remain separate for theme substitution.

## Entry and exit

Upright entry requires enabled player controls, grounded support, Down without Up or either horizontal button, feet within four pixels of the mouth center and within one pixel of its top. Accepted vertical entry preserves Mario's horizontal position and facing throughout descent; the alignment gate still applies. Momentum alone does not reject entry.

The left-facing entrance requires a grounded player walking right against its left wall, without opposing Left, with feet aligned to its bottom within four pixels. Airborne side contact does not activate it. Mario moves right into the mouth at 30 pixels/second; upright entry moves down at the configured 60 pixels/second. Upright entry retains its 48-tick timer. Side entry plays the assigned walk animation at the existing slow cadence, moves 14 pixels to place the sprite left edge on the next 16px boundary, then waits 52 ticks concealed. The delay is editable for special entrances. Both use ControllerHandler's existing direction bindings.

BaseLevel reserves and revalidates the route, then uses the player's assigned PipeEnter state. Normal movement, controls and collisions are suspended. Mario draws behind the world only during travel; all visuals retain Z=0 inside Game's shared world/UI/player shadow. The source camera stays fixed during entry. The pipe sound plays once on entry; emergence is silent, using a nonlooping runtime WAV copy; import settings are unchanged.

At the concealed handoff, the destination loads, its progress is restored, its camera becomes current and the source runtime unloads. The selected destination entity provides the final player-feet position, exit direction and presentation. Exit Distance defaults to 96 pixels: upward emergence moves at 60 pixels/second for 96 physics ticks. Mario remains invisible until close enough to the mouth to emerge naturally, faces right, and uses a standing pose for vertical travel. Controls, collision and normal draw order return after the final emergence step; normal input runs on the following physics tick. Handoff does not briefly activate Idle between travel phases. Holding a direction works after emergence without a release; jump presses made while locked are discarded. A standalone spawn destination without exit presentation resumes normal play immediately.

Exit supports Up, Down, Left and Right; current supplied entity art supports upright and left-facing entrances. There is no screen fade or music crossfade. Area soundtrack playback is currently removed pending suitable assets; pipe SFX remain unchanged. The shared PipeEnter state handles both travel phases; the concrete player owns the state node. Cancellation restores a safe position, visibility and collision; shutdown stops travel. Held directional input must be released before another entrance can activate.

## Routes and authoring

PipeEntrance inherits TransportEntity and calls `level.transport(player, get_destination(), self)` after accepting entry. Paint source 3 for an upright pipe or source 4 for a left-facing pipe. Configure its per-cell TransportPlacement under the area's Transport Points array: assign a Target Id, a TransportDestination (Area Id/Target Id), and entrance/exit permissions.

The destination pipe supplies its opening and exit direction; no separate arrival marker is required. Upright pipes emerge upward with final feet at local (16,0); left-facing pipes emerge left with final feet at local (-8,32). Exit Distance defaults to 96 pixels and is editable per placement. These directions follow the supplied artwork. Standalone Arrival markers remain valid for destinations with no pipe.

The secret return targets main/secret_exit, the painted exit-only pipe at MainArea cell (162,11), near X 2624. Mario emerges upward from that pipe before normal collision/control resumes. The original entrance at (57,9) retains its route to the secret area. PlayerSpawn remains supported as an open-space destination and has independent fixture coverage. The temporary start return pipe and the old adjacent marker are removed. See [transport](transport.md) for the full API, native Inspector workflow, explicit test routes, lifecycle and compatibility wrappers. Vines and a custom per-cell editor remain future work.

## Verification

pipe_entry_test covers entry controls, timing, camera freeze, sound, invalid target rollback and shutdown. pipe_transfer_test covers full stamps, geometry, alignment, destination handoff and cleanup. pipe_routing_test covers saved per-cell routes, endpoint uniqueness, cameras, session state and reentry lock. sideways_pipe_test uses an isolated pipe-to-pipe fixture and walks into its secret-area entrance, checks horizontal movement, area unloading, upward emergence, final position, collision/control restoration and draw order, and verifies both theme TileSets expose the new solid pieces and marker.

## Reference correspondence

[SMB disassembly](https://gist.github.com/1wErt3r/4048722): EnterSidePipe supplies right input and stops on a 16px boundary; normal side travel uses the $34 timer. PlayerEntrance rises from $f0 to $90, then PlayerRdy selects normal control for the next frame and faces right. Our transport targets relocate that sequence to arbitrary openings. The special page-zero intro's $a0 delay is not selected automatically; use Side Entry Delay when authoring it. Our horizontal motion remains a constant 30 px/s adaptation rather than emulating every fractional friction update. Full NES frame-trace equivalence is not claimed.

## Transition presentation

Completed entry commits area travel behind the global quick black screen, including HUD. Destination pipe emergence starts after reveal; area travel does not show the level splash. See [transitions](transitions.md).

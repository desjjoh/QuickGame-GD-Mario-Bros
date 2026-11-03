# Global transitions

GameHandler owns TransitionCoordinator as a child, using the persistent Game UI/ScreenContainer/TransitionScreen for presentation. This is not another autoload. GameHandler creates the coordinator by runtime script loading in _ready to avoid a static dependency cycle back through GameHandler/BaseLevel. Game enables transitions by default. Standalone scenes and timing-focused regression fixtures can use the immediate loading path instead.

## Presentation and lifecycle

Area/pipe transfer: hide world, player and HUD; present full black; perform the destination transfer under cover; submit the destination camera/render state; hold the minimum duration; restore visibility and input. Pipe emergence proceeds after the cover is removed. HUD/theme changes therefore happen while hidden. No splash card appears for area travel.

Initial level loading and death restart: quick full black, load the level, loading splash with HUD, quick full black again, gameplay. The splash currently contains static WORLD 1-1, Mario portrait and × 3 placeholders. These do not bind to session values or deduct lives. Death still waits for its existing jingle lifecycle before requesting restart.

A rendered frame acknowledges the cover before work starts. Headless validation uses a process-frame acknowledgement instead. Physics-frame minima do not shorten when work is slow: loading must finish and destination state must be submitted before reveal. Async callables are supported; current scene creation remains synchronous, with no threaded disk loader added.

Entity gameplay and controller input are suspended while covered; presentation animations and the shared cosmetic clock can continue. Existing visibility, input enablement and gameplay suspension are restored. Controlled state initialization can run under suspension without granting a gameplay tick. Weak references allow old scene nodes and temporary audio nodes to be freed safely.

## Black screen: original and Godot implementation

The original disables background and sprite output through `DisableScreenFlag` and `PPU_CTRL_REG2` while updating screen data. This is hardware display blanking, not an extra black sprite or rectangle drawn over a running level. The intermediate world/lives card is a separate visible presentation between blanking phases. See `NonMaskableInterrupt`, `DisplayIntermediate` and `AreaParserTaskControl` in the [disassembly](https://gist.github.com/1wErt3r/4048722).

Our implementation uses both visibility and a black background. `TransitionCoordinator` hides `Game/LevelContainer`, each affected level's `Players`, and `Game/UI/HUD`. Hiding Players explicitly also covers their separate foreground render routing. `TransitionScreen/Cover` is an opaque full-viewport `ColorRect` with `Color(0, 0, 0, 1)`. It supplies a consistent black image regardless of the current area's background color. It is not a change to the project's default clear color or an area's painted background.

The cover remains visible during the loading card; its Card child and the persistent HUD become visible over black. Before revealing gameplay, Card and HUD are hidden again for the final quick phase. Existing visibility is restored when the transaction finishes or is cancelled. The black screen does not itself free a level or area: loading and area streaming own that work.

| Concern | Original game | This project |
| --- | --- | --- |
| Hide gameplay | Disable PPU background/sprite rendering | Hide world, player and HUD; show an opaque black Control |
| Protect visual updates | Update screen data while display is disabled | Commit area, camera and theme changes while hidden, then submit a covered destination frame |
| Quick area travel | Alternate entrance skips the intermediate card | One quick black phase; no card or HUD |
| Startup/respawn | Screen tasks alternate blanking and intermediate presentation | Quick black, splash with HUD, quick black, gameplay |
| Timing | Hardware frames, task execution and interval timers | Configurable minimum physics ticks plus work/render acknowledgement |
| Gameplay suspension | Original mode/task-specific execution | Explicit reversible entity gameplay suspension and controller gating |

These are corresponding presentation goals, not identical rendering implementations. Quick black hides HUD artwork changes when themes change; the Underground HUD coin now uses the active area theme, while other HUD variants remain future work. Normal gameplay keeps the existing shared world/HUD/player shadow composition and player-over-HUD ordering. Transition black is opaque and gameplay is hidden, so world shadows cannot show through it. No fade, crossfade or shader-based darkening is applied.

## Timing reference

Defaults are 12 physics ticks for each quick black phase (0.2 seconds at 60Hz), and 147 ticks for the loading card (2.45 seconds). These are configurable coordinator properties, not Project Settings changes. They are frame minima, not wall-clock timers.

The [SMB disassembly](https://gist.github.com/1wErt3r/4048722) initializes ColumnSets to $0b, giving twelve area-parser column sets. Our quick minimum adapts that count; it does not claim the original complete pipe blackout lasts exactly twelve frames. ResetScreenTimer loads seven interval ticks and the interval divider counts twenty-one frames; countdown phase gives roughly 127–147 frames. The card uses a consistent 147-frame minimum. Pipe travel skips the intermediate card in the reference. Full fixed-point/NMI/PPU timing parity is not claimed.

## API and cancellation

Use GameHandler.transition_to_level(scene) for presented level loading. GameHandler.load_level(scene) remains the immediate low-level compatibility API. BaseLevel routes completed pipe entry through the coordinator before committing area transport, and death restart uses the level transition lifecycle.

TransitionCoordinator.begin(owner, operation, kind, completion, validator) returns an accepted transaction ID, or zero if unavailable/busy/invalid. Operation returns true on success and may await work. The owner must be the attached Game or current level. Signals started, covered, loaded and finished expose the lifecycle; phase and frame counters expose progress. Successful level operations include the splash; area operations only use quick black. Failed operations restore presentation without a success card.

Only one transaction runs at once. Cancellation, owner removal, unexpected level replacement and Game detach invalidate pending continuations. The expected single level replacement during a level operation is allowed. Callers of asynchronous operations must also guard their own side effects after cancellation; the coordinator can reject stale completion, not undo arbitrary external work. Input edges buffered during cover are discarded.

## Verification

transition_test covers startup and death cards, real pipe transfer, black cover before work, HUD visibility, slow work, minimum holds, overlapping requests, cancellation/stale completion, level replacement and visibility/input restoration. Its rendered branch checks black-screen pixels and captures quick and splash previews. Existing timing-focused fixtures explicitly disable transitions; this test exercises the enabled production path. Headless assertions do not establish subjective pacing or audible output.

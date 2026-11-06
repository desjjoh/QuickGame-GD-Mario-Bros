# Global transitions

GameHandler owns TransitionCoordinator as a child; persistent Game owns UI/ScreenContainer/TransitionScreen, a generic presentation host. No additional autoload is used. GameHandler loads the coordinator at runtime to avoid a static dependency cycle through GameHandler/BaseLevel. Current named types are area and level. Game over and other future screens are not implemented.

## Existing behavior

Area/pipe transfer: hide world, player and HUD; present a frame with the existing viewport background; perform destination work; submit destination camera/theme state while hidden; honor the minimum hold; restore visibility and input. Pipe emergence proceeds after reveal. Area travel has no splash card.

Starting a game from the title and death restart: quick hidden phase, load, level-intro presentation with HUD, quick hidden phase, gameplay. The existing intro now lives in scenes/ui/transitions/level_intro.tscn. Its stage label and lives read GameHandler values; the portrait remains Small Mario. Accepted death has already reduced lives before the intro is created. Death still waits for its existing jingle lifecycle before requesting restart.

A rendered frame acknowledges blanking before work starts. Headless checks use a process-frame acknowledgement. The initial minimum includes time spent loading; slow work cannot be revealed before completion and destination render submission. Each later stage holds its own minimum physics ticks after its first submitted frame. Async callables are supported, but current level creation remains synchronous; no threaded disk loader was added.

Entity gameplay and controller input are suspended. Presentation animation and the global cosmetic clock can continue. Completion/cancellation restores prior visibility and suspension. Controlled state initialization can run under suspension without granting a gameplay tick. Weak snapshots tolerate freed old-level/audio nodes.

## Black screen: original and Godot implementation

The original uses DisableScreenFlag and PPU_CTRL_REG2 to disable background/sprite output during screen updates, rather than drawing a black overlay. Its intermediate world/lives card is visible between blanking tasks. See NonMaskableInterrupt, DisplayIntermediate and AreaParserTaskControl in the [disassembly](https://gist.github.com/1wErt3r/4048722).

There is no Cover node, replacement fullscreen rectangle, or renderer clear-color override. The coordinator hides LevelContainer, the separately routed Players and HUD, leaving the existing viewport background visible. It does not change its color. During a presentation, its Control scene and optionally HUD render over that existing background. Scene and area artwork remains authored as before.

| Concern | Original | Godot adaptation |
| --- | --- | --- |
| Hide gameplay | Disable PPU background/sprite output | Hide world/player/HUD; leave the viewport background unchanged |
| Protect visual changes | Update screen data while disabled | Load/swap theme and camera while hidden; acknowledge destination render state |
| Quick area travel | Alternate entry skips intermediate card | area definition has no presentation stages |
| Startup/respawn | Blanking and intermediate screen tasks | level definition selects intro and blank outro stages |
| Timing | Hardware frames and interval timers | Physics-tick minima plus work/render acknowledgement |
| Completion | Mode/task-specific execution | Shared cancellation/restoration and caller completion callback |

Quick phases conceal HUD coin theme swaps. The shared world/HUD/player shadow composition remains; hiding the world prevents its shadows from contributing during transitions. No fade or shader darkening was added. The black screen does not itself unload areas; normal streaming/loading owns that work.

## Definitions and presentation scenes

TransitionDefinition is a Resource with:

- id: the StringName supplied to begin, such as area or level.
- minimum_frames: initial hidden hold.
- allow_level_replacement: permit one expected replacement during operation execution.
- stages: ordered TransitionStage resources shown after successful work.

Each stage supplies a phase name, optional PackedScene, minimum_frames and show_hud. A null scene means a blank stage. Presentation roots must inherit Control. The host hides and queues the previous presentation for deletion; it never assumes a child named Card or a particular screen layout. Presentation initialization may cancel safely.

Defaults are assets/transitions/area.tres and level.tres. The coordinator registers private runtime copies on readiness. get_definition(id) exposes the runtime configuration; register_definition(resource) adds another valid, unique ID while idle. Registration rejects duplicates, invalid definitions and changes during active/restoring transactions. begin rejects unknown IDs. Active requests deep-copy their configuration so later edits cannot alter a running sequence. Never mutate loaded shared source assets to configure a particular request.

To add a future type: create a Control presentation scene, create its definition/stages, register the definition (or include it in the coordinator's exported definitions), then request its ID. Loading behavior remains the supplied operation, not something inferred from the type name. The current public GameHandler level/death calls and BaseLevel pipe calls still request level or area.

Named stages now also support the game-over presentation and optional completion waiting. GameHandler owns the destination/session decision; transition artwork does not reset lives or load levels from its cleanup callback. Existing cards keep timed-only behavior unless wait_for_presentation is enabled.

## Timing reference

area uses a twelve-tick initial blank minimum. level uses twelve initial ticks, a 147-tick intro with HUD and a twelve-tick blank outro. At 60Hz these correspond to 0.2 and 2.45 seconds. Timings now live in definition/stage resources; former area_minimum_frames and level_minimum_frames coordinator properties were removed.

The reference initializes ColumnSets to $0b (twelve parser column sets). Twelve quick ticks adapt that count; this is not a claim that the entire original pipe blackout lasts exactly twelve frames. ResetScreenTimer loads seven intervals with a twenty-one-frame divider, giving roughly 127–147 frames depending on phase; the intro uses a consistent 147-tick minimum. Exact PPU/NMI timing parity is not claimed.

## API and cancellation

GameHandler.transition_to_level(scene) presents a level load. load_level(scene) remains the immediate compatibility API. TransitionCoordinator.begin(owner, operation, kind, completion, validator) returns a transaction ID or zero when rejected. Operation returns success and may await. Owner must be the attached Game/current level. Signals started, covered, loaded and finished and phase/frame counters expose progress. The historical covered signal means a blank frame has been submitted; it no longer implies an overlay object.

Only one transaction is active. Invalid owners, unexpected level replacement, detach and cancellation invalidate pending continuations. Replacement permission is a definition property, independent of ID. A failed operation skips success presentations; invalid presentation roots restore state and report failure. Async callers must guard their own later side effects because the coordinator cannot undo arbitrary external work. Buffered input edges are discarded. New requests are rejected during restoration, but completion callbacks may request the next transition after cleanup.

## Verification

transition_test exercises existing startup/respawn and actual pipe transfer, render-before-work sequencing, unchanged background pixels with no Cover node or clear-color override, custom named presentation/HUD/timing, resource isolation and active snapshots, unknown/duplicate/invalid rejection, scripted initialization cancellation, generic replacement permission, slow work and stale/cancelled transactions. Rendered checks capture quick/intro images. Headless checks cannot qualify physical monitor pacing or subjective presentation. The separately tracked intermittent native engine shutdown issue is not resolved by this feature.

Normal application startup now opens the [title](title-screen.md) through immediate background loading, with no transition. Confirming Start invokes the level definition into 1-1. Direct gameplay fixtures may opt out of title startup to isolate existing behavior.

Game over adds a game_over definition (12 hidden / 378 card with HUD / 12 hidden). Its card waits for one-shot audio completion with bounded fallback, and its GameHandler completion returns to title after explicit old-level progress cleanup. No background override is introduced. See [game over](game-over.md).

Level completion uses the existing level definition for advancement and Warp destinations, including the destination intro. A finish definition supplies a 12-frame hidden minimum with level replacement allowed and no presentation scene for final-stage title return. Warp skips future completion fanfare, not the destination intro. See [level completion](level-completion.md).

## TIME UP

The time_up definition holds its HUD-visible card for 147 physics frames, followed by a 12-frame quick outro. It validates the existing dead level without replacing it, preserving HUD TIME 000. Its completion callback selects the existing lives intro or game-over sequence. See [level timer](level-timer.md).

## Ending return to title

finish uses a 12-tick minimum hidden operation and a 12-tick quick outro. Title UI created inside that operation stays hidden until the coordinator finishes, matching its hidden background/HUD. No black cover or clear-color override is added. Flagpole audio and score/firework hooks finish before this transition begins.

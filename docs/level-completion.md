# Level completion and stage order

BaseLevel owns the completion lifecycle entry; GameHandler owns destination selection and persistent session status. 1-1 now uses a level-owned [flagpole ending presentation](flagpole-ending.md) with descent, automatic walk, endpoint player retirement and completion audio. Score/firework hooks currently do nothing; time-to-score conversion remains deferred. The level timer is implemented separately.

## Authoring the stage order

Open scenes/main/game.tscn, select Game and edit Stages in the Inspector. Entries are PackedScene resources in play order. The current list contains only scenes/levels/worlds/world 1/1-1.tscn, so completing it returns to the title until more stages are added. The list must be nonempty with no null entries. The title background remains configured separately on TitleScreen.

The former exported initial_level setting is replaced by Stages. A non-exported initial_level compatibility property reads the first entry; setting it replaces the list with a single stage for existing programmatic fixtures. It is not a second Inspector configuration. GameHandler snapshots the ordered list at startup. current_stage_index is zero-based and -1 on the title or in an unlisted custom stage. Repeated scene entries advance by list position and start a clean visit, even if the resource path is unchanged.

## Lifecycle API

```gdscript
# Normal progression to the next listed stage, or title after the last.
on_complete()

# Warp completion: explicit stage, no completion fanfare, destination intro retained.
on_complete(destination_scene, BaseLevel.CompletionMode.WARP)
```

Both calls return whether completion was accepted. WARP requires a non-null PackedScene destination. NORMAL also accepts an explicit destination when needed. completion_mode records NORMAL or WARP and completion_started notifies listeners once after acceptance gates. A configured flagpole starts its accepted presentation through begin_ending; ordinary direct calls remain immediate, and Warp bypasses that presentation. Both stage-to-stage modes use the existing level intro after loading the destination.

Requests are rejected for a shutdown, dead/dying, transporting, already completing or transitioning level, or when it is not GameHandler's current PLAYING level. The completion flag blocks death and further transports immediately, including reentrant observers. Completion switches flow to COMPLETING. TransitionCoordinator suspends entity gameplay/input and hides gameplay while retaining cosmetic animation updates; BaseLevel stops its ordinary gameplay checks. Direct-flow fixtures with transitions disabled replace synchronously.

GameHandler chooses the next list entry or explicit override. A listed override selects that entry so subsequent normal completion advances from there. An unlisted override has no inferred successor and returns to the title on normal completion. start_new_game(destination) keeps its existing title-only override and fresh-session semantics; it is not used for stage progression.

## State and progress

Stage advancement preserves score, coin totals, reserve lives and power-up form in GameHandler. Current artwork still supplies only Small Mario; preserving the form does not add Super/Fire player scenes. The next stage initializes its own stage label/time, areas, camera and player. No lives are charged and no new-game reset runs.

The old level shuts down and saves its final snapshot before the next stage visit explicitly resets progress. This ordering prevents shutdown from repopulating a cleared store. Areas within the same level and ordinary death keep their established policies. Finishing the final stage uses the finish transition (12-tick minimum plus 12-tick quick outro, no presentation card), loads the title through its common cleanup lifecycle and resets current_stage_index to -1. No black Cover or background override is introduced. Title background gameplay remains suspended after transition snapshot restoration. Title entry calls clear_session after shutdown, resetting score/coins, Small form, reserves, custom session values, pending startup target, stage index and world progress. Top score survives until hard restart. The next Start also performs the ordinary fresh-session reset defensively.

## Cancellation and ownership

An index is selected only when the destination is accepted by load_level; cancellation before replacement retains the current index. A failed/rejected or cancelled completion clears the active level's completion flag and restores playable flow through the coordinator. If a new stage has already loaded when cancellation occurs, it remains the current stage. Weak Game/source ownership checks prevent stale work from replacing an external level or a closing Game. Normal on_complete is unavailable from the title background and standalone F6 levels outside Game's PLAYING flow.

## Verification

level_completion_test covers direct and animated advancement, duplicate/death/transport rejection, cancellation recovery, carried session status, progress disposal, repeated scene visits, final-stage/title return, frozen title gameplay, explicit Warp destination plus level intro, unlisted override behavior and synchronous replacement by a completion observer. See verification.md for executed outcomes. The configured flagpole is now a production caller through the claim/presentation/finish lifecycle; no debug shortcut was added.

## Level start

GameHandler initializes the stage timer during load. Once PLAYING and the intro coordinator is idle, BaseLevel.on_level_start arms the countdown once; completion stops further countdown work. See [level timer](level-timer.md).

## Presented completion

begin_ending claims completion before presentation without loading a destination. finish_ending dispatches the already accepted transaction only after the configured presentation reports completion; Mario may already have been removed. The level owns cancellation/recovery. See [flagpole ending](flagpole-ending.md).

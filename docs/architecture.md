# Architecture

## Game and level ownership

| Owner | Responsibility |
| --- | --- |
| Game scene | Level container, title and HUD, and shared shadow composition |
| GameHandler | Session flow, stage list, player status, top score, and active-level progress |
| TitleFlow | Title screen, backdrop suspension, and new-game transition |
| StageFlow | Restart, TIME UP, Game Over, and stage-handoff operations |
| TransitionCoordinator | Covers gameplay, runs the transition operation, and restores presentation and controls |
| BaseLevel | Player spawn and death, timer lifecycle, camera boundaries, area transport, and level completion |
| AreaTransport | Destination resolution, trip state, entry and exit callbacks, and cancellation |
| LevelTimer | Countdown phase and expiry notification |
| LevelDeath | Level-owned death presentation, gameplay suspension, jingle, timeout, and cancellation |
| BaseLevelArea | Local layouts, camera, theme, transport metadata, and off-camera entity activity |
| ControllerHandler | Global input intent |
| SoundHandler | Generated cues, one-shot stream copies, and the shared reward voice |
| MusicHandler | Non-positional background playback and track changes |

GameHandler owns the active game, level, session, and flow state. Its TitleFlow and StageFlow children coordinate operations through the shared TransitionCoordinator. The game opens the title over Test Level, then loads 1-1 through the level intro. The HUD reads session values and adopts the active area’s artwork. A shared cosmetic clock keeps question blocks, coins, and the HUD coin synchronized.

## Area lifecycle and persistence

The level scene groups its children under Areas, Players, Systems, and Presentations. Areas and Players remain siblings so pipe travel can change their relative draw order. Systems contains LevelDeath, LevelTimer, and AreaTransport. BaseLevel leaves Presentations empty for derived levels. In 1-1, it contains FlagpoleEnding.

Only the active area keeps its runtime layouts, objects, and camera loaded. The level captures progress on unload and applies it when that area returns. Progress belongs to the current level. Coins and used question blocks retain their state by default, while bricks return to their active state. A level can suspend off-camera entities without destroying them, and controller input is opt-in.

Transport resolves explicit area and target IDs. A pipe handles player entry and exit presentation. The level-owned AreaTransport child validates the trip and requests the transition. BaseLevel commits player placement, the active area, and the camera handoff. The destination can be a pipe or a spawn target.

## Entities and player states

`BaseEntity` owns state-machine shutdown and exclusive one-shot playback. `BasePlayer` adds a character body and reusable movement and action nodes. Mario owns his concrete states and artwork. Movement states select behavior, while motion values carry velocity and tuning between states. Jump retains its own pose until landing, while walking off a ledge keeps the ground movement pose with animation paused.

Painted entity stamps resolve to scenes at runtime. A question block moves through Active, Bouncing, and Inactive. A brick returns to Active after bouncing. Both receive a hit through the entity hit contract. Question blocks award a coin on bounce entry and create a temporary coin and score effect under the area. World coins award on contact. Both use GameHandler for the coin, 200 points, and the extra life at 100 coins.

## Death and completion

BaseLevel starts its LevelTimer child after gameplay is revealed and advances it only on eligible gameplay ticks. The child updates the shared remaining time and emits expiry. BaseLevel routes expiry into visible death.

Falling below the camera triggers death without an on-screen animation. Visible death, including timeout, uses Mario’s Dead state. BaseLevel accepts the death and consumes a reserve life. Its LevelDeath child suspends gameplay and waits for the presentation and jingle. BaseLevel retires the player when the presentation ends and asks GameHandler to resolve the outcome once the sequence finishes. A negative reserve triggers Game Over. Otherwise the level restarts at its player spawn. Returning to the title clears the session while retaining the in-memory top score.

Flagpole contact starts a level-owned presentation. It handles scroll lock, descent, flag score, the castle walk, timer conversion, and the castle flag. The endpoint removes the player at the doorway. Each remaining timer unit becomes 50 points. The ending waits for its presentation and audio before handing off to the next stage or the title. Warp completion can choose an explicit destination and still shows that stage’s intro.

## Audio

All gameplay audio uses non-positional playback at default gain. SoundHandler caches the generated effects. Coin, 1 UP, and timer tick share one voice, with 1 UP protected from interruption. During level clear, the ticker temporarily takes over the second pulse while the rest of the jingle keeps playing.

MusicHandler starts background music when gameplay is revealed. Area transitions restart the destination track, including a transition within the same area. Same-area movement without a transition keeps playback running. Death, completion, and level shutdown stop the background loop. The title backdrop is silent.

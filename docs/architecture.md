# Architecture

## Game and level ownership

| Owner | Responsibility |
| --- | --- |
| Game scene | Level container, title and HUD, and shared shadow composition |
| GameHandler | Session flow, stage list, player status, top score, and active-level progress |
| TitleFlow | Title screen, backdrop suspension, and new-game transition |
| StageFlow | Restart, TIME UP, Game Over, and stage-handoff operations |
| PauseController | Gameplay pause eligibility, Start toggle, tree pause, and cleanup |
| TransitionCoordinator | Covers gameplay, runs the transition operation, and restores presentation and controls |
| BaseLevel | Player spawn and death, timer lifecycle, camera boundaries, area transport, and level completion |
| AreaTransport | Destination resolution, trip state, entry and exit callbacks, and cancellation |
| LevelTimer | Countdown phase and expiry notification |
| LevelDeath | Level-owned death presentation, gameplay suspension, jingle, timeout, and cancellation |
| BaseLevelArea | Local layouts, camera, theme, transport metadata, and off-camera entity activity |
| ControllerHandler | Global input intent |
| SoundHandler | Generated cues, one-shot stream copies, and the shared reward voice |
| MusicHandler | Non-positional background playback and track changes |

GameHandler owns the active game, level, session, and flow state. Its TitleFlow and StageFlow children coordinate operations through the shared TransitionCoordinator. The game opens the title over Test Level, then loads 1-1 through the level intro. Loading creates placements without implicitly activating their spawners. BaseLevel.initialize_actors establishes the area actor policy: title entry requests suspended actors, gameplay start requests active actors, and pipe arrival initializes after its transition or immediately for uncovered travel. Standalone F6 initializes at area entry. The HUD reads session values and adopts the active area’s artwork. A shared cosmetic clock keeps question blocks, coins, and the HUD coin synchronized.

## Area lifecycle and persistence

GameHandler exposes `is_paused`, `pause_changed`, and `request_pause_toggle()`. Its PauseController child applies SceneTree pause to gameplay and level presentations. The listener uses Always processing so Start can resume; ordinary gameplay, audio, and the shared animation clock remain pausable. SoundHandler owns a separate Always-processing pause cue player. The title screen and active transitions block pause. Level shutdown, session reset, entering Title or Detached flow, and accepted transitions clear pause. See the [pause walkthrough](archive/pause.md).

The level scene groups its children under Areas, Players, Systems, and Presentations. Areas and Players remain siblings so pipe travel can change their relative draw order. Systems contains LevelDeath, LevelTimer, and AreaTransport. BaseLevel leaves Presentations empty for derived levels. In 1-1, it contains FlagpoleEnding.

Only the active area keeps its runtime layouts, objects, and camera loaded. The level captures progress on unload and applies it when that area returns. Progress belongs to the current level. Coins and used question blocks retain their state by default, while bricks return to their active state. A level can suspend off-camera entities without destroying them, and controller input is opt-in.

Transport resolves explicit area and target IDs. A pipe handles player entry and exit presentation. The level-owned AreaTransport child validates the trip and requests the transition. BaseLevel commits player placement, the active area, and the camera handoff. The destination can be a pipe or a spawn target.

## Entities and player states

`BaseEntity` owns state-machine shutdown and exclusive one-shot playback. `BasePlayer` adds a character body and reusable movement and action nodes. Mario owns his concrete states and artwork. Movement states select behavior, while motion values carry velocity and tuning between states. Jump retains its own pose until landing, while walking off a ledge keeps the ground movement pose with animation paused.

Painted spawner stamps create placements on area load. The area activates them at the camera boundary, and the placement saves consumption after the live actor is freed. The 1-Up spawner scene uses this path internally; standalone power-up painting is deferred. BaseLevel limits live power-ups to one. A painted spawner attempts once per area load. If the slot is occupied when the marker activates, it skips the spawn for that load. Mushroom owns terrain movement. PowerUp frees the item once its bounds are fully outside the camera cleanup region, without recording collection. A configured question block can replace the current item and release a 1-Up. PowerUp raises it one tile before normal movement and pickup begin.

BaseEnemy extends SpawnableEntity with a terrain body and uses the inherited entity state machine. The Goomba scene selects a shared Walking state and provides the animation and themed artwork. A painted Goomba Spawner attempts once at the camera activation boundary. The enemy category has ten live slots, separate from the one power-up slot. A failed attempt is skipped for the current area load. SpawnableEntity frees actors beyond the cleanup boundary. EnemyLayout places spawners on an 8×8 grid. Defeated enemies return on death restart and area reload. BaseEnemy classifies Mario contact and validates incoming hits without assuming defeat. Concrete enemies choose reactions and explicitly call mark_defeated(hit) for permanent defeat; repeated damage or shell transitions can remain nonterminal. enemy_contact(other) identifies the contacted enemy, allowing state-specific responses. Walking retains reversal; Goomba explicitly marks its squash or knock-out state as defeated. See [enemy hit and contact ownership](archive/enemy-contract.md). Blocks deliver upward hits through a reusable receiver shared by enemies and mushrooms.

BaseLevel.tscn owns the shared entity_scenes registry for all standard painted entities. Derived levels inherit it without dictionary overrides; new marker mappings are added once in BaseLevel. Painted entity stamps resolve to scenes at runtime. A question block moves through Active, Bouncing, and Inactive. A hidden question block accepts a rising underside hit before becoming solid. An ordinary brick returns to Active after bouncing. Reward Brick and Reward Brick Alt inherit QuestionBlock and use static initial textures, shared reward configuration, and used-block persistence. Their Active state has no synchronized animation; the existing bounce and depletion states are inherited. Both receive a hit through the entity hit contract. Question blocks award a coin on bounce entry and create a temporary coin and score effect under the area. World coins award on contact. Both use GameHandler for the coin, 200 points, and the extra life at 100 coins.

## Death and completion

BaseLevel starts its LevelTimer child after gameplay is revealed and advances it only on eligible gameplay ticks. The child updates the shared remaining time and emits expiry. BaseLevel routes expiry into visible death.

Falling below the camera triggers death without an on-screen animation. Visible death, including timeout, uses Mario’s Dead state. BaseLevel accepts the death and consumes a reserve life. Its LevelDeath child suspends gameplay and waits for the presentation and jingle. BaseLevel retires the player when the presentation ends and asks GameHandler to resolve the outcome once the sequence finishes. A negative reserve triggers Game Over. Otherwise the level restarts at its player spawn. Returning to the title clears the session while retaining the in-memory top score.

Flagpole contact starts a level-owned presentation. It handles scroll lock, descent, flag score, the castle walk, timer conversion, and the castle flag. The endpoint removes the player at the doorway. Each remaining timer unit becomes 50 points. Before conversion, the timer's final digit selects zero, one, three, or six fireworks. CastleEntity owns the burst sprite, positions, and animation, driven by CastleFireworksStep after the tiny flag rises. Each completed burst awards 500 points and requests the generated blast cue through SoundHandler. The ending waits for its presentation and audio before handing off to the next stage or the title. Warp completion can choose an explicit destination and still shows that stage’s intro. See the [fireworks walkthrough](archive/fireworks.md).

## Audio

All gameplay audio uses non-positional playback at default gain. SoundHandler caches the generated effects. Coin, 1 UP, and timer tick share one voice, with 1 UP protected from interruption. During level clear, the ticker temporarily takes over the second pulse while the rest of the jingle keeps playing.

MusicHandler starts background music when gameplay is revealed. Area transitions restart the destination track, including a transition within the same area. Same-area movement without a transition keeps playback running. Death, completion, and level shutdown stop the background loop. The title backdrop is silent.

Timed coin rewards share the QuestionBlock implementation across question, hidden, and both reward-brick variants. BlockReward holds authoring data (Coin, Timed Coins, or Power-Up); existing PackedScene reward assignments remain compatible. Each block owns its started/remaining state and bounce depletion decision. BaseLevel advances registered timers through weak references so camera activity suspension cannot extend a loaded block's window. Area unload snapshots the timer, and tree pause freezes level processing. See [timed coin rewards](archive/timed-coins.md).

Green Koopa currently inherits BaseEnemy directly with the shared Walking state. Walking optionally mirrors asymmetric artwork when direction changes; Goomba retains its default facing behavior. Koopa shares the 14×16 terrain body and uses a separate 12×12 player-contact area. Its two walking frames follow the global eight-tick animation phases. EnemyLayout source 2 creates its generic enemy-category spawner, with all three theme textures. Walking Mario contact uses the shared damage/stomp check. A successful stomp enters ShellIdle without permanent defeat, stops horizontal motion, and awards 100 points through the shared enemy score-popup helper. ShellIdle reuses zero-speed Walking for gravity/terrain handling; idle shell contact kicks it away from Mario, while a moving shell can damage him or be stopped by a stomp. ShellMoving reuses shared movement and delivers EntityHit shell attacks, awarding chains only on permanent defeat. An idle shell wakes after 336 active physics ticks, with globally phased warning poses over the final 84 ticks. Waking restores full-height artwork, shared walking animation, and normal damaging/stomp contact; pause freezes the sequence. See [walking Koopa](archive/koopa.md).


### Nested entity activity

BaseEntity suspension visits its internal nodes and stops at nested BaseEntity roots. The same boundary applies to animation suspension and cached activity geometry. The area tracks each entity independently: sleeping a painted spawner does not freeze its moving actors, and waking the spawner cannot restore processing over a child's independent suspension. SpawnableEntity actors retain shared offscreen removal and release their category slots when freed. Area/title/transition lifecycle paths suspend entities explicitly; tree pause still freezes gameplay. New entity types inherit these boundaries without individual sleep/cleanup code.


### Consecutive enemy stomps

BasePlayer owns its airborne stomp chain. Accepted Goomba stomps and Koopa walking/moving-shell stomps award 100, 200, 400, 500, 800, 1000, 2000, 4000, 5000, 8000, then repeated 1-Ups through the shared enemy popup/reward helpers. Rejected hits do not advance it. Landing in shared player movement or beginning death resets it; pause preserves it. Shell defeat chains remain independent. This intentionally omits the NES short-lived StompTimer scoring modifier.


Shell kicks use Mario's current stomp-chain count without incrementing it: 400, 500, 800, 1000, 2000, 4000, 5000, 8000, then repeated 1-Ups. Landing therefore restores the normal 400-point kick. Remaining wake time overrides this calculation at 22-42 ticks (500) and 1-21 ticks (1000), mapping the reference interval counts onto the existing fixed 336-tick wake sequence. Kicking a moving shell is rejected. Each Koopa owns a 12-physics-tick (0.2-second) grace window after an accepted stomp. During that window, fresh contact with that same moving shell can stop it and bounce Mario without descent. A stomp refreshes grace; a kick does not. Other actors receive no grace, and the overlap latch still requires separation. Pause freezes the countdown; waking or permanent defeat clears it. This is a deliberate shell-local rule rather than the NES shared player timer.


### Koopa block stuns

GreenKoopa accepts block_bump through the shared BlockHitReceiver without permanent defeat. ShellStunned reuses Walking physics for a recoverable upside-down launch: two pixels upward, -180 px/s vertical velocity, and 60 px/s horizontally away from the attacker. Landing enters ShellIdle and starts its existing 336-tick recovery window; kicking is allowed before landing and preserves upside-down presentation. Each new valid bump reapplies the launch and awards 100 points without advancing Mario's stomp chain. Bumping a moving shell preserves ShellMoving and its enemy-hit chain, but slows it to 60 px/s and turns its artwork upside-down. A subsequent kick restores 180 px/s; a stopping stomp restores the upright shell. Waking restores upright walking and global animation. Orientation is Koopa-owned; movement, gravity, cleanup, scoring, and contact continue through shared paths.

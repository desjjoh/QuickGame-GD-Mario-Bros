# Green Koopa

Walking and stomp-to-stationary-shell implemented 2026-11-07. Kicking, stopping, and shell attacks are now implemented. Waking and reference 1-1 placement remain future steps. Winged artwork is not used yet.

## Shared behavior

green_koopa.tscn inherits BaseEnemy directly and selects the existing Walking state. It shares 30 px/s normal walking, 857.8125 px/s² gravity, the 180 px/s fall cap, move-before-gravity integration, terrain wall reversal, enemy reversal, lifecycle, activity, and cleanup. Walking's new face_movement flag updates asymmetric artwork on entry and direction changes. Goomba leaves it disabled and keeps its existing behavior.

The initial walking-only milestone had no Mario interactions. The current green_koopa.gd enables shared player contact while Walking and handles stomps by entering ShellIdle. Side contact uses the existing level/player damage path (currently death for small Mario). Successful stomps use the shared -240 px/s rebound and stomp cue, then award 100 points once through BaseEnemy.award_score. This helper also supplies Goomba's existing score popup. Shell entry does not mark defeat, consume the spawner, or release the enemy slot. BlockHitReceiver is inherited, but no Koopa block-hit response has been implemented yet.

## Artwork and contact geometry

Each supplied koopa.png is an 80×32 sheet. Only columns 0 and 1 (16×32 cells) animate, eight ticks each, synchronized through the global cosmetic clock. The walking art occupies 23/24 visible pixels beneath transparent top padding. Sprite2D is positioned (0,-8) relative to the body; its bottom aligns with the inherited 14×16 body's bottom. Artwork height does not enlarge the terrain body.

The separate Mario-contact area is 12×12 at (0,-1) relative to Body. This translates the NES control-3 offsets (2,9)-(14,21) into the same actor origin used by the existing Goomba. The Goomba control-9 contact remains 10×6. Shapes are coordinate spans, not inclusive pixel counts. The terrain rectangle remains this project's Godot approximation of NES probes; exact edge-contact parity is not claimed.

Reference values were taken from InitNormalEnemy, TallBBox/SmallBBox, BoundBoxCtrlData, MoveNormalEnemy, MoveD_EnemyVertically, and EnemyAnimTimingBMask in the [SMB disassembly](https://gist.github.com/1wErt3r/4048722). Rendered contact alignment still needs comparison with Mesen.

## Painting and themes

EnemyLayout remains an 8×8 grid. Source 2 is Green Koopa Spawner in every theme; no marker is added to EntityLayout. Its atlas region is 16×32 with texture_origin (-4,4), matching the live sprite's top-left/feet alignment rather than placing its feet one row lower. The marker uses the matching theme's sheet, and AreaTheme maps live Overworld art to Underground/Castle art.

The generic EntitySpawner instantiates GreenKoopa in the enemy category. It uses the existing ten-enemy cap, once-per-area-load attempt, no deferred retry after capacity denial, and no saved defeated progress. BaseLevel, TestLevel, and 1-1 expose the mapping so the marker is usable. Existing authored enemy placements were not changed.

## Verification

koopa_walking_test reached PASS in Godot 4.7.2 headless. It verifies theme art and marker regions/origins, no actor before activation, placement coordinates, shared tuning, terrain/contact dimensions, feet alignment, initial gravity integration, landing, global animation joins, actual enemy reversal and facing, wall reversal, offscreen cleanup, and no respawn from the consumed placement. Combat deferral is explicit in the test.

Enemy-spawn, enemy-contract, and area-theme checks also reached PASS. Enemy-spawn reported two ObjectDB leaks. Focused formatting and diff checks passed. Full suite, rendered editor/game testing, and a Mesen frame comparison were not performed. No project settings or import options were changed; new sprites were imported with existing defaults.

## Stationary shell milestone - 2026-11-07

ShellIdle extends the shared Walking script with walk_speed zero. It immediately clears horizontal velocity and continues the same gravity/terrain integration, allowing a shell to fall. Entering it disables synchronized walking and holds the upper 16x16 shell pose in column 4 of the same themed sheet (hframes 5, vframes 2, frame 4). Sprite position (0,2) aligns the opaque shell bottom with the terrain body's feet. Contact and terrain shapes do not resize.

At this initial stationary-shell milestone, the shell was harmless to Mario. This temporary policy is superseded by the shell interactions below. Wake timers and player stomp-combo scoring remain deferred. Pause stops its physics and artwork through normal tree pausing. No health system was added.

koopa_contact_test reached PASS headlessly in Godot 4.7.2. It covers real Mario overlap, exact rebound without position/X-velocity changes, stomp audio, one score award, nonterminal state/slot retention, all themed shell frames, harmless repeated shell contact, pause, stationary/falling shell physics, and walking side-contact death/life loss. Koopa-walking, enemy-spawn, enemy-contract, pause, and death checks also reached PASS. Koopa-contact and enemy-spawn reported two ObjectDB leaks each; death three. Rendered shell alignment and Mesen frame/audio comparisons remain outstanding. Full suite was not run.

## Kicking, stopping, and shell attacks - 2026-11-07

Idle shell contact kicks it away from Mario at 180 px/s and awards 400 points with the generated enemy-smack cue. A descending contact on a moving shell returns it to ShellIdle, awards 100 points, and uses the shared -240 px/s Mario rebound/stomp sound. Other fresh moving-shell contact damages Mario through the existing level path. A player-contact latch holds until separation, preventing a kick/stop from immediately becoming another interaction during the same overlap. It uses the shared contact cadence; no arbitrary invulnerability duration is introduced.

ShellMoving extends the same shell/Walking state path, retaining gravity and wall reversal, with bump audio on wall turns. It holds the static shell pose rather than inventing a spinning animation. Enemy contacts identify the target; active shell overlap polling also catches a target already touching when the shell is kicked. One attack is attempted per target overlap. Rejected or surviving hits do not advance the chain or award defeat points.

Goombas and walking/idle Koopas accept shell hits into their shared flipped knock-out physics. A moving shell survives hitting a stationary shell. Two moving shells defeat each other: the source awards its target the current chain value and receives 1000 points for its own defeat. The first such mutual collision totals 1500 points. This follows ProcEnemyCollisions' asymmetric awards; exact NES slot-order/popup correspondence is not claimed. Squashed Goombas accept a shell impact as a post-defeat physical reaction without clearing permanent defeat or emitting its signal again.

Shell chain awards are 500, 800, 1000, 2000, 4000, 5000, 8000, then one life per subsequent enemy. The chain belongs to the live Koopa and survives wall rebounds and stop/re-kick; a new actor starts fresh. Extra lives use the existing 1-Up popup/cue. Independent guards prevent repeated pair callbacks or sustained overlap from duplicating rewards.

SoundHandler adds enemy_smack from PlaySmackEnemy: 14 nominal frames, frequency offset $28 (period $ef), control $9f/sweep $cb, with muted continuation frames and the second timer-low/control write at frame 6. All playback remains non-positional at default gain and pitch. No amplitude/pitch retuning was performed.

Reference: HandlePECollisions, KickedShellXSpdData, HandleStompedShellE, ProcEnemyCollisions, ShellOrBlockDefeat, and PlaySmackEnemy in the linked disassembly. Waking and its time-dependent kick bonuses are not implemented; ordinary kicks currently award 400, and stomps 100 without a shared player stomp-combo counter. Mesen frame/audio comparison remains outstanding.

shell_interaction_test covers physical Mario kicks in both directions, wall rebound, stopping, fresh moving-shell damage, pause, full chains/repeated lives, stop/re-kick chain retention, surviving-hit behavior, duplicate prevention, squashed/normal Goombas, walking/idle Koopas, mutual shell defeat, and actual enemy overlap already present at kick time. Shell-interaction, enemy-spawn, enemy-contract, Koopa-contact, Koopa-walking, pause, and sound-mix checks reached PASS headlessly in Godot 4.7.2. Expanded shell-interaction reported four ObjectDB leaks; Koopa-contact two. Full suite and rendered playtesting were not performed.


## Waking and reference stage placement - 2026-11-07

ShellIdle now counts 336 active physics ticks (5.6 seconds at 60 Hz). Its final 84 ticks alternate the upper shell pose (frame 4) and lower warning pose (frame 9) using bit 3 of the pause-aware global animation clock. ShellMoving retains terrain behavior without advancing the wake sequence. Each new stopping stomp restarts the idle countdown. Pause freezes countdown, warning pose, walking phase, and motion through normal gameplay processing.

At expiry the sprite returns to vframes 1 and position (0,-8) before Walking activates its SynchronizedAnimation. The walking cycle therefore samples the current shared eight-tick phase immediately, rather than restarting locally. Direction follows reference ReviveStunned: even global ticks face right, odd ticks face left; walking speed remains 30 px/s. Normal damaging and stomp contact returns with Walking. Terrain/contact dimensions and shell chain ownership remain unchanged. Near-wake kick bonuses and player stomp-combo scoring remain deferred; kicks still award 400 points.

Reference: [SMB disassembly](https://gist.github.com/1wErt3r/4048722), RevivalRateData, ReviveStunned, RevivedXSpeed, CheckForBloober, and CheckForSecondFrame. The NES starts with 16 interval counts, decremented on a shared 21-frame timer; its starting phase makes total duration variable. This implementation deliberately uses a fixed 336-tick duration and 84-tick warning, following the project's preference to omit shared gameplay frame rules. Hard-mode timing/speed are not implemented.

Painting already supports source 2 in all three themed 8x8 EnemyLayout palettes and the shared entity registry. No extra painter or spawner path was added. E_GroundArea6 contains one green Koopa: the $bb,$00 record on page 6 gives X=$6b0 (1712), reference Y=$b0 (176). The established actor-origin conversion adds 8 to Y, so the marker is cell (214,23), world origin (1712,184). Its 16-pixel terrain body initially ends at Y=200, eight pixels above ground at Y=208. Existing Goomba markers are preserved. Existing enemy-category limits, consumed activation attempts, cleanup, and area/death reconstruction apply unchanged.

Verification: koopa_wake_test, koopa_walking_test, koopa_contact_test, shell_interaction_test, enemy_spawn_test, entity_registry_test, and pause_test reached PASS in Godot 4.7.2 headless. Wake regression uses fixed 60 FPS for exact tick assertions; it covers the warning artwork, frozen timer/global clock during pause, precise expiry, restored contact/geometry/global walking phase, stopping reset, rolling exclusion, and the single authored Koopa location. Pause's audio-completion assertion failed under fixed-FPS execution and passed on a real-time rerun. ObjectDB warnings occurred in wake (7), contact (4), shell interactions (5), enemy spawn (8), and pause (2). Full suite, rendered/Mesen comparisons, and manual stage playthrough were not performed.


## Shared airborne stomp chain - 2026-11-07

Supersedes the previously deferred player stomp chain and flat 100-point stomp behavior. BasePlayer owns the chain across mixed enemies: 100, 200, 400, 800, 1000, 2000, 4000, 8000, then one extra life for every subsequent stomp. Goomba and Koopa call BaseEnemy.award_stomp only after accepting the reaction. Stopping a moving shell participates; kicking, block bumps, and shell defeat chains retain their independent rewards. Non-player synthetic stomps retain a 100-point fallback. Existing shared popups, extra-life sound, score, and lives paths are reused.

Actual floor contact in BasePlayer.move_body resets the chain, as does beginning death. A new player starts at zero; no session persistence is added. Pause freezes gameplay and retains the count. The count saturates at the repeated-1-Up tier. Reference HandleStompedShellE increments StompChainCounter, and LandPlyr clears it. The NES additionally adds its short-lived StompTimer to the award index; this implementation deliberately omits that timing modifier and uses one step per accepted airborne stomp. No Mesen comparison was performed.


## Chain-aware kicks and kicked-shell audit - 2026-11-07

Supersedes the earlier flat-400 kick and deferred near-wake kick bonuses. BasePlayer.award_shell_kick uses reference score control 3 + StompChainCounter without incrementing Mario's chain. For counts 0 through 7 this awards 400, 500, 800, 1000, 2000, 4000, 5000, 8000; higher counts repeat 1-Ups. This uses the kick score table, including 500 and 5000, independently of the previously implemented simplified stomp progression. A kick after landing gets 400; a kick after one airborne stomp gets 500.

GreenKoopa snapshots ShellIdle's countdown before changing state. ceil(remaining_ticks / 21) maps the existing local timer to reference EnemyIntervalTimer counts. Counts 2, 1, and 0 override chain scoring with 500, 1000, and 8000 respectively. Natural idle processing changes to Walking at zero before player contact, so the zero table entry is tested synthetically and is not an extra normal-gameplay bonus window. Fixed wake duration and omission of shared starting-phase variation remain deliberate. Non-player synthetic kicks keep the 400 fallback. Sound, direction, velocity, and shell defeat chains are unchanged.

Reference audit (disassembly, not a Mesen observation): HandlePECollisions applies a player-overlap latch, kicks an idle shell away at 3 px/frame, and routes moving shells into the player injury/stomp check. Our overlap latch, 180 px/s kick, descending stop, wall reversal, enemy defeat chain, retained chain after stopping/re-kicking, and mutual-shell defeat are covered by existing regressions. The reference additionally checks StompTimer: a recent stomp can turn a non-descending contact into another stomp. Our implementation has no post-stomp grace timer and requires positive vertical velocity. Reference per-object offscreen collision suppression and exact original enemy-slot ordering are also not reproduced by modern camera-buffer activation/contact handling. These are remaining fidelity differences, not claims of complete parity. The previously simplified airborne stomp scoring still omits StompTimer's award-index modifier and its 500/5000 intermediate score controls; kick scoring now follows its full table.

Verification: shell_kick_score_test, shell_interaction_test, stomp_chain_test, koopa_wake_test, and nested_entity_activity_test reached PASS in Godot 4.7.2 headless at fixed 60 FPS. Coverage includes all kick chain tiers, no chain increment, exact 43/42/22/21/1/0 tick boundaries, late bonus overriding a life-tier chain, rejected repeat kicks, actual overlap kick awards, stop/re-kick behavior, wall rebounds, enemy/shell outcomes, pause, waking, and offscreen cleanup. Existing shell score assertions were updated from flat 400. ObjectDB exit warnings occurred (21, 5, 9, 7, and 2 respectively). Full suite, rendered playtesting, and Mesen contact comparison were not performed.


## Full stomp score ladder - 2026-11-07

Supersedes the earlier shortened airborne progression. Accepted stomps now use 100, 200, 400, 500, 800, 1000, 2000, 4000, 5000, 8000, then repeated 1-Ups. This is one score-control step per accepted stomp; the NES shared StompTimer award-index addition remains deliberately omitted. Existing grounded/death resets, rejected-hit protection, and separate kick/shell defeat scoring are preserved.


## Individual shell stomp grace - 2026-11-07

Implemented with the user's explicit choice of 0.2 seconds (12 physics ticks). The timer is stored on the individual GreenKoopa actor, not BasePlayer, GameHandler, or a shared contact singleton. An accepted stomp into ShellIdle starts or refreshes it. Idle and moving states count it down; kicking preserves the remaining value. A fresh moving-shell contact during grace is accepted as a stomp even while Mario is rising or stationary. Ordinary descending stomps remain valid after expiry. BaseEnemy exposes a default descending-only _can_stomp hook, and Koopa extends it only for its own moving-shell grace. Other shells, walking Koopas, and Goombas receive no grace from that stomp.

The overlap latch remains authoritative, so an uninterrupted overlap cannot stop/kick repeatedly or duplicate rewards. The stop still gives the shared Mario rebound, stomp audio, and next player-chain reward. Countdown updates after contact processing and does not consume a refreshed tick during the successful stomp's physics update. Pause and existing gameplay suspension stop its physics callback. Waking to Walking or accepting permanent shell defeat clears the timer; removal/reload naturally discards the actor and its timer.

Correction to the earlier reference interpretation: StompTimer ($0791, Timers+$11) is a frame timer. HandleStompedShellE increments it once; DecTimers decrements it every eligible frame, not on the 21-frame interval cadence. Consequently it is not a fixed long grace window. The chosen 12-tick shell-local reset is a deliberate gameplay difference, approved in this conversation, independent of the unchanged fixed wake countdown and near-wake scoring. No project settings changed. The corrected full stomp score ladder remains one step per stomp, without the NES timer addition.

Verification: shell_stomp_grace_test, stomp_chain_test, shell_interaction_test, shell_kick_score_test, koopa_wake_test, and enemy_spawn_test reached PASS in Godot 4.7.2 headless. New checks cover actual rising overlap, shell-local isolation, no kick refresh, stop refresh, exact expiry, pause, same-overlap reward prevention, descending stop after expiry, clearing on Walking, and the full literal score table through repeated lives. Existing moving-shell damage coverage now waits for grace expiry. ObjectDB exit warnings remain; full suite and rendered/Mesen comparison were not performed.


## Recoverable block bumps - 2026-11-07

Implemented: walking Koopas, stationary shells, and already stunned shells accept the existing block_bump maneuver into ShellStunned. It inherits shared Walking movement/gravity/wall/enemy reversal, selects the upside-down shell presentation, and applies a two-pixel lift, -180 px/s vertical velocity, and 60 px/s horizontal velocity away from the hit's attacker. Valid repeat bumps reapply this impulse and award another 100 points. These are recoverable reactions, not permanent defeats, and retain the actor's enemy-category slot. Mario's stomp chain and the existing shell grace are not refreshed by a block bump.

ShellStunned uses existing BlockHitReceiver integration; no separate collision detector or enemy spawner was added. Its landing transition enters ShellIdle, stops horizontal movement, and starts the existing fixed 336-tick recovery countdown. Orientation is stored on GreenKoopa so an upside-down idle shell can warn, wake, or be kicked using the same states. Stopping a moving shell by stomp restores the upright pose; waking restores upright full-height Walking and its global synchronized animation.

An airborne stunned shell can be kicked immediately. Walking-to-stunned initializes the unused idle recovery countdown to zero; landing starts it. Thus an airborne kick of a newly block-stunned walking Koopa reaches the existing zero-interval 8000-point reference table entry. This supersedes the earlier note that zero was only reachable synthetically: the previous implementation had no block-stun path. A re-bumped idle shell retains/decrements its prior countdown while airborne, then restarts it on landing. Kicking derives its interval from that current value and does not refresh stomp grace.

Bumping ShellMoving preserves that state, dangerous Mario/enemy contact, and the actor's shell defeat chain. It flips the shell upside-down and changes horizontal speed to 60 px/s while applying the same upward impulse. Repeated moving-shell bumps reapply the impulse without clearing per-target overlap guards. A later stopping stomp enters upright ShellIdle; the next kick restores 180 px/s. Non-moving stunned shells do not deliver shell defeat hits. Shared terrain collision and cleanup remain enabled, unlike permanent KnockedOut defeat.

Reference: HandleEToBGCollision/GiveOEPoints, SetStun, EnemyBGCXSpdData, ChkLandedEnemyState, MoveNormalEnemy, and CheckUpsideDownShell in the SMB disassembly. The modern shared gravity integration is retained rather than reproducing the original moving-shell background-state sampling order. Existing fixed recovery duration, local 12-tick grace, simplified one-step stomp scoring, and camera buffers remain documented differences. Rendered upside-down alignment and Mesen comparisons are outstanding.

Verification: koopa_block_bump_test, shell_interaction_test, koopa_wake_test, shell_stomp_grace_test, shell_kick_score_test, enemy_spawn_test, and koopa_contact_test reached PASS in Godot 4.7.2 headless at fixed 60 FPS. New coverage includes a real brick bonk through BlockImpact's physics query and receiver, exact launch/repeat/direction/score values, retained slot and nonterminal outcome, pause, landing/recovery reset, airborne kick and 8000 reward, moving-shell slowdown/enemy defeat, upright stopping/re-kick speed, and global animation restoration. The final expanded block-bump test passed without exit warnings; the initial run reported ten ObjectDB instances. Other runs reported ObjectDB warnings (shell interaction 5, wake 6, grace 12, kick score 21, enemy spawn 6, contact 4). Full suite and manual rendered playtesting were not performed.

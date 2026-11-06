# Settings reference

Snapshot recorded 2026-11-01 from current files. Earlier changes are reconstructed from the project conversation. Ask before future settings changes and record their approval here.

## Approved project configuration

| Setting under Project Settings | Original observed value | Current value | Reason and approval |
| --- | --- | --- | --- |
| `application/run/main_scene` | Unassigned | `res://scenes/main/game.tscn` | Game entry point; explicitly approved with pixel-art setup |
| `display/window/size/viewport_width` | Unspecified | `256` | Logical play area; explicitly approved |
| `display/window/size/viewport_height` | Unspecified | `240` | Logical play area; explicitly approved |
| `display/window/size/window_width_override` | Unspecified | `768` | Initial 3× window; explicitly approved |
| `display/window/size/window_height_override` | Unspecified | `720` | Initial 3× window; explicitly approved |
| `display/window/stretch/mode` | `canvas_items` | `viewport` | Render at logical resolution before scaling; explicitly approved |
| `display/window/stretch/aspect` | `expand` | No explicit override; intended `keep` behavior | Preserved aspect ratio explicitly approved; `keep` was written during setup and is now omitted from the file |
| `display/window/stretch/scale_mode` | Unspecified | `integer` | Consistent pixel sizes; explicitly approved |
| `autoload/GameHandler` | Absent | `*res://scripts/handlers/game_handler.gd` | Shared game state and level ownership; explicitly approved |
| `autoload/ControllerHandler` | Absent | `*res://scripts/handlers/controller_handler.gd` | Shared input source; explicitly approved |
| `input/secondary` | Absent | Deadzone 0.5; physical Left Shift and gamepad left face button (index 2, any device) | Run binding explicitly approved 2026-11-01; ControllerHandler secondary action name changed from blank to `secondary` |
| `input/primary` | Absent; handler used `ui_accept` | Deadzone 0.5; physical Space/Enter/keypad Enter and gamepad bottom face button (index 0, any device) | Explicitly approved 2026-11-01 after runtime inspection showed no joypad binding in `ui_accept`; handler now uses `primary` |

"Unspecified" means the original project did not serialize an override, not that an effective engine default was measured. The `*` in autoload paths enables the singleton.

## Scene and resource configuration

| Location | Deliberate configuration | Context |
| --- | --- | --- |
| TestLevel root | Nearest texture filtering | Approved for pixel-art setup; inherited by its terrain |
| Mario root | Nearest texture filtering | Applied when creating the requested sprite-based player; local to the scene |
| Terrain TileSet | 16×16 cells/atlas regions; ground collision on physics layer 1 | Implements requested floor grid; dimensions may be omitted when matching resource defaults |
| Camera2D | Position `(128, 120)`; default zoom `(1, 1)` | Frames the approved logical play area |
| BasePlayer | 16×16 rectangle centered at `(0, -8)` on Body | Feet-based origin for the requested player foundation |
| ControllerHandler | Physics process priority `-100`, set in code | Samples held input before ordinary entity physics callbacks |
| MotionValues | Walk cap `90` pixels/s; acceleration/deceleration `133.59375` pixels/s²; reversal multiplier `2` | Replaces the earlier prototype values of 96/600/800 on HorizontalMovement; rationale and limits in [movement](movement.md) |
| Run action | Cap `150` pixels/s; acceleration/deceleration `200.390625` pixels/s²; priority 100 | Applies a named modifier to shared values; original release-timer behavior not implemented |
| Mario Idle | Stop Animation On Enter = true; Sprite Frame = 0 | User clarified Idle is a static pose, without an idle animation |
| Slide action | Entry/stop 41.25 pixels/s; fast threshold 105; friction 133.59375 or 182.8125 pixels/s²; reversal multiplier 2; cap 90; priority 300 | Added for requested reversal skidding; source conversion and fidelity limits in [movement](movement.md) |
| Mario state textures | Idle/Slide use static standing/skid textures; Move seeds walk-1 then plays `walk` | Static states stop playback; Move no longer stops the AnimationPlayer on entry |
| Mario AnimationPlayer | Physics callback mode; external `walk` animation in default library | Requested velocity-driven walk/run loop; no project/global animation settings changed |
| Mario WalkAnimation | Medium/fast thresholds 52.5/105 pixels/s; pose timer bands 7/4/2 | Changes playback rate using actual velocity; baseline resource interval 7/60 seconds |
| MotionValues vertical defaults | Gravity 1575 pixels/s²; weight 1; fall-speed limit 240 pixels/s | Requested editable node values; gravity profiles can override the default, weight scales gravity only |
| Jump action | Editable takeoff-speed thresholds, impulses, rising/falling gravity arrays; minimum release height 1 pixel | Requested variable-height jump; see [jumping](jumping.md) for table and source limits |
| Mario Air | Supplied air texture; stop playback; sprite frame 0 | Requested common rising/falling state; no project/import changes |
| Mario Actions/Jump | Sound Effect = `assets/sfx/smb_jump-small.wav` | Plays once on successful launch at the user's request; no audio-bus or import settings changed |
| AirMovement | Speed threshold 93.75; history threshold 105; acceleration 133.59375/182.8125/200.390625; caps 90/150; facing mismatch ×2; modifier priority 300 | Separate air control and skid-jump braking; neutral drag remains zero. See [jumping](jumping.md) for context/history approximation |
| BaseState | Optional enter/exit animation and sound slots; mirror sprite offset enabled | Added with the requested state effects; no sound assets or animations assigned |

Project, import, and scene properties are different scopes. Do not silently turn a local scene choice into a global default.

## Input bindings

Directional actions use existing `ui_left`, `ui_right`, `ui_up`, and `ui_down`. Primary uses dedicated `primary` for keyboard and gamepad jumping; secondary uses `secondary` for Run. Start/select remain unassigned and require approval before bindings are added. PNG imports retain generated defaults. The jump WAV has the approved loop override below.

## Audio import override — 2026-11-01

`assets/sfx/smb_jump-small.wav.import`: `edit/loop_mode` changed from 0 (Detect From WAV) to 1 (Disabled), with explicit user approval. The file's embedded metadata enables a loop with begin/end both zero. Following that metadata produced near-silent playback. Reimporting with looping disabled restores the full 0.59-second sound. Compression, volume, buses, and the source WAV remain unchanged. Controller/audio tests now check imported loop mode and decoded sample amplitude, rather than only node creation. Runtime bus capture confirmed a non-silent jump waveform; physical speaker output remains a user playtest.

## Preserved generated configuration

The original project declared Godot 4.7, Forward Plus, Windows D3D12, and Jolt for 3D physics. These were retained, not chosen as part of the 2D platformer setup.

## Reverted configuration

The first scaffold added a blue `rendering/environment/defaults/default_clear_color` override, a 960×540 viewport, and a World layer name. The user requested restoration of the original setup, and those overrides were removed before the later approved pixel-art setup. There is currently no background-color override or named physics-layer override in `project.godot`. The initial starter scenes/docs were also removed. These earlier edits did not have the later explicit settings-approval workflow; they are retained here as history, not retroactively marked approved.


## Combined shadow scene configuration — 2026-11-01

User authorized a trial of a combined level drop shadow. BaseLevel root changed from Node2D to CanvasGroup (script superclass matches), with a new ShaderMaterial. Fit/clear margins are explicitly 8 pixels (CanvasGroup defaults: 10). Shader defaults: offset (3, 3), black at 0.4 alpha, enabled. This is scene configuration; project, viewport, camera, and import settings are unchanged. See level-shadow.md.


## Outer blur adjustment — 2026-11-01

Requested visual revision: shader default shadow_offset changed from (3, 3) to (0, 0); new blur_radius defaults to 4 logical pixels. Opacity stays 0.4 and CanvasGroup margins stay 8. These are shader defaults, with no project/import settings changes.


## Horizontal player confinement — 2026-11-01

Requested BaseLevel behavior: keep_player_on_screen defaults true, horizontal_screen_inset defaults 7 world pixels to match the reference app, and level physics priority is 100 to clamp after player motion. No project/input/import settings changed. Camera rotation is not supported by this horizontal world-axis rule.


## Camera boundary speed correction — 2026-11-01

The user approved matching the investigated SMB screen-edge speed rule. Horizontal speed now resets at either camera edge unless player-state input points inward; Y speed is preserved. This supersedes the earlier velocity-preserving behavior. Inset and camera settings are unchanged.


## Entity layout scene configuration — 2026-11-01

User authorized TileMap-driven entities and test blocks. BaseLevel now includes EntityLayout (collision_enabled=false, navigation_enabled=false) and WorldObjects. TestLevel assigns the separate 16-by-16 entity_layout.tres marker TileSet, maps brick to BrickBlock in Entity Scenes, and paints four cells. Markers are hidden at runtime after startup generation; entity scenes own collision. Project, Input Map, and import settings are unchanged.


## Wider stage and right-only camera — 2026-11-01

User requested a wider level and camera follow, then explicitly selected original NES right-only scrolling. TestLevel floor extended from X=0..256 to X=-128..768 (8 tiles left, 32 right), preserving block markers. Camera center changed (128,120) to (0,120); PlayerSpawn changed (40,208) to (-88,208) so initial screen X remains 40. Camera2D uses LevelCamera, physics callback mode 0, default bounds -128/768, thresholds 80/112, and target-origin correction 8. No project/Input Map/import settings changed. See camera.md for fidelity limits.


## Original test-stage size restored — 2026-11-01

At the user's request, restored TestLevel floor to X=0..256, camera start (128,120), and PlayerSpawn (40,208). Scene-level camera bounds override World Left/Right to 0/256; reusable LevelCamera defaults, thresholds, right-only logic, and fractional tracking remain unchanged. Block layout retained. A one-viewport-wide level has no scroll room. No project/import settings changed.


## Outer halo saved override correction — 2026-11-01

Restored BaseLevel ShaderMaterial shadow_offset from saved (3,3) to (0,0) after the user reported the appearance had reverted. Shader defaults already used zero offset; the serialized material was overriding them. Radius remains 4, opacity remains 0.4, margins remain 8.


## Halo visibility tuning — 2026-11-01

Requested visibility adjustment: BaseLevel saved shadow_color alpha increased from 0.4 to 0.55. Centered offset (0,0) and blur radius 4 remain unchanged. Rendered preview completed successfully; no project/import settings changed.


## Decorations layer — 2026-11-02

Requested layer addition: BaseLevel Decorations is a TileMapLayer with z_index=-1, nearest texture filtering (1), collision_enabled=false, and navigation_enabled=false. TestLevel assigns the new 16-by-16 decorations.tres TileSet and two sample bushes. No physics layers are defined on that TileSet. The existing camera, terrain, entity markers, halo, and project/import parameters are unchanged; newly supplied bush sprites use default imports.


## Decorations composite ordering correction — 2026-11-02

Corrected Decorations z_index from -1 to default 0 and moved it to first sibling draw order in BaseLevel/TestLevel. This keeps decorations behind gameplay while allowing CanvasGroup to include their alpha in the shared halo. No shader, collision, project, or import parameters changed.


## Small Mario collision shape — 2026-11-02

Requested correction: Mario scene now overrides the inherited 16-by-16 shape centered (0,-8) with an 11-by-14 shape centered (-0.5,-7). The base player remains generic, sprites and feet origin remain unchanged, and camera inset stays 7. This approximates NES head/side terrain-probe extents; distinct foot/enemy probes are not implemented. No project/import parameters changed.


## Player corners and foreground order — 2026-11-02

Requested corner/landing forgiveness: BasePlayer now includes Motion/CornerCorrection with landing_tolerance=4 pixels and head_corner_tolerance=4 pixels. BaseLevel places WorldObjects then Players last on readiness; base scene order also places Players last. All affected visuals remain Z=0 for the shared halo. Project/import settings, artwork, level painting, and movement coefficients are unchanged.


## Project display name — 2026-11-02

User requested renaming the project to QuickGame-Godot2D (Super Mario Bros). Updated application/config/name from QuickGame-Godot2D to that exact value. README title matches. Workspace folder and resource paths remain unchanged. Godot's default user:// data location is derived from the project name, so it changes unless explicitly overridden; current session data is memory-only and no save migration was performed.


## Platformer project identity — 2026-11-02

At the user's request, application/config/name changed from QuickGame-Godot2D (Super Mario Bros) to QuickGAME-GD Mario Bros. This supersedes the earlier display-name decision: the tutorial covers multiple games. README uses the broader identity; game-specific implementation references remain accurate. The workspace folder is unchanged. The default user:// directory follows the new display name; no saved-data migration was performed.

## Shared layout grid — 2026-11-02

User requested grouped, consistently aligned decoration/entity/ground layouts and explicitly required ground in BaseLevel. These are scene/script rules, not Project Settings: Layouts and its TileMapLayer children use identity local transforms; assigned TileSets use 16x16 square cells. BaseLevel now owns all three layers. Existing painted cell data, terrain collision, halo parameters, camera, Input Map, and import settings are preserved.

## Softer halo over blue background - 2026-11-02

At the user's request, BaseLevel's material shadow_color alpha changed from 0.55 to 0.28 and blur_radius from 4 to 6 logical pixels. Shader defaults now match. The Gaussian alpha kernel expands from 9x9 to 13x13 samples, retaining more of the low-weight tail for a gentler cutoff. Centered offset and 8-pixel margins are unchanged. This is scene/shader tuning, not a Project Settings or import change. The low logical viewport resolution still produces pixel stepping; no claim of eliminating all banding is made.

## Soft drop shadow - 2026-11-02

At the user's request, BaseLevel and shader default shadow_offset changed from (0,0) to (3,3) logical pixels. Retained the 6-pixel blur radius, 28% opacity, and 13x13 kernel. Increased CanvasGroup fit_margin and clear_margin from 8 to 12 pixels to accommodate the offset plus blur without clipping. These are scene/shader changes; project and import settings are unchanged.

## Tighter drop shadow - 2026-11-02

User requested less softness and offset. Changed BaseLevel material and shader defaults from offset (3,3) to (2,2), and blur radius from 6 to 4.5 logical pixels. Opacity remains 28%; the 13x13 kernel and 12-pixel margins are unchanged.

## Darker drop shadow - 2026-11-02

At the user's request, increased BaseLevel material and shader default shadow opacity from 28% to 38%. Offset (2,2) and blur radius 4.5 remain unchanged.

## Pipe testing space - 2026-11-02

User requested an expanded level and static pipe tiles. TestLevel camera World Right changes from 256 to 768; World Left remains 0. Extended floor rows 13/14 from columns 0..15 to 0..47 and background width from 256 to 768. Camera thresholds, viewport, spawn, existing decorations/entity markers, and shader tuning remain unchanged. Four pipe atlas sources use full 16x16 terrain collision; no project/input/import parameters changed.

## Eleven-tile stage shift - 2026-11-02

User requested shifting the stage right by 11 blocks. Painted cells moved +11 columns, PlayerSpawn moved +176 pixels on X, camera World Right changed from effective default 768 to explicit 944, and eleven columns of left floor were added. Camera initial center and tracking thresholds remain unchanged. No project/import settings changed.

## Lower test room - 2026-11-02

User requested a one-screen lower area with its own camera that cannot be left except by pipe. Added LowerArea at (0,512), a local (128,120) camera with follow disabled and bounds 0/256, and an arrival marker at (48,208). The camera starts disabled. Painted enclosed solid terrain and added a black 256x240 background. Main camera and current player spawn remain unchanged. No project/input/import settings changed; pipe traversal is still pending.

## Physics interpolation - 2026-11-02

Explicit user approval: enabled physics/common/physics_interpolation in project.godot (previously absent/default false). Physics remains 60 ticks per second; no camera smoothing, Input Map, shader, or painted scene changes. Initial player placement and camera target reset clear interpolation history. Follow/boundary logic now uses authoritative camera coordinates rather than the interpolated rendered center.

A short Forward+ rendered probe on an approximately 240-Hz display confirmed interpolation active, no same-tick physics-follow mismatches, and changing rendered canvas coordinates between physics ticks. This does not guarantee subjective smoothness or eliminate the 256x240 viewport's pixel stepping.

## Area theme setup - 2026-11-02

User requested area themes using the supplied palette artwork. MainArea selects Overworld; LowerArea selects Underground. Each area now owns its own grid layers, WorldObjects, Arrival, and Camera2D. Underground ground/brick/alternate-brick art replaces matching Overworld textures; missing art falls back unchanged. No project settings, Input Map, import parameters, physics values, shader tuning, or background colors changed.

Normalized LowerArea's origin from (720,240) to (464,384), converted its painted cells to local coordinates, changed Camera2D's local position from (-128,264) to (128,120), and Arrival from (-224,192) to (32,48). All their world positions remain unchanged. The fixed camera's bounds now correctly match its world view at 464/720, replacing stale 0/256 bounds. Main camera remains enabled; LowerArea remains explicitly disabled. Additional area cameras must be disabled until selected; BaseArea otherwise uses Godot's enabled camera default.

## Paintable one-way pipe entrance - 2026-11-02

User requested a paintable pipe entity leading to the second area, deferring return travel. Added EntityLayout source 3 in both theme marker sets and a TestLevel entity mapping. Pipe cap collision is 32x16; centered entry tolerance is 4 horizontal pixels and 1 vertical pixel, with grounded Down input required. BaseLevel switches the selected area camera and resets interpolation during deferred transfer. No project/Input Map/import settings or existing painted cells changed. Existing ui_down/ui_up actions are read through ControllerHandler.

## Full 2x2 pipe stamp and occlusion - 2026-11-02

User requested complete 2x2 pipe painting and foreground coverage for future descent. Pipe collision changed from 32x16 centered (16,8) to 32x32 centered (16,16); four sprites fill the same footprint. EntityLayout source 3 retains its ID but now previews a 2x2 atlas region anchored at the top-left. Added ForegroundObjects after Players, keeping pipe artwork at Z=0 in the existing shadow group. No project settings or existing import parameters changed; the newly generated preview PNG was imported with defaults. Existing painted anchors remain unchanged and now display the larger pipe.

## Named pipe endpoints and route authoring - 2026-11-02

User requested multiple pipe destinations before animations. BaseArea's existing Arrival marker now uses AreaEndpoint with endpoint_id arrival; its position is unchanged. Added an Endpoints container and TestLevel MainArea markers near_start=(48,208), near_end=(880,208). Exit Direction is metadata for future animation, not a new input or movement rule. Added per-area Pipe Routes resources keyed by marker cell, plus a Destination Endpoint Id export on PipeEntrance. Existing pipes default to lower/arrival. No project/Input Map/import parameters, existing painted cells, arrival positions, camera thresholds, or shader tuning changed. Explicit warp arrivals may now reposition scrolling cameras within their existing bounds.

## Pipe entry animation and sound - 2026-11-02

User requested entry animation/transition and supplied smb_pipe.wav. Mario now owns PipeEnter and assigns it through BasePlayer's exported transition-state reference. Default Entry Speed is 60 pixels/second and Entry Duration is 0.8 seconds, based on reference one-pixel/frame motion and a 48-frame timer. Pipe entry temporarily suspends player collision/control and source camera updates; exit/cancellation restores them. The sound uses a nonlooping runtime WAV copy; no project/Input Map/import parameters or existing painted routes/cells were changed. Destination emergence and screen fades remain unimplemented.

## Unoccupied area runtime unloading - 2026-11-02

User requested unloading unoccupied areas and chose preserving progress. BaseLevel now unloads inactive runtime branches after startup and at area handoff. Area metadata stays registered, while runtime nodes, collisions, actors, and cameras are freed. GameHandler caches per-area tile/block progress in memory. Editor authoring content, project/Input Map/import settings, camera parameters, pipe timing, and shader parameters are unchanged.

## Pipe background priority only during entry - 2026-11-02

User requested normal world ordering for pipes and putting Mario behind them only on entry. Removed ForegroundObjects and the pipe's RemoteTransform2D/reparenting; four pipe sprites stay with their entity. BaseLevel temporarily moves Players before Areas when reserving an entry and restores the saved sibling index on arrival, cancellation, or live state exit. Z indices remain 0; no project/Input Map/import, camera, timing, collision, or shader settings changed.

## Sideways pipe and return route scene configuration - 2026-11-02

Requested sideways tiles/entities and exit functionality add terrain sources 7-10 and entity marker source 4 in both themes. Existing IDs remain stable. New AreaEndpoint Animate Exit defaults false; TestLevel pipe_return enables it with Up at (928,144). LowerArea receives a 2x2 sideways entrance at (14,11); static junction cells (15,11)/(15,12) are removed from its footprint. Shared travel uses 30 px/s horizontally and existing 60 px/s vertically, suppresses controls/collision and restores them afterward. No Project Settings, Input Map, or existing import settings changed.

## Reference pipe travel scene values - 2026-11-02

Requested reference parity assigns Mario PipeEnter's Walk Animation Name to walk and Walk Cadence to Presentation/WalkAnimation. Side Entry Delay defaults to 52/60 seconds; side motion stops after 14 pixels at the aligned opening. AreaEndpoint Exit Distance defaults to 96 pixels, replacing sprite-height-derived emergence travel. Normal upward exit therefore lasts 96 ticks at the existing 60 px/s speed. Sound plays only on entry. The repaired endpoint parents are Areas/MainArea/Endpoints; their IDs and positions are unchanged. No Project Settings, Input Map or import settings changed.

## Vertical pipe entry position and facing - 2026-11-02

Requested behavior supersedes automatic entry centering: preserve the accepted body X coordinate and facing during vertical descent. The four-pixel alignment tolerance remains unchanged. Remove the emergence sound; entry sound remains assigned and nonlooping. Destination emergence placement/facing and travel timing are unchanged. These are script behavior changes, not Project Settings, Input Map or import changes.

## Explicit transport test route and start return pipe - 2026-11-02

User requested shared level transport and a return near the start instead of emergence from the original pipe. Added a source-3 upright EntityLayout marker at MainArea cell (4,11), ID stage_return, Entrance Enabled=false, Exit Enabled=true, Exit Distance=96; its entity supplies feet (80,176). LowerArea's existing sideways marker at (13,11), ID secret_return, targets main/stage_return. The existing MainArea entrance at (57,9), ID secret_entrance, targets lower/arrival. These are area TransportPlacement/TransportDestination Resources. Removed the old pipe_return spatial marker; retained ordinary spawn examples. Existing painted cells are preserved apart from the new clear-footprint marker. No third area/camera, Project Settings, Input Map, shader or import setting changes.

## Secret return destination changed to PlayerSpawn - 2026-11-02

Changed the explicit secret return Destination_start target from stage_return to player_spawn in main. Removed its now-unused Point_start resource and source-3 marker at MainArea cell (4,11). PlayerSpawn remains at its authored position (48,208). The sideways pipe scene's fallback target also uses player_spawn. No project/input/import settings changed.

## Editor-only world boundary guides - 2026-11-02

Requested visual guides for LevelCamera World Left/Right. New scene-script property Editor Guides / Draw World Bounds defaults true; it draws green/orange labeled lines at the existing global bounds without changing their values. No Project Settings, Input Map, import parameters, gameplay camera behavior or shader settings changed.

## Reliability audit: stable inherited scene identities - 2026-11-02

Persisted Godot-generated unique_id metadata on BaseArea's authored nodes and repaired TestLevel's near_start/near_end parent paths/identity paths under Areas/MainArea/Endpoints. Existing endpoint IDs/positions, painted layout data, camera settings and movement values are unchanged. The movement/transport fixes alter callback ordering/ownership, not tuning or Project Settings. No Input Map, import, shader or physics-rate settings changed. Reload an already-open TestLevel before saving the repaired hierarchy.

## Area theme soundtrack and silent test areas - 2026-11-02

Requested music lifecycle assigns Overworld Music to assets/soundtrack/01. Ground Theme.mp3 and Underground Music to assets/soundtrack/02. Underground Theme.mp3. New AreaTheme fields default Music Loop=true and Music Volume Db=0. BaseLevelArea Music Enabled defaults true and can disable playback per area. Automated silent_level/silent_game fixtures override both areas to false; the playable test stage remains enabled. Native MP3 looping is enabled only on runtime stream copies; existing imported loop=false values are unchanged. No Project Settings, Input Map or audio-bus settings changed.

## Area music configuration removed - 2026-11-03

At the user's request, remove the AreaTheme Music/Music Loop/Music Volume Db fields and BaseLevelArea Music Enabled property together with area playback. Remove soundtrack resource assignments and test fixture mute overrides. This supersedes the earlier area music configuration; retained audio assets are unassigned. Generic area entry/exit and entity SFX remain. No Project Settings or import settings changed. Future restoration prerequisites are tracked in [backlog](../backlog.md).

## Pit death configuration - 2026-11-03

User-approved first death implementation adds BaseLevel Fall Death Enabled=true, Fall Death Margin=2 pixels, Death Fallback Delay=1 second and Death Presentation Timeout=10 seconds. Death Sound references assets/soundtrack/smb_mariodie.wav on the base scene. GameHandler.reset_progress_on_death=false is global script configuration, preserving block/world progress; it replaces the earlier proposed per-level reset flag. Lives are unchanged. Runtime audio copies disable looping without changing existing import settings. No Project Settings or Input Map changes.

## Deeper pit death cutoff - 2026-11-03

User-approved reference adjustment changes BaseLevel Fall Death Margin from 2 to 34 pixels. Since small Mario's collision-envelope top is 14 pixels above his feet, death now triggers after feet pass viewport bottom +48 (Y=288 in the main view), two tiles deeper than before. This translates the reference's 32px drawing-envelope origin approximately; immediate cleanup, one-shot sound and restart timing are unchanged. No Project Settings or import changes.

## Persistent HUD scene configuration - 2026-11-03

Requested UI implementation adds Game/UI CanvasLayer at layer 10 with a full-viewport ScreenContainer and HUD. HUD uses nearest filtering, an 8px bitmap font/advance, 8px-aligned offsets and mouse pass-through. Coin uses the supplied Overworld 24x8 atlas with durations 3/1/1/1 at 7.5 steps/s. No existing import parameters, Project Settings, input bindings, world grid, camera or player configuration changed. Labels are static placeholders.

## Shared HUD/world/player composition - 2026-11-03

User-approved rendering change replaces Game/UI CanvasLayer layer 10 with a screen-space Control and adds Game/SharedShadow CanvasGroup with existing 12px margins. UI and compositor disable interpolation locally; native camera/body interpolation and Project Settings are unchanged. Game routes all contributors at Z=0 in world/UI/player order, temporarily returning the player behind world during pipes. Per-level material values remain the source and move to the runtime compositor without shader tuning changes; standalone base-scene composition remains. Existing import settings, physics values and level painting are unchanged.

## Fixed screen-space shadow compositor - 2026-11-03

Rendering bugfix changes Game root from Node to CanvasLayer at layer 0 and removes inverse camera transforms from UI. World/player render-root RIDs disable interpolation individually because their submitted camera transform is already interpolated; child body interpolation remains enabled. No Project Settings, existing import parameters, camera thresholds, player movement values or shader tuning changed. Shared world/UI/player shadow and foreground ordering remain.

## Shared cosmetic animation configuration - 2026-11-03

Requested global synchronization adds palette_pulse.tres with phase_ticks=[24,8,8,8], clock priority -90 and component offset default 0. HUD coin native autoplay is replaced by its enabled synchronization component. Question Active references its presentation component, with independent animation-name playback replaced by clock sampling. Existing texture/timeline resources and themes are retained. No Project Settings, Input Map, existing import settings or gameplay tuning changed.

## Run-release countdown - 2026-11-03

User-approved movement change adds RunAction Retention Ticks=10 (per-player script default, editable on Actions/Run). Grounded continuing-direction input retains the run profile for released ticks 1-9 and clamps to the effective walking cap on tick 10. Existing 150/90 px/s caps, acceleration/deceleration coefficients and reversal/jump/air values are unchanged; HorizontalMovement now enforces its one-sided directional cap immediately. No Project Settings, Input Map, import settings or camera tuning changed.

## Transition defaults - 2026-11-03

Game.transitions_enabled defaults to true. Original implementation used area_minimum_frames = 12 and level_minimum_frames = 147; these have been superseded by the definition resources below. The area minimum applies to each quick black phase around the level card as well. HUD is hidden during quick phases to cover theme changes and restored for the card. These are script/scene defaults; no Project Settings, input mappings or existing asset import settings changed. See [transitions](transitions.md).

## SFX playback balance - 2026-11-03

User requested consistent effect levels. New assets/audio/sound_effect_mix.tres defines master_volume_db=-3 and per-stream trims: jump 0, bump -4, pipe -1.5, skid -3.5, death -5 dB. Previously these runtime players used the engine-default 0 dB without shared source compensation. BaseEntity and BaseLevel now apply this profile before playback. These are runtime gain defaults in a new Resource, not changes to Project Settings, Input Map, source recordings or import parameters. See [audio](audio.md).

## Definition-driven transitions and Cover removal - 2026-11-03

User authorized removing Cover and preparing multiple transition types. Timings now live in assets/transitions/area.tres (minimum_frames=12) and level.tres (initial 12; intro stage 147 with HUD; blank outro 12). TransitionScreen/Cover is removed; existing intro artwork/layout moves to scenes/ui/transitions/level_intro.tscn. A temporary RenderingServer clear color supplies black while gameplay is hidden; its prior runtime value is restored on every terminal path. This is process-wide render state, not a persisted Project Settings change. No project/input/import setting was modified. See [transitions](transitions.md).

## Transition background correction - 2026-11-03

The user rejected the temporary black clear-color override. It has been removed along with definition/stage background_color fields. Transition code no longer reads or writes the renderer clear color; the existing background is used throughout. This supersedes the temporary-render-state description above. No Project Settings changed.

## Stage rename and independent one-screen sandbox - 2026-11-03

User authorized renaming the existing test stage to 1-1 and creating an unconnected one-screen test level. Game.initial_level now references scenes/levels/1-1.tscn, preserving its existing stage behavior and serialized UID. The new scenes/levels/test_level.tscn inherits BaseLevel with one Overworld MainArea, camera center (128,120), World Left/Right=0/256, Follow Enabled=false, spawn (48,208), ground columns 0..15 at rows 13/14 and empty decoration/entity markers/transport placements. No Game, menu or transport destination references the new scene. These are new scene defaults and an existing reference migration, not Project Settings/Input Map/import changes.

## Title startup and Start bindings - 2026-11-03

User authorized creating the single-player title and binding controls. Added Input Map start (deadzone 0.5) with Enter, keypad Enter and gamepad Start/Menu (JOY_BUTTON_START=6, any device). ControllerHandler.start_action changed from empty to start; Select remains empty. Existing primary/secondary and directional mappings were preserved. Added Game.start_with_title=true as normal startup policy; initial_level remains 1-1. TitleScreen.background_level references TestLevel. Gameplay fixtures explicitly opt out with start_with_title=false. No display, renderer, physics or import settings changed. This supersedes the previous instruction to leave TestLevel unconnected, following the user's subsequent request to use it behind the title.

## Entity controller capability - 2026-11-03

User requested controller input opt-in as the first entity activity change. New BaseEntity.controller_input_enabled defaults to false. BasePlayer and PipeEntrance scenes explicitly set it true; derived Mario and sideways pipe scenes inherit it. These are scene/script capability defaults within the requested scope, with no Input Map, Project Settings or import changes. Existing state Controls Enabled remains a separate gate. See [entity activity](entity-activity.md).

## Area camera activity defaults - 2026-11-03

Within the authorized activity/spawner work, BaseLevelArea adds Camera Activity / Activation Buffer=64 pixels and Deactivation Buffer=96 pixels, clamped at runtime to at least the activation margin. These are new exported script defaults, not changes to camera scrolling, Project Settings, Input Map or import settings. EnemySpawner adds Enabled=true and Respawn On Reentry=true; Enemy Scene is unassigned by default. No spawner instances were added to levels. See [entity activity](entity-activity.md).

## Player status and stage display defaults - 2026-11-04

Within the approved status/UI milestone, new-game defaults are Small form, score=0, coins=0, lives=3. App-session top score initially=0 and survives new games. New BaseLevel Stage Display exports are stage_label=1-1 and starting_time=400; level load initializes GameHandler display values. The title adds a white 8x8-grid TopScore label at (80,184); intro Lives width is 32 pixels to accommodate two digits. These are new runtime/scene defaults, not Project Settings/Input Map/import changes. Existing project.godot edits were present before this work and were preserved. No life deduction, countdown or automatic top-score update was enabled.

## Palette source-path migration - 2026-11-04

User authorized relocating assets/Overworld (Palette 1) to assets/palettes/overworld and assets/Underground (Palette 2) to assets/palettes/underground, including all reference updates. Existing import UIDs and semantic parameters were preserved; source_file/cache paths changed for the relocation and Godot rebuilt its generated cache. No Project Settings or Input Map changes were made. The bitmap-font importer automatically marked its PNG page to skip import; the existing texture import configuration was restored. Existing unrelated settings/artwork edits were preserved.

## Game-over lifecycle defaults - 2026-11-04

User approved NES reserve semantics (stored default/reset 2, displayed +1; terminal -1) and explicit game-over cleanup. Reserve clamp is -1..98 so display fits 0..99. Added game_over transition: 12 initial hidden frames, 378-frame HUD-visible card, 12 hidden outro. New optional TransitionStage wait_for_presentation=false and completion_timeout_frames=600 preserve existing stage behavior; the game-over card opts in and uses a ten-second audio watchdog. New smb_gameover.wav mix trim=-5 dB plus existing master=-3 dB. These are script/resource defaults within the authorized feature, not Project Settings/Input Map/import changes. No black overlay or clear-color override was added.


## Separable Game shadow - 2026-11-04

User authorized trying a two-pass blur after reporting no drops with the shared shader disabled. Game/SharedShadow changes from CanvasGroup to Node2D and owns two runtime SubViewports sized to the logical view plus 12px padding per edge. Default offset/blur/opacity and Shadow Shader Enabled=true are unchanged. Disabled bypasses capture and stops both buffer updates. BaseLevel's standalone/editor reference shader remains unchanged. These are scene/render implementation changes; no Project Settings, Input Map or import parameters changed. This supersedes the earlier Game/SharedShadow CanvasGroup implementation above.


## Title-menu Select - 2026-11-04

User requested Select-based menu navigation and approved a dedicated select Input Map action: Tab (physical key) plus gamepad View/Back (JOY_BUTTON_BACK, button 4, any device), deadzone 0.5. Previously Select was unbound and ControllerHandler.select_action was empty; it now defaults to select and publishes a just-pressed edge. Select cycles 1 PLAYER GAME / 1 PLAYER TEST; Start confirms. No other bindings or settings changed.


## Main-area right boundary reconciliation - 2026-11-04

User set World Right=2624 in the open scenes/levels/1-1.tscn scene, but Game loaded scenes/levels/worlds/world 1/1-1.tscn with 2688. Rendered diagnostics confirmed the loaded path/value and a right edge at 2688, 64px past the intended guide. Matched the active MainArea Camera2D.world_right to 2624. Artwork, pipe routes, camera code and Project Settings were unchanged. Both source copies still exist; future stage edits should use the active worlds/world 1 scene until the duplicate is consolidated.


## Small Mario sprite baseline - 2026-11-04

User approved matching the reference's one-pixel lower sprite presentation. In scenes/player/mario (small)/mario.tscn, Body/Sprite2D.position changes from (0,-8) to (0,-7). The baseline applies across states; per-state Sprite2D.offset remains additive. The 11x14 collision shape at (-0.5,-7), body origin, physics, animation frames and pipe transport coordinates are unchanged. This is a concrete Mario scene property, not a Project Settings/import change.


## Ordered stages and completion - 2026-11-04

User approved a stage-list completion lifecycle without physical triggers, plus explicit Warp destinations that skip completion fanfare but retain the level intro. Game's exported initial_level becomes Stages, currently [1-1]; programmatic initial_level remains a single-stage compatibility alias. Added finish transition: 12 hidden frames, replacement allowed, no card. NORMAL/WARP modes use the existing level transition for destination intros. No Project Settings, bindings, imports, timer countdown or audio configuration changed.


## Small Mario visible death presentation - 2026-11-04

User approved adding the concrete Dead state and supplied mario-dead.png, without a gameplay trigger. Mario.death_state now points to StateMachine/Dead. State defaults: Hold Frames=16, Launch Velocity=-240 px/s, Death Gravity=562.5 px/s squared, Maximum Fall Speed=240 px/s. Static death sprite, stop-animation-on-enter, controls/input/frame callbacks disabled, physics enabled. The existing (0,-7) sprite baseline, collision shape, normal movement coefficients, jingle/life/progress policies and pit trigger are unchanged. No Project Settings/Input Map or existing asset import parameters changed; Godot generated the new PNG's import sidecar.

## Level timer scene properties (2026-11-04)

Approved timer implementation adds BaseLevel.Timer Enabled (default true); TestLevel sets it false. Starting Time remains the single load-time value source. Disabled timers hide HUD digits but retain TIME. TIME UP is a coordinator definition with a 147-frame hold and existing quick transition phases. No Project Settings, Input Map or import settings changed.

## Climbing scene configuration (2026-11-04)

Approved fixed flagpole adds a 2x11 marker to entity palettes, maps flagpole in BaseLevel and existing level overrides, and gives Mario a Climb state/animation plus Motion/Climbing. Default component values: up 52.5 px/s, down 119.765625 px/s, side offset 7 px, side cooldown 24 ticks. Solid base is a normal 16x16 StaticBody2D using the palette block texture. No Project Settings, input bindings or existing import semantics changed.

## Climb capture refinement (2026-11-04)

Within the requested flagpole attachment fix, BaseClimbable Detection changes collision_layer 0 to 128 (layer 8) and monitorable false to true for player-driven area queries; its mask stays 1. The shaft remains non-solid. Attachment Tolerance changes from an 8-pixel feet-distance test to a 2-pixel half-width shaft band tested against Mario's collision envelope and actual swept motion. These are scene/script properties, not Project Settings or Input Map changes.

## Flagpole ending configuration (2026-11-05)

Approved level-ending implementation assigns 1-1 Ending Presentation to FlagpoleEnding, matching main/(196,2), and adds independent EndingEndpoint at (3272,208). The presentation references smb_flagpole.wav and smb_stage_clear.wav through non-looping runtime copies, with post-delay 126 ticks. finish retains its 12-tick minimum and adds a 12-tick outro for the requested title-return transition. The camera gains a runtime owner-scoped lock; authored Follow Enabled is unchanged. New supplied sound assets were imported with defaults; no existing import semantics, Project Settings or bindings changed.

## Skid audio removal and ending hold ordering (2026-11-05)

Removed the Slide scene's smb-skid.mp3 reference and the shared mix entry (+2.5 dB); other sound gains and the source/import files remain unchanged. Ending Post Delay Frames stays 126; only its runtime start changes to after score/fireworks and music completion, ensuring the requested visible pause before the existing finish transition. No Project Settings or bindings changed.

## Ending sound gain trims (2026-11-05)

At the user's request, sound_effect_mix.tres adds per-stream flagpole=-2 dB and stage_clear=-3 dB (previously no entry/0 dB trim). With the unchanged -3 dB master, effective playback gains are -5 dB and -6 dB. Both presentation playback and runtime copies use this shared mix. No Project Settings, source recordings, imports, timing or other stream gains changed.

## Flagpole upper grab geometry (2026-11-05)

Within the requested top-grab fix, Flagpole overrides ClimbTop from local (24,24) to (24,8). Its detection rectangle grows from (32,152) centered at (24,88) to (32,164) centered at (24,82), covering the full ball tile. Motion/Climbing exposes Capture Probe Offset Y=-8 for flagpole side contact; generic climbables retain their body-envelope default. Marker footprint, art, solid base, player collider and jump/movement settings are unchanged. No Project Settings, bindings or imports changed.

## Retained falling gravity - 2026-11-05

Authorized after reviewing the reference's gravity lifetime: JumpAction adds an editable entrance_falling_gravity default of 562.5 px/s� ($28 at nominal 60 Hz). New players and committed transport arrivals initialize this value; successful jumps select 1575/1350/2025 from the existing speed-profile table and retain it across landing. Passive Move falls apply that selection through a temporary priority-250 modifier. Grounded MotionValues.base_gravity remains 1575; jump speeds, existing gravity arrays, weight, terminal speed, Project Settings, Input Map and imports are unchanged.


## 2026-11-06 - Test Level timer

Restored Test Level timer_enabled=false, the previously requested sandbox setting. Playable stages retain their own timer settings.

## 2026-11-06 - Question-block editor add-on

Added project setting editor_plugins/enabled. Previously the section was absent. The enabled list now contains res://addons/question_block_contents/plugin.cfg so the editor exposes the painted-cell contents dropdown. The user explicitly approved enabling the add-on. This is an editor-only setting.

## 2026-11-06 - Remove the question-block editor add-on

With explicit user approval, removed the Question Block Contents entry from editor_plugins/enabled. It was the only entry, so the section is absent again.

## 2026-11-06 - Enable the Block Rewards preview add-on

With explicit user approval, added res://addons/block_rewards/plugin.cfg to editor_plugins/enabled. The setting was previously absent. This enables the editor-only reward preview on EntityLayout.

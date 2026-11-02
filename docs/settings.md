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


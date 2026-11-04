# Persistent UI and static HUD

Game owns scenes/ui/ui.tscn as a sibling of LevelContainer. UI is a screen-space Control, visually routed into Game/SharedShadow alongside the world and player. It shares one shadow composite while remaining independent of entity gameplay suspension. Game supplies a fixed screen-space canvas. UI stays at identity; only world/player render transforms receive the final camera matrix, with additional proxy interpolation disabled. The UI root also disables interpolation. Level replacement (including death restart) leaves UI alive. Keep future transition screens inside this persistent Game shell rather than replacing the root scene. See [shared composition](level-shadow.md) for render routing and constraints.

UI/ScreenContainer owns TransitionScreen, a host for definition-selected Control presentation scenes. HUD is its later sibling and draws above the loading splash card. Quick black transitions explicitly hide HUD and the player, covering theme swaps. Startup and respawn show quick black, then the splash with HUD, then quick black again before gameplay. The player normally draws above HUD outside transitions. See [transitions](transitions.md).

## 8x8 layout

HUD is a full-viewport, mouse-ignoring Control. Labels and the coin use integer multiples of eight logical pixels at 1x scale. The 256x240 viewport provides 32 columns by 30 rows; world layouts stay on their separate 16x16 grid. Placement is authored in the scene, not dynamically packed by containers. Keep offsets on multiples of eight when editing; automatic editor snapping/enforcement is not added. Texture filtering is nearest on the HUD, inherited by its children. No global rendering settings changed.

| Element | Cell (column, row) | Static content |
| --- | --- | --- |
| PlayerName | 3, 2 | MARIO |
| Score | 2, 3 | leading blank then 000000 |
| Coin | 11, 3 | animated 8x8 atlas frame |
| CoinMultiplier | 12, 3 | multiplication sign |
| CoinCount | 13, 3 | 00 |
| WorldHeading | 18, 2 | WORLD |
| WorldValue | 19, 3 | 1-1 |
| TimeHeading | 25, 2 | TIME |
| TimeValue | 26, 3 | 400 |

All values are placeholders. There are no score/timer/coin/lives subscriptions, polling or GameHandler writes. They do not describe actual stage/session progress. No opaque HUD backing strip is used; it renders directly over the background.

## Font and coin assets

assets/ui/fonts/hud.fnt is a BMFont definition referencing the existing assets/ui/alphabet.png (192x16, 24 columns, two rows). It maps digits, uppercase letters, hyphen, multiplication sign and space with an 8px advance. The source PNG remains a Texture2D; its import type/settings are unchanged. The HUD Theme supplies this font at native size 8 with white text and no outline/shadow. Other punctuation or font variants can be mapped when needed; this is not a general Unicode font.

The default coin uses assets/Overworld (Palette 1)/ui/hud-coin.png, a 24x8 atlas. SpriteFrames uses three AtlasTexture regions, retaining the atlas untouched. Its animation sequence is bright, medium, dark, medium, with relative durations 3,1,1,1 at 7.5 steps/second: 24,8,8,8 ticks at 60Hz, total 0.8 seconds. This reproduces the supplied colors using frames instead of NES palette writes. Runtime playback samples the [shared cosmetic clock](animation-clock.md), matching active question blocks and ready for future world coins. Native autoplay is disabled; synchronization selects the phase and continues through death/world suspension.

HUD coin artwork follows the active area's AreaTheme texture_overrides. Underground maps the canonical Overworld 24x8 coin atlas to its Underground 24x8 atlas. HUD owns a private SpriteFrames/AtlasTexture copy and changes only the atlas references, preserving 8x8 regions, 24/8/8/8 durations and the shared clock phase. Missing overrides fall back to Overworld. Area entry and level replacement refresh the mapping; theme changes during covered transport occur while HUD is hidden. BaseEntity remapping is not used for UI. Text/value binding and additional themed HUD assets remain deferred.

## Reference and verification

The disassembly's TopStatusBarLine, StatusBarData and world-number placement supply the tile-based layout. ColorRotatePalette repeats its bright color three times, then medium/dark/medium, updated every eighth frame; our atlas animation adapts that cadence. The implementation uses normal Godot UI and bitmap text rather than PPU/name-table writes. See the [reference](https://gist.github.com/1wErt3r/4048722).

hud_test checks exact 8px font advances and grid positions, mouse pass-through, coin durations/playback, static values despite session changes, camera/area/level independence and transition layering. Rendered gameplay and black-screen previews are saved under .godot/validation and inspected separately. Global transition presentation is covered separately by transition_test. Live value updates, themed HUD variants and title/game-over screens remain future work.

## Black transition background

Quick transitions hide HUD explicitly; they do not depend on drawing a rectangle above it. The Cover node has been removed. World, player and HUD are hidden, leaving the existing viewport background visible. During the loading splash, the level-intro presentation and HUD draw above it. Transitions do not override the background color. This conceals future themed HUD swaps. See the [original-versus-Godot comparison](transitions.md#black-screen-original-and-godot-implementation) for rendering, timing and lifecycle differences.

TitleScreen is a persistent screen-space Control under ScreenContainer, separate from TransitionScreen. It uses the existing white HUD Theme for 1 PLAYER GAME and the supplied 8x8 cursor resolved through the title background area theme. alphabet-alt is reserved for future copyright text. GameHandler owns creating/hiding/disposing the menu and transitioning into gameplay; see [title flow](title-screen.md).

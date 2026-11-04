# Area themes

A level contains BaseLevelArea scenes under Areas. Each area owns Layouts (DecorationLayout, GroundLayout, EntityLayout), WorldObjects, Arrival, and Camera2D. All layouts retain identity local transforms and the shared 16x16 square grid. Moving the area moves its content together. Players remain level-owned and retain their own appearance.

## Current selection

- 1-1/Areas/MainArea uses assets/themes/overworld.tres.
- 1-1/Areas/LowerArea uses assets/themes/underground.tres.

Select an area and assign its Theme resource in the Inspector before running. The tool script applies its TileSets in the editor and at startup. BaseLevel generates entities only when their area loads and assigns the area's visual_theme and saved progress before the entity enters the tree. Theme selection is a startup/authoring contract; hot-swapping already spawned entities is not implemented.

AreaTheme groups terrain, decoration, and entity-marker TileSets, explicit source-texture-to-replacement mappings. These are artwork selections, not palette shaders. Existing sprites and entity scenes remain shared. Missing texture mappings preserve the source texture; missing optional TileSet assignments preserve the layer's assigned TileSet.

## Supplied Underground art and fallback

Underground texture_overrides maps 21 supplied entity/terrain/UI PNG counterparts under assets/palettes/underground: ground, solid block, both bricks, all four question-block frames (including used), and all ten pipe sections, plus the HUD coin atlas, title cursor and title card. Both upright and sideways pipe entities use the replacements, as do terrain pipe tiles. All 15 decoration counterparts now use assets/tileset/underground/decorations.tres: three bush pieces, six hill pieces and six cloud pieces. The theme assigns this TileSet directly, with matching source IDs 0..14, atlas coordinates and alternative IDs; existing painted decoration cells select the Underground artwork automatically. Mario remains independent of the area theme. Mario is not assigned the area's visual theme.

Underground terrain and marker TileSets are under assets/tileset/underground/. They preserve source IDs, atlas coordinates, alternative IDs, entity_id custom data, and collision definitions from the Overworld counterparts. Thus an area's painted cells do not change when selecting the matching theme. Marker textures preview themed bricks and question blocks; Underground-specific 32x32 pipe previews preserve whole-pipe painting. Rebuild both themes' previews with scripts/build_pipe_marker.gd after changing pipe artwork. Existing terrain IDs 0-10 are unchanged; source 11 exposes the matching solid block in both themes with square collision. No painted cells were added or moved.

## Adding artwork

1. Add the matching sprite under the target theme folder, preserving dimensions, alignment, and transparency.
2. For entity art, add a texture mapping to the AreaTheme resource using the original texture's full res:// path as its key and the replacement Texture2D as its value.
3. For terrain/decorations/markers, update the corresponding theme TileSet atlas texture without changing logical tile IDs or collision definitions. Assign that TileSet to the theme.
4. Check both area themes together before replacing more artwork.

BaseEntity resolves its child Sprite2D textures and BaseState's static sprite textures through visual_theme. Texture keys in entity animation libraries are remapped on private copies before the FSM starts, preserving shared source animations and other areas. Unmapped animation frames remain unchanged. No per-frame palette polling is needed.

## Current stage migration

Main-area content stays at its original world positions. LowerArea currently sits at (896,240) after a user move; its camera is local (128,120), world (1024,360), and its arrival marker is local (32,48), world (928,288). Lower cells were converted from level coordinates to area-local coordinates with no world-position or tile-ID changes. MainArea's camera stays enabled and LowerArea's stays disabled. Theme selection does not change backgrounds or shader tuning. Area music is deferred; see the [backlog](backlog.md).

## Verification

area_theme_test checks all 21 texture mappings and dimensions, all 12 terrain sources and retained collisions, both pipe entity variants, marker previews, Underground question animation and used art, all 15 themed decoration sources and retained tile IDs, themed brick bounce, source-resource isolation, and descendant shutdown. Migration validation compares every saved painted cell's world coordinate and identifiers before/after. Both areas were rendered and visually inspected. Theme resources configure appearance; pipe travel is coordinated separately by BaseLevel.

## Editing nested areas safely

BaseLevel and 1-1 persist Editable Children for MainArea; 1-1 also persists it for LowerArea. These flags are required for per-level nested layout and camera overrides to survive editor saving. Expand Areas -> MainArea/LowerArea -> Layouts directly. The area-theme regression saves and reloads the level to verify painted bytes and camera enabled states survive. If an external repair changes the scene file, reload it in the editor before saving an older in-memory copy.

At runtime, inactive areas retain their theme/configuration metadata but free their Layouts and world instances. Theme application runs again when the runtime is recreated; saved cell data and logical block state are restored. The local editor still shows both full layouts. See [area lifecycle](areas.md).

The persistent HUD listens for active-area changes and resolves its canonical Overworld coin atlas through the same AreaTheme texture mapping. It updates private AtlasTexture resources without restarting synchronized playback. Missing theme art falls back to the canonical atlas. See [UI](ui.md).

TitleScreen also resolves its canonical start cursor through the active background area's theme. Underground supplies the mapped cursor; missing art falls back to Overworld. BaseLevelArea emits area_theme_changed after applying a newly selected theme, allowing title artwork to refresh without per-frame polling. Level/area binding and exit disconnects prevent stale subscriptions. Menu text remains the white HUD font.

## Palette asset folders

Themed artwork lives under assets/palettes/overworld and assets/palettes/underground, retaining decorations, interactibles, tileset and ui subfolders where present. Future themes should follow assets/palettes/<theme>. Display names remain Overworld/Underground. Shared TileSet resources remain under assets/tileset and AreaTheme selectors under assets/themes. All canonical texture-override keys and values use the new paths; fonts retain relative atlas filenames within their ui folder. Adding artwork alone still does not create a theme mapping or a font binding.

Underground.title_accent_font selects its own ui/alphabet-alt.fnt for the title copyright. The font uses the supplied Underground atlas; white HUD/menu/top-score text remains unchanged. Missing/null font assignments still fall back to Overworld.

# Area themes

A level contains BaseLevelArea scenes under Areas. Each area owns Layouts (DecorationLayout, GroundLayout, EntityLayout), WorldObjects, Arrival, and Camera2D. All layouts retain identity local transforms and the shared 16x16 square grid. Moving the area moves its content together. Players remain level-owned and retain their own appearance.

## Current selection

- TestLevel/Areas/MainArea uses assets/themes/overworld.tres.
- TestLevel/Areas/LowerArea uses assets/themes/underground.tres.

Select an area and assign its Theme resource in the Inspector before running. The tool script applies its TileSets in the editor and at startup. BaseLevel generates entities from every area's markers and assigns the area's visual_theme before the entity enters the tree. Theme selection is a startup/authoring contract; hot-swapping already spawned entities is not implemented.

AreaTheme groups terrain, decoration, and entity-marker TileSets plus explicit source-texture-to-replacement mappings. These are artwork selections, not palette shaders. Existing sprites and entity scenes remain shared. Missing texture mappings preserve the source texture; missing optional TileSet assignments preserve the layer's assigned TileSet.

## Supplied Underground art and fallback

Underground currently replaces ground, brick, and alternate brick with the supplied PNGs under assets/Underground (Palette 2). Pipes, question-block animation/used art, and decorations retain Overworld artwork until replacements are provided. Mario is not assigned the area's visual theme.

Underground terrain and marker TileSets are under assets/tileset/underground/. They preserve source IDs, atlas coordinates, alternative IDs, entity_id custom data, and collision definitions from the Overworld counterparts. Thus an area's painted cells do not change when selecting the matching theme. Marker textures also preview the correct brick palette in the editor.

## Adding artwork

1. Add the matching sprite under the target theme folder, preserving dimensions, alignment, and transparency.
2. For entity art, add a texture mapping to the AreaTheme resource using the original texture's full res:// path as its key and the replacement Texture2D as its value.
3. For terrain/decorations/markers, update the corresponding theme TileSet atlas texture without changing logical tile IDs or collision definitions. Assign that TileSet to the theme.
4. Check both area themes together before replacing more artwork.

BaseEntity resolves its child Sprite2D textures and BaseState's static sprite textures through visual_theme. Texture keys in entity animation libraries are remapped on private copies before the FSM starts, preserving shared source animations and other areas. Unmapped animation frames remain unchanged. No per-frame palette polling is needed.

## Current stage migration

Main-area content stays at its original world positions. LowerArea currently sits at (896,240) after a user move; its camera is local (128,120), world (1024,360), and its arrival marker is local (32,48), world (928,288). Lower cells were converted from level coordinates to area-local coordinates with no world-position or tile-ID changes. MainArea's camera stays enabled and LowerArea's stays disabled. Area themes do not change music, backgrounds, or shader tuning. The later pipe milestone adds one-way arrival/camera transfer separately.

## Verification

area_theme_test checks independent terrain textures, retained collisions, missing-art fallback, themed brick spawning and bounce recovery, source-resource isolation, and descendant shutdown. Migration validation compares every saved painted cell's world coordinate and identifiers before/after. Both areas were rendered and visually inspected. Theme resources configure appearance; pipe travel is coordinated separately by BaseLevel.

## Editing nested areas safely

BaseLevel and TestLevel persist Editable Children for MainArea; TestLevel also persists it for LowerArea. These flags are required for per-level nested layout and camera overrides to survive editor saving. Expand Areas -> MainArea/LowerArea -> Layouts directly. The area-theme regression saves and reloads the level to verify painted bytes and camera enabled states survive. If an external repair changes the scene file, reload it in the editor before saving an older in-memory copy.

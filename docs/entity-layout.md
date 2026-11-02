# Painting level entities

Open TestLevel and select Areas/MainArea/Layouts/EntityLayout, then paint the brick tile from its TileMap palette. Erase a marker to remove that entity from the next run. Save the level and press F5. Markers are visible in the editor; runtime hides this layer and creates actual entities under WorldObjects before spawning Mario.

For example, cell (4, 9) places an entity at top-left position (64, 144). TestLevel is a freely editable layout; the automated block test creates its own fixed four-cell fixture. Each BaseLevelArea owns Layouts/DecorationLayout, Layouts/GroundLayout, and Layouts/EntityLayout. The Layouts tool script enforces a shared origin, zero rotation, unit scale, and 16-by-16 square TileSet cells in the editor and runtime. Independent layout transforms are reset; move the level root to relocate the stage. Position conversion still accounts for the level and WorldObjects transforms. Entity origins are the top-left of the marker cell.

The dedicated assets/tileset/entity_layout.tres TileSet has no physics layers. BaseLevel also disables collision/navigation on its EntityLayout. Each marker carries string custom data named entity_id; the brick marker uses `brick`. The level's Entity Scenes dictionary maps that ID to BrickBlock's PackedScene. To support another entity, add its marker/custom-data ID to the palette and map the ID to a scene inheriting BaseEntity. Collision, detection areas, presentation, and behavior belong to that scene. Non-solid decorations and vines do not need solid bodies.

BaseLevel.spawn_layout_entities() processes all BaseLevelArea children once before spawn_player(). Each generated entity receives its area theme before entering the tree. Repeated calls do not duplicate entities. Unmapped IDs and scenes that do not inherit BaseEntity report errors and are skipped. WorldObjects is inherited from BaseArea inside each area; do not add a second container with that name in a derived level. Generated entities join the level shadow and descendant shutdown automatically. Changing markers during play does not regenerate entities; streaming and activation-on-demand are not implemented.

The block regression covers count, duplicate prevention, marker collision/visibility, solid block contact, non-solid entity spawning, translated and negative cell coordinates, and shutdown.

The palette also includes Question block entity (source 1, entity_id question_block). TestLevel maps it to the animated QuestionBlock scene. See [question block](question-block.md) for timing and scene details.


## Planned: per-cell entity properties

A future custom editor tool will let us paint a question block, select its cell, and choose its contents from a dropdown. Configuration will belong to the level and be keyed by grid coordinate, while TileSet custom data continues identifying the entity type. The spawner will configure the generated entity before startup. This workflow is planned, not currently available; item spawning is also unimplemented. See the [per-cell editor decision](decisions.md#2026-11-02---planned-per-cell-entity-editor).

## Static pipes

Select Areas/MainArea/Layouts/GroundLayout and use the terrain TileSet sources Pipe top - left (1), Pipe top - right (2), Pipe body - left (3), and Pipe body - right (4). Paint the two top pieces side by side, then extend the two body pieces downward. Each 16x16 tile has full solid collision on the existing terrain physics layer. These tiles do not spawn entities or support pipe travel; they are appropriate for non-interactive pipes. Original ground remains source 0. No pipe examples were painted automatically.

## Alternate brick

EntityLayout source 2, Alternate brick entity, uses entity_id brick_alternate. TestLevel maps it to scenes/entities/blocks/brick/alternate_brick_block.tscn. This scene inherits BrickBlock and overrides only Sprite2D.texture with brick-alternate.png. Collision, hit acceptance, Active/Bouncing recovery, sound ownership, and shutdown remain inherited. Select Areas/MainArea/Layouts/EntityLayout and the alternate marker to paint it; no existing painted cells were changed.

Both areas have their own layers and WorldObjects; choose Areas/LowerArea/Layouts to paint Underground content. See [area themes](level-themes.md) for artwork fallback and matching tile IDs.

## Pipe entrance marker

EntityLayout source 3, Pipe entrance (2x2), uses entity_id pipe_entrance. Paint one stamp at the top-left cell; it previews and generates a complete 32x32 pipe. No separate body tiles are required. Stand centered on it and hold Down to travel to LowerArea's Arrival marker. Static pipe terrain remains separate. See [pipes](pipes.md) for configuration and limitations.

Pipe destinations can be overridden individually using the source area's Pipe Routes array: match the top-left painted Cell and select destination area/endpoint IDs. Unconfigured markers keep lower/arrival. See [named endpoints and per-cell routing](pipes.md#different-routes-for-painted-pipes); the visual cell-selection editor remains planned.

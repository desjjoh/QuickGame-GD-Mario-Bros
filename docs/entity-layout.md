# Painting level entities

Open TestLevel and select EntityLayout, then paint the brick tile from its TileMap palette. Erase a marker to remove that entity from the next run. Save the level and press F5. Markers are visible in the editor; runtime hides this layer and creates actual entities under WorldObjects before spawning Mario.

For example, cell (4, 9) places an entity at top-left position (64, 144). TestLevel is a freely editable layout; the automated block test creates its own fixed four-cell fixture. Keep layer/container rotation at zero and scale at one for the shared 16-by-16 world grid. Position conversion accounts for translated layers and containers. Entity origins are the top-left of the marker cell.

The dedicated assets/tileset/entity_layout.tres TileSet has no physics layers. BaseLevel also disables collision/navigation on its EntityLayout. Each marker carries string custom data named entity_id; the brick marker uses `brick`. The level's Entity Scenes dictionary maps that ID to BrickBlock's PackedScene. To support another entity, add its marker/custom-data ID to the palette and map the ID to a scene inheriting BaseEntity. Collision, detection areas, presentation, and behavior belong to that scene. Non-solid decorations and vines do not need solid bodies.

BaseLevel.spawn_layout_entities() runs once before spawn_player(). Repeated calls do not duplicate entities. Unmapped IDs and scenes that do not inherit BaseEntity report errors and are skipped. WorldObjects is inherited from BaseLevel; do not add a second container with that name in a derived level. Generated entities join the level shadow and descendant shutdown automatically. Changing markers during play does not regenerate entities; streaming and activation-on-demand are not implemented.

The block regression covers count, duplicate prevention, marker collision/visibility, solid block contact, non-solid entity spawning, translated and negative cell coordinates, and shutdown.

The palette also includes Question block entity (source 1, entity_id question_block). TestLevel maps it to the animated QuestionBlock scene. See [question block](question-block.md) for timing and scene details.


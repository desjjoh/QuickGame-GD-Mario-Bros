# Entity scene organization

## Implemented layout

Entity roots retain their scripts and inherited state machines. Structural groups organize related children without adding gameplay authorities:

- `Body`: the physics body, shapes, artwork that follows the body, and contact queries. Coins use a `Node2D` body group because collection is area-based.
- `Presentation`: visual helpers, synchronization, and scenery artwork. Pipe artwork keeps its four sprites inside this group.
- `Anchors`: named points such as castle doorway and climb endpoints.
- `Interactions`: climb detection that is independent of the flagpole's solid base.

Base scenes own shared groups. BaseBlock supplies Body and Presentation to ordinary, reward, and hidden block variants. BaseClimbable supplies Anchors, Interactions, and Presentation to Flagpole. BaseEnemy and BasePlayer retain their previously established groups. Mushroom already groups its physics, sprite, pickup, and block-hit receiver under Body. Spawners remain single placement markers; empty organizational nodes are unnecessary there.

Blocks bounce only their sprite; moving it under Body does not move the static collision shape. Animation paths resolve from the relocated AnimationPlayer's parent. Coin probes and climb queries resolve the actor through the new group parent, preserving collection and climbing behavior.

## Tile-based scenery

Castle replaces 21 static sprite tiles with one 16×16 TileMapLayer. Flagpole replaces its top, nine shaft tiles, and base with one 16×16 TileMapLayer. Both layers live at Presentation/Tiles. They contain artwork only: the flagpole's solid base and climb-detection shape retain their previous sizes and positions.

Moving flags and castle fireworks remain Sprite2D nodes. Their presentation code keeps advancing the same positions and frames. The flagpole capture top now refers to its tile grid at the same original Y coordinate.

BaseEntity duplicates tile sets and atlas sources before applying area texture overrides, keeping other instances' artwork unchanged. Activity geometry includes each tile layer's used-cell rectangle, so converting scenery to a grid does not remove its extent from camera activity checks.

## Verification on 2026-11-08

Thirteen focused regression scenes passed without engine errors or warnings: area_theme_test, climbing_test, coin_probe_test, entity_activity_test, fireworks_test, pipe_transfer_test, question_block_test, reward_brick_test, secret_coin_collection_test, area_streaming_test, climb_capture_test, flagpole_ending_test, and timed_coin_test.

A separate temporary audit compared all 32 converted tile cells with the original scene texture paths, atlas regions, and positions, then checked editor-state packing and save/reload for 11 affected entity scenes. These checks passed. No interactive visual playtest or full regression run was performed for this cleanup. Project settings, import settings, and Input Map bindings were unchanged.

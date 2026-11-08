# Enemy activation and cleanup audit

## Findings — 2026-11-08

Investigation only. No gameplay code, scene properties, or settings changed.

BaseLevelArea currently grows the camera rectangle by 64 pixels for activation and 96 pixels for deactivation/cleanup. EntitySpawner activates by its marker position, once per area load. A live SpawnableEntity is removed only once its complete activity rectangle no longer intersects the outer rectangle. Until that point it continues processing independently of the placement. The area uses the same region policy for resident entity sleeping and disposable actors, including power-ups.

At a fixed 256×240 camera view with top-left (0,0), a controlled Godot fixture measured wake rectangle (-64,-64,384,368) and outer rectangle (-96,-96,448,432). A Goomba marker at X=320 remained unspawned; X=319 spawned. A 16-pixel Goomba with sprite-left X=-111 remained alive, while X=-112 queued deletion. At the right edge, X=351 remained alive and X=352 queued deletion. The fixture completed without engine errors or warnings. Coordinates refer to the sprite's left edge, not body center.

## Original-game source and trace

[Disassembly](https://gist.github.com/1wErt3r/4048722): ProcessEnemyData/CheckRightBounds computes ScreenRight + 48 and rounds down to a 16-pixel column before testing ordinary enemy data. Depending on scroll alignment, this is 33–48 pixels beyond the last visible pixel (32–47 beyond the exclusive right edge). It is a forward enemy-data parser, not a symmetric rectangle around the camera.

OffscreenBoundsCheck uses nominal 72-pixel horizontal extensions and compares the enemy X anchor, not the full sprite bounds. The exact arithmetic carries matter: for ordinary Goomba/Koopa IDs, the left subtraction includes a borrow after the ID comparison, giving a 73-pixel extension. The right extension can differ by a pixel with carry/page state. Enemy-specific exceptions exist, including earlier left cleanup for Hammer Bros/Piranha Plants and right-side exemptions. This audit does not prescribe one universal threshold for all future enemy types or vertical cleanup.

A fresh Mesen trace used the existing isolated runner/reference ROM documented in [Super movement](super-mario-movement.md). [Script](reference/enemy-boundaries.lua) and [CSV](reference/enemy-boundaries.csv) retain the non-ROM evidence. Right+Run drives Mario; the injury timer is held at 255 via RAM to suppress contact damage. The original ROM remains unchanged. The trace spawned the first Goomba at world X=352 with the last visible right pixel at 304: +48 pixels. The last pre-frame sample before removal was enemy X=251 and screen-left X=324: -73 pixels. This is a bounded natural horizontal encounter trace, not a controlled pixel-by-pixel proof of every removal threshold. The run reaches the first pipe, so it does not qualify later groups or all enemy types.

## Goomba pairs

Our pair marker activates both actors together, with offsets 0 and +24, provided the outer region includes them. Changing only one member's individual activation would regress the previously corrected staggered-pair issue.

The reference HandleGroupEnemies instead places the first member at the current right screen edge when its group record is processed, then adds 24 pixels for each following member. A faithful activation pass must account for this separate group placement rule, not just substitute a smaller constant for every marker. Current pair positions/trigger mappings need comparison before implementation.

## Proposed next step — not implemented

Keep area lifecycle ownership and existing spawn limits/skipped-attempt rules. Separate enemy activation/removal policy from resident scenery hysteresis and power-up cleanup, so fidelity corrections do not alter unrelated entities. Use the reference forward activation threshold and anchor-based horizontal cleanup for current ordinary enemies, and verify group trigger/placement together. Discuss the concrete policy before implementing it. Vertical cleanup and future special enemy exceptions remain separate verification items.


## Implementation — 2026-11-08

This section supersedes the proposed status above. At the user's request, BaseLevelArea now supplies a separate enemy spawn region using floor((last_right_pixel + 48) / 16) * 16 as its inclusive cutoff. Its left edge is the visible screen left, retaining initialization of authored markers already inside the view. The existing vertical activation envelope remains unchanged. Generic enemy-category EntitySpawner placements and legacy EnemySpawner placements use this region; scenery and power-ups retain their existing rectangles.

A grouped enemy marker represents the intended first member position. EntitySpawner converts that to a reference data trigger 48 pixels farther right. Once eligible, it creates all available members in the same activation call, starting at the last visible right pixel, with the authored +24-pixel pair offset. No stage markers were moved. Existing cap failures remain skipped for the area load; failed members are not queued for later spawning.

BaseLevelArea handles live BaseEnemy activity separately from resident hysteresis. Enemy X is the moving body's global X minus its existing +8-pixel origin offset, floored to the reference pixel anchor. Ordinary Goomba/Koopa cleanup removes anchors strictly left of screen-left minus 73, or at/beyond last-right-pixel plus 72 (plus one when the preceding page subtraction preserves carry). Live enemies do not sleep between activation and cleanup. Existing vertical bounds cleanup, death/transition suspension, tree pause, category ownership, and capacity release remain intact. Future enemy-specific exceptions are not implemented by this ordinary-enemy policy.

Affected paths: scenes/levels/areas/base_area.gd, scenes/entities/spawners/entity_spawner.gd, scenes/entities/spawners/enemy_spawner.gd, tests/enemy_boundary_test.*, and tests/enemy_spawn_test.gd. Architecture/testing guides describe the current policy.

Verification: eight focused scenes passed without engine errors or warnings: enemy_boundary_test, enemy_spawn_test, entity_activity_test, nested_entity_activity_test, shell_interaction_test, spawn_return_test, one_up_test, and super_mushroom_test. Coverage includes column rounding, activation equality, both horizontal cleanup edges and carry regimes, actual disposal, group spacing and movement, cap failures without deferred spawning, reload behavior, and unchanged power-up paths. Initial checks exposed script type-inference errors; those were corrected before successful reruns. No new Mesen trace, interactive playtest, or full regression suite was performed; implementation uses the source and trace documented above. No project/Input Map/import settings or authored stage positions changed.


## Pair vertical-origin correction — 2026-11-08

The user's rendered test exposed an airborne entry after the boundary change. A new controlled Mesen fixture moves Mario and the screen edges past the first pipe so the original enemy parser can process the first pair. It records creation at enemy X=816/840, stored Y=184, with screen edges 561/816. The [trace](reference/group-entry.csv), [script](reference/group-entry.lua), and [sprite rows](reference/group-oam.txt) retain the evidence. At frame 342 the first Goomba's OAM rows are Y=184 (tile 252, blank), Y=192 (tile 113), and Y=200 (tile 115). The original sprite pattern bank's tile 252 was confirmed blank. The stored Y is therefore eight pixels above the visible 16-pixel Goomba artwork, not its visible top. This fixture injects RAM/camera state and is not a natural uninterrupted playthrough.

The previous group conversion accounted for X but omitted this vertical-origin difference. EntitySpawner now adds eight pixels to the group actor's local Y, retaining authored marker positions. Existing first-member markers at Y=184 produce visible sprite top Y=192 and body center Y=200, with feet at the ground's Y=208. Ordinary single placement behavior is unchanged in this correction.

The horizontal creation point remains the last visible right pixel, matching the reference group routine. A first-pixel sliver at the screen edge is distinct from spawning an entire sprite inside the viewport. The second member remains 24 pixels farther right; both activate together.

Verification: enemy_boundary_test passes with explicit ground geometry and asserts the pair starts at body Y=200 and remains there over its first movement frames (within Godot's 0.1-pixel contact tolerance), instead of dropping eight pixels. Existing enemy_spawn_test and nested_entity_activity_test also passed. Initial strengthened checks exposed a missing floor in the boundary fixture and then the need for contact tolerance; these were corrected before the successful rerun. No full regression suite or interactive Godot visual playtest was performed. No settings, terrain, or stage marker positions changed.


## Offscreen pair placement — 2026-11-08

At the user's explicit request, pairs now activate together using the same offscreen marker cutoff as singles and retain their painted X positions. Removed the +48-pixel group trigger conversion, screen-edge relocation, and unused get_enemy_group_origin_x helper. Pair members retain +24-pixel spacing and the corrected +8-pixel vertical-origin conversion. This supersedes the horizontal group placement described above and deliberately differs from the NES group routine. Enemy cleanup, limits, skipped attempts, and scenery/power-up buffers are unchanged.

The boundary and stage-spawn regressions now assert that both members' complete bounds begin beyond the visible right edge, at the painted positions, and that they move together without a separate second-member activation. enemy_boundary_test, enemy_spawn_test, and nested_entity_activity_test passed without engine errors or warnings. No interactive visual playtest or full regression suite was performed.


## Ground-aligned 16×16 enemy grid and restored pair timing — 2026-11-08

The user clarified that the offscreen pair-placement change was the change to revert. Restored the +48-pixel group trigger and last-visible-right-pixel placement, retaining simultaneous members and 24-pixel spacing. This supersedes the preceding offscreen-placement section. No extra pair-only Y conversion remains.

EnemyLayout now uses 16×16 cells in all three themed TileSets; LevelLayouts enforces the same grid across layout layers. Marker texture origins are (0,0) for Goombas and (0,8) for the 16×32 Koopa artwork. Migrated all 11 authored 1-1 enemy cells from (x,y) to (x/2,(y+1)/2): horizontal world positions remain unchanged, while all marker Y positions increase eight pixels. Ground markers are now row 12 (world Y=192), and raised-platform markers row 4 (Y=64). Singles and groups therefore start with feet on support rather than settling an eight-pixel gap. The Green Koopa marker is cell (107,12), world (1712,192).

Verification: nine focused regression scenes passed without engine errors or warnings: area_theme_test, enemy_boundary_test, enemy_spawn_test, koopa_wake_test, koopa_walking_test, layout_grid_test, nested_entity_activity_test, title_backdrop_test, and scene_hierarchy_test. Updated fixtures to the new grid and grounded contact; the initial placement assertions treated exact floor contact as penetration and began rays inside the floor, so the assertions now distinguish contact from overlap. A separate temporary audit checked all 17 authored single/group-member footprints in 1-1: every foot position touches its ground/platform and every body is free of terrain penetration. No interactive visual playtest or full regression suite was performed. No project settings, Input Map, import options, or terrain changed. TileSet grid changes were explicitly requested by the user.

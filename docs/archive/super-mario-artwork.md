# Super Mario artwork inventory

Date: 2026-11-07. Inspection only; no animations, atlas resources, imports, scene properties, or image pixels were changed.

## Files and intended mapping

Source directory: `assets/player/mario (super)/`. All six PNG files are RGBA8, use binary alpha (0/255), and use the same three opaque colors: (107,109,0), (181,49,32), (230,156,33). Frames have a 16x32 canvas, arranged left-to-right on single-row sheets. Visual inspection confirms distinct movement poses. The initial left-to-right walk cycle is an authoring map, not proof of exact ROM frame ordering/timing.

| Action | File | Sheet dimensions | Frame regions (x,y,width,height) |
| --- | --- | --- | --- |
| Standing | mario-idle.png | 16x32 | (0,0,16,32) |
| Walking/running | mario-walk.png | 48x32 | (0,0,16,32), (16,0,16,32), (32,0,16,32) |
| Skidding | mario-slide.png | 16x32 | (0,0,16,32) |
| Jumping | mario-jump.png | 16x32 | (0,0,16,32) |
| Crouching / crouch jumping | mario-crouch.png | 16x32 | (0,0,16,32) |
| Climbing / flagpole grip | mario-climb.png | 32x32 | (0,0,16,32), (16,0,16,32) |

`slide` means the existing skid/braking pose, not a new sliding or crawling action. Idle/jump/skid artwork faces right, matching current Mario's horizontal flip convention. Climb uses side-facing grip poses; which pose/facing the flagpole presentation selects must be verified in-engine. Crouch has transparent upper space within the full-height canvas, so a short collision profile does not require cropping its texture or moving the actor.

## Exact per-frame alpha bounds

Bounds are local to each 16x32 frame, written (left,top)-(right,bottom), with right/bottom exclusive. Padding is left/top/right/bottom. These are artwork bounds, not collision boxes.

| File / frame | Nontransparent bounds | Padding L/T/R/B | Nontransparent pixels |
| --- | --- | --- | --- |
| mario-climb.png / 0 | (2,2)-(16,32) | 2/2/0/0 | 278 |
| mario-climb.png / 1 | (2,2)-(16,29) | 2/2/0/3 | 291 |
| mario-crouch.png / 0 | (0,10)-(16,32) | 0/10/0/0 | 275 |
| mario-idle.png / 0 | (0,0)-(16,32) | 0/0/0/0 | 372 |
| mario-jump.png / 0 | (0,0)-(16,32) | 0/0/0/0 | 371 |
| mario-slide.png / 0 | (0,0)-(16,32) | 0/0/0/0 | 354 |
| mario-walk.png / 0 | (0,2)-(16,32) | 0/2/0/0 | 310 |
| mario-walk.png / 1 | (1,1)-(15,32) | 1/1/1/0 | 287 |
| mario-walk.png / 2 | (0,0)-(16,32) | 0/0/0/0 | 353 |

There are nine distinct frames; none are exact RGBA duplicates of another supplied Super frame. Idle, jump, skid, crouch, all three walk frames, and climb frame 0 reach the canvas bottom. Climb frame 1 ends at row 28 inclusive, leaving three transparent rows. Preserve that difference: independently bottom-aligning/trimming every frame would change the climbing motion. Crouch begins at row 10 and occupies 22 rows; this is compatible with a shorter contact box inside the art and does not imply a 22-pixel terrain body.

## Feet and alignment contract

Current Small Mario uses 16x16 art with centered Sprite2D at Body-local (0,-7). Its idle/jump/skid frames reach local image row 15, so the Sprite2D rectangle ends at Body Y=+1 and the last opaque row starts at Body Y=0. The terrain shape still ends at Body Y=0. This is an existing sprite/collision alignment convention, not permission to move the body.

For centered 16x32 Super frames, Sprite2D position (0,-15) preserves that existing rectangle bottom at +1 and the last opaque row at Body Y=0. Position (0,-16) instead places the continuous rectangle bottom at 0 and shifts art one pixel upward relative to current Small. Do not silently mix the two conventions. Before wiring, compare against the reference OAM scanline convention and choose/document the form presentation offset; no scene offset has been changed by this inventory.

Use the same selected canvas anchor for idle/walk/skid/jump/crouch. Preserve per-frame transparent padding, particularly the raised climb foot. Texture/animation frame changes must not reposition Mario's Body. Mirroring and pipe occlusion need to consume actual frame dimensions; reusing Small's (0,-7) offset with a 32-pixel texture would lower Super by eight pixels.

## Existing animation integration

Current walk.tres selects three 16x16 AtlasTexture resources from Small's walking sheet. Current climb.tres selects two Small climb AtlasTextures. Both animate Sprite2D:texture; the actor uses walking cadence and existing Climb presentation logic. Super can supply equivalent 16x32 atlas regions while reusing the movement/cadence logic. This is an integration proposal, not new resource creation. Do not use the three-frame-wide walking sheet as one uncropped standing texture.

Jump/idle/skid currently enter through state sprite_texture properties. The future form configuration must resolve those through Mario's selected form so returning from Jump, Climb, PipeEnter, or a level presentation cannot restore Small textures accidentally. Crouch-jump can use the supplied crouch pose; a normal walk-off uses the reference's separate Falling artwork logic documented in super-mario-research.md, rather than inventing another fall sheet.

## Transformation and other asset gaps

- No transformation sheet or intermediate-growth pose is supplied. Reference growth uses small, intermediate, and big poses; Small and big standing endpoints exist, but the distinct intermediate growth artwork is still needed for that presentation.
- No Super swimming poses are supplied. The reference shrink sequence reuses big/small swimming graphics. Current Small assets also do not contain a swimming set, so faithful shrinking needs those particular poses even before swimming gameplay exists.
- No separate Super death sheet is required for the planned damage behavior: Super shrinks on ordinary damage, and existing Small death artwork remains available for the death path. Pit/death presentation policy still needs verification; do not invent a new death animation solely because a file is absent.
- Fire throwing poses and Fire palette art are not supplied here; those belong to the later Fire Mario pass.
- No separate crouch-jump, run, or fall image is required merely because those names are absent. Existing poses and the reference action rules supply their presentation; actual selection/timing remains to be wired and checked.

The basic standing/movement/crouch/climb sandbox pass has the necessary poses. Growth/shrink presentation is not artwork-complete. No frames were synthesized, resized, recolored, or substituted during inspection.

## Themes and remaining verification

Only one Super set was found in the supplied player directory. No additional Mario/player PNG set was found under assets/palettes, and current theme texture-overrides contain no Mario mapping. Current Small Mario also uses shared player art. Therefore theme-specific Super variants are not established assets or a new requirement; check the reference palette expectations before requesting variants. Fire form colors are a separate later concern.

Verification performed: visually inspected all six original PNGs; decoded dimensions and every RGBA frame with a standard-library PNG reader; measured alpha bounds/padding and confirmed the shared colors and distinct frames; cross-checked Small PNG dimensions/bounds using System.Drawing; read current scene offsets, AtlasTexture resources, and walk/climb animation tracks. The machine-readable analysis output is an ignored diagnostic under .godot/validation, not a shipped asset.

Not performed: Godot import/preview, animation wiring, rendered player alignment, pipe/flagpole playback, ROM pixel comparison, or Mesen frame ordering. No gameplay tests were run because this pass changes documentation only. Super import files were not present during inspection; the editor may generate them later using established defaults. No import settings were selected or changed here.

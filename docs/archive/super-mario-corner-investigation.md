# Super Mario corner overlap investigation

## 2026-11-08 — investigation only

The reported overlap also occurs on a normal jump; an enemy rebound is not required.

Super Mario retains a short physical support body. `scripts/player/mario_terrain.gd` adds a standing head probe at (0, -28) and upper side probes at (-6, -24) and (5, -24). The head check casts vertically at the final horizontal position, using the previous and current vertical positions. It does not sweep the actual diagonal path. When horizontal movement places the start of that ray inside a block, the normal underside-entry check can miss it. Upper side probes also leave four pixels above their sample height.

### Controlled reproduction

A temporary headless diagnostic placed a 16×16 brick at (128, 128), started standing Super Mario to its left, and stepped the existing Jump state with rightward movement near the apex. A sweep of 24 starting heights, each observed for 14 physics ticks, recorded 30 samples with the center head probe strictly inside the brick. The run exited without reported engine errors or warnings. This is a seeded-state reproduction using production movement, not a recording of a complete player-controlled jump. An earlier faster-rising sweep did not reproduce center-head penetration.

### Proposed correction

Handle upper-body corner entry through the existing terrain-probe path, distinguishing underside contact (bonk and downward response) from side contact (horizontal correction). Cover diagonal entry and an already-overlapping probe rather than relying only on a vertical ray starting outside solid terrain. Preserve the intended reference corner escape and uncrouching push-out behavior; do not replace this with a blanket full-height physics body.

Before implementation is called verified, add focused regressions for both approach directions, shallow apex entry, ordinary underside bonks, permitted corner escape, and crouched movement. No production code, scene configuration, or project settings changed during this investigation. No new Mesen comparison was performed.

## Implemented correction and focused audit

The standing head sweep now uses actual upward movement rather than requiring the next vertical velocity to remain nonpositive. If the vertical ray has no underside hit, a current-position point query checks whether diagonal movement placed the head inside terrain. For occupied rectangular or convex terrain shapes, the existing terrain resolver obtains the shape underside from the physics server and applies the shared bonk response. This avoids casting through another block to recover the surface. The short support body and side-probe spacing are unchanged.

Confirmed and fixed two cases: diagonal corner entry and a last upward movement tick whose next velocity has already become downward. The new `super_mario_corner_test` steps production Jump movement across 24 starting heights in both directions, with shallow-apex and high-gravity cases (96 seeded trajectories, 14 ticks each). It also checks a two-pixel-thick upper obstruction with post-gravity downward velocity. Before the fix, the temporary shallow-apex sweep recorded 30 penetrated center-head samples; after the fix it recorded none.

Audit results:

- Upper-side and uncrouching behavior: existing Super movement checks pass, including fixed-order push-out. No side-probe geometry changes were needed for the reproduced issue.
- Duplicate contacts/rewards: existing bonk-contact and question/reward-block checks pass, including hidden-block repeated-delivery and one-coin assertions. No additional reward ownership or delivery path was introduced.
- Hidden blocks: their separate rising underside sweep remains unchanged. Existing side/top pass-through, reveal, shared response, used-block landing, standing Super, and crouched ceiling checks pass.
- Ordinary corner escape and landing/re-jump checks pass.

Seven focused scenes passed without engine errors or warnings: super_mario_corner_test, super_mario_movement_test, bonk_contact_test, corner_correction_test, question_block_test, reward_brick_test, and landing_rejump_test. The corner scene passed again after adding the thin-obstruction assertions. Formatter and diff whitespace checks passed. No full regression suite, new Mesen capture, or interactive visual playtest was performed.

Reference basis: `HeadChk` reads current probe occupancy, checks upward speed and tile-relative height, while `SideCheckLoop` / `ImpedePlayerMove` handle side probes independently. This correction retains Godot's continuous underside sweep and adds occupancy recovery; it does not claim byte-for-byte NES collision behavior or complete parity for every corner position. The recovery assumes the project's axis-aligned rectangular terrain (including convex tile representations); arbitrary sloped/custom shapes are not qualified.

## Follow-up — brief upper-side artwork overlap

The user clarified that the two screenshots show a brief overlap followed by the expected bonk, rather than Mario remaining trapped. This distinction supersedes the initial interpretation that the screenshots established an unresolved persistent corner-penetration bug.

Fresh controlled captures in Mesen and Godot each exercised eight cases: approaches from both directions at four initial feet heights (160, 164, 168, 172), 24 observed ticks per case. Both used a single solid 16×16 obstacle at (128,128), standing Super, held direction/Jump, initial horizontal speed approximately 2.5 pixels/tick and vertical speed -1 pixel/tick. Mesen uses an isolated block-buffer fixture and seeded RAM state; Godot steps the existing Jump state against a real brick. Neither capture is an input-only stage playthrough. Files are `reference/corner-side-reference.lua/.csv` and `reference/corner-side-godot.gd/.tscn/.csv`.

| Case group | Mesen upper-side probe overlap samples | Godot upper-side probe overlap samples |
| --- | --- | --- |
| Approaching right, initial feet 160/164/168 | 1 per case | 1 per case |
| Approaching left, initial feet 160/164/168 | 2 per case | 2 per case |
| Shallow apex approach, initial feet 172, either direction | 0 | 0 |

The matching upper-side counts demonstrate that even a side probe can remain within the obstacle briefly after the one-pixel correction; artwork extends beyond the probes too. In the apex cases the NES center head enters the tile, vertical speed reverses to +1 pixel/tick on tick 3, and the head clears after two occupied samples. This is a normal bonk with temporary overlap, not indefinite upward travel through the block. Godot instead snaps the head to the underside on tick 3, so those center-head samples are not occupied.

This does not establish exact trajectory parity. NES integer coordinates, fractional integration, speed caps, and the existing Godot ceiling response differ; the fixtures are comparable collision cases rather than golden full-motion traces. No screenshot pixel comparison was performed, and the exact player-input sequence from the supplied screenshots was not reconstructed.

Conclusion: the clarified transient visual overlap is consistent with the reference's separate center-head and side probes. Do not add a full-height rectangle or move side probes merely to eliminate it. No further gameplay changes were made in this follow-up. The previous underside-snap fix is more restrictive than the NES's velocity-only reversal; changing that response should be discussed separately, with regressions that distinguish intended temporary overlap from failure to bonk.

The Godot audit completed without reported engine errors or warnings and the Mesen runner exited successfully. Corrected the temporary fixture's initial held-button history and vertical-force initialization before preserving final reference results. No regression-suite rerun was needed for this investigation-only follow-up.

## Replacement decision — natural clearance after standing bonks

At the user's explicit request, removed the standing head's underside snap. This supersedes the positional correction described above: the sweep/current-occupancy checks now invoke the bonk effects and reverse vertical speed to +60 px/s, corresponding to NYSpd's +1 pixel per 60Hz tick. Current-position overlap is allowed while Mario descends naturally. The shape-bound recovery helper is no longer needed and has been removed. Side probes, short-body ceiling handling, and hidden-block crossings remain unchanged. This is the standing generic ceiling response; interactive block-specific velocity responses, including future shattering, still need their own reference behavior.

Regression assertions now require downward velocity during temporary occupied-head samples, natural clearance by the end of each trajectory, and unchanged position plus reversed velocity for the thin-obstruction contact. The normal Super brick-bonk check asserts the reaction rather than requiring a positional snap; hidden-block checks retain their separate behavior.

Verification: five focused scenes passed without engine errors or warnings (super_mario_corner_test, super_mario_movement_test, bonk_contact_test, corner_correction_test, question_block_test). Formatter and whitespace checks passed. No full suite or interactive playtest was performed; no settings changed.

## Follow-up — immediate sideways stop and material-specific bonks

The user clarified that the disputed momentum is horizontal: in Mesen, partial corner entry can immediately act as a side hit. The earlier eight-case conclusion was insufficient to establish full collision-response parity, and the blanket +60 px/s standing response should not be described as matching every reference bonk.

### New controlled evidence

`reference/bonk-material-reference.lua/.csv` records 24 cases (three materials × two directions × four initial feet heights), each for 24 ticks. Approach starts closer to the corner: Body-equivalent X126 from the left or X146 from the right. Materials are solid $61, question $c0, and ordinary breakable $51. The selected cell is initialized once per case, then preserved so a successful block hit is not overwritten each frame; other fixture cells remain cleared to isolate contact. Block object state and bounce timer are reset between cases. This corrects an important limitation of the original static-cell fixture, which reinserted the tile every tick and therefore was unsuitable for post-hit interactive-block behavior.

`reference/bonk-side-godot.gd/.tscn/.csv` captures the corresponding eight approach cases against the current Godot brick. The current brick bounces for Super until breaking is implemented, so it is not a material-matched golden replay of all three NES materials.

On the first contact at initial feet 160/164/168, NES horizontal integer speed is cleared when the upper side probe reaches the obstacle; end-frame CSV contains a small fractional/reacceleration residue rather than the original ~150 px/s travel speed. Godot also clears horizontal speed on the first tick in all six corresponding cases. At initial feet 172, the side probes are below the obstacle and both retain horizontal movement. Thus sideways stopping exists in both implementations and depends on which probe actually enters the tile; it should not be added unconditionally to every head bonk.

The captures also confirm two material differences and a missing gate:

- Solid underside (`NYSpd`) sets vertical speed +1 pixel/tick.
- Question-block bump (`BumpBlock`) sets vertical speed zero. The current Godot blanket +60 px/s override is therefore wrong for that reference response.
- Super brick shatter (`BrickShatter`) sets vertical speed -2 pixels/tick. It is still a future block-specific reaction; later shatter trajectory parity is not established here.
- `HeadChk` only fires an upward head reaction when the NES player origin's low Y nibble is at least 4. At initial feet 164, after one upward tick feet are 163 and origin low nibble is 3: Mesen keeps rising while the side contact stops horizontal travel. Godot currently reverses downward on the same tick. The earlier occupancy fallback omitted this position gate and changes the sequence of side-versus-head responses.

### Proposed correction, not implemented in this follow-up

Respect the reference's head-position gate; keep side collision as an independent subsequent check. Distinguish a solid underside from an accepted block bounce and, later, shatter, so the caller does not overwrite the block-specific vertical response. Preserve immediate horizontal stopping when the relevant side probe is obstructed, rather than stopping X for every bonk or adding a full-height physics rectangle.

No new production changes were made during this investigation. The closer-corner Godot capture completed without reported errors or warnings, and Mesen exited successfully. These remain seeded RAM/state fixtures, not an input-only recreation of the user's exact encounter or a pixel comparison. The user's particular sideways mismatch has not been independently reproduced: the audited side-contact cases already stop in Godot. The confirmed missing Y gate and incorrect blanket material response are concrete differences to correct before claiming full parity. No full regression suite was run.

## Implemented — standing head-position gate and distinct bounce response

Implemented the proposed standing-head correction at the user's request. MarioTerrain derives the NES origin's low Y nibble from the integer feet coordinate modulo 16 (subtracting 32 does not change that phase). Phases 0–3 skip the standing head reaction while retaining independent side checks; phases 4–15 permit it. Upward movement is still determined from actual displacement and the pre-move rising flag.

Accepted block hits now set vertical speed to zero after shared bonk effects; rejected hits/solid ceiling contact use +60 px/s. No positional snap was reintroduced. This replaces the blanket +60 override described earlier. The existing block acceptance result selects the current reaction; no shatter response or new player state was introduced. Short-body/crouched and hidden-block crossing paths remain unchanged.

Expanded super_mario_corner_test checks both directions at adjacent phases 3/4 against fresh question blocks: phase 3 keeps upward speed and awards nothing; phase 4 stops vertical speed and grants exactly one coin. Both stop sideways movement, nudge one pixel away, and preserve Y position. Repeated non-rising contact must not grant another coin. Existing seeded trajectory checks now allow rising overlap during the reference's excluded head phases and still require eventual clearance. Super movement asserts zero vertical speed on its accepted normal block bounce. Thin solid upper contact retains its +60 px/s check.

Verification: all six selected scenes passed without engine errors or warnings: super_mario_corner_test, super_mario_movement_test, bonk_contact_test, corner_correction_test, question_block_test, reward_brick_test. Formatter and whitespace checks passed. No new Mesen capture, input-only visual playtest, or full suite was performed for this implementation; prior archived reference captures supply the comparison basis.

## Block entity versus ground differential audit

The user reported that ground geometry behaves correctly and the remaining clipping is specific to bricks/question blocks. A clean four-way comparison isolates the difference:

| Fixture | Collision | Hit acceptance | Standing response |
| --- | --- | --- | --- |
| Ground tile | 16×16 TileMap convex rectangle, layer 1 | None | +60 px/s |
| Ordinary brick | 16×16 StaticBody rectangle, layer 1 | Accepted bounce | 0 px/s |
| Fresh question block | Same StaticBody shape/layer | Accepted bounce | 0 px/s |
| Inert brick control | Unchanged brick body; BonkAction disabled in audit only | Disabled | +60 px/s |

Each fixture runs eight seeded corner trajectories (two directions × four initial heights), 24 steps each. The same empty court and floor are used; interactive blocks are recreated before every case so question-block depletion cannot contaminate subsequent cases. Actual head/upper-side point queries record TileMapLayer for ground and StaticBody2D for blocks. Capture scripts/scenes/CSVs are `reference/block-ground-{ground,brick,question,inert}.*`.

Results: all 192 recorded position/velocity samples of the inert brick match ground exactly at CSV precision (six decimal places). All 192 fresh-question samples match the bouncing brick. The collision body type alone therefore does not explain the remaining mismatch in this test matrix. Both ground and blocks stop X on the same first side-contact tick; head-only contact retains X in both. The first divergence is accepted-hit velocity zero instead of solid-contact +60. A block bounce additionally animates only Sprite2D.position; the solid shape remains at its grid location. No body motion, collision-layer change, or shape disable occurs in ordinary brick/question hit states.

### Correction to prior verification evidence

The earlier corner diagnostic and super_mario_corner_test inherited sandbox floating ground near their seed positions. A zero-velocity move_and_slide used to refresh contact flags could depenetrate the actor before observation (for example, requested feet Y160 became approximately Y173.84). Those seeded Godot captures cannot be used as reliable proof of the intended starting geometry, and their broad parity conclusions are superseded by this clean comparison. Historical files are retained. The current regression now clears the sandbox terrain and builds only its required floor; it passed after that fixture correction. This was a test-fixture correction, not a production collision change.

Temporary full-jump sweeps, including the actual 1-1 block row/upper question-block geometry with manually stepped movement, did not establish the exact deeply embedded frame from the screenshot. Those runs are not normal F5 input-only reproductions. The current finding isolates the differential response path but does not establish that setting Y speed to zero is itself incorrect: the NES BumpBlock also zeros Y speed. Further work must examine accepted-hit timing/presentation and the exact encounter before changing the verified reference response. Do not treat the isolated differential as permission to force all blocks to behave like solid ground.

Verification: four clean audit scenes completed without reported engine errors/warnings; corrected super_mario_corner_test passed without errors/warnings. No new production edits or settings changes were made during this audit. No full suite was run.

## Reproduced root cause — CanvasLayer point-query filtering

The user confirmed a used coin block clips without any bounce presentation. A controlled CanvasLayer test reproduces the missed contact independently of presentation. Game.tscn's root is a CanvasLayer; earlier standalone-level fixtures omitted this parent. PhysicsPointQueryParameters2D.canvas_instance_id defaults to zero. Under the game's canvas, these point queries still find TileMapLayer ground but do not find block StaticBody2D bodies. Both MarioTerrain's occupied-head fallback and its side checks omit that field. The world-coin path already selects the player's canvas explicitly; these terrain queries do not.

Evidence:

- Eight CanvasLayer approach cases against ground retain their normal side stop. The corresponding brick/question cases retain ±150 px/s and upward movement while probes are inside their physical rectangles; default point-query collider lists are empty. Preserved `reference/canvas-ground.csv`, `canvas-brick.csv`, and `canvas-question.csv`.
- `reference/canvas-used.gd/.tscn/.csv` forces a fresh question block to Inactive in every case. Default point queries find the block in zero samples; the identical queries with the CanvasLayer instance ID find it in 72 samples. No collision/body/presentation change is needed to demonstrate the missed detection.
- `reference/stage-canvas-used.gd/.tscn/.csv` loads actual 1-1 beneath a CanvasLayer, starts Super on the first block row, sets question_block_22_5 at (352,80) to Inactive, and executes normal movement-state jumps from varied row positions in both directions. Of 810 recorded samples, 22 have the standing center-head probe inside that used block, with bounce_running false. For example, case 3 tick 6 reaches Body (353.530396,112.220474) with VX150 and VY-234.375; the next tick reaches feet Y110.074860 and only then gets the short body's VY3.75 ceiling response. Head Y82.074860 is nearly fourteen pixels inside the tile's underside Y96. This reproduces the deep overlap/late bonk, not just artwork beyond a probe.

The short physical body eventually catches the block, while the upper point probes miss it. This explains why ground works and standalone tests pass. The previous hit-response comparison remains accurate for its default-canvas fixtures, but it did not expose this hierarchy-dependent failure. The earlier position/velocity edits are not evidence that the root issue was repaired.

No production changes were made during this investigation. A prospective correction must query block bodies on the player's canvas while preserving the working default-canvas TileMap results; simply switching every point query to the player's canvas without retaining ground coverage is not yet qualified. Add the CanvasLayer hierarchy to regression coverage before implementing that correction. The reproduction uses actual stage geometry and production movement but manually seeds row starting positions and disables level/area physics for controlled stepping; it is not a screenshot-matched interactive F5 recording. The renderer/shader was not needed to produce the failure. All diagnostic runs completed without reported errors/warnings; no full suite was run.

## Implemented — canvas-aware terrain point queries

At the user's request, MarioTerrain now shares a point-query helper between occupied-head detection and standing side probes. It queries canvas zero first for TileMap bodies and additionally queries the player's CanvasLayer when present for entity bodies. Standalone actors retain the single default-canvas query. Collision geometry, head gates, bounce/solid velocities, and presentation behavior are unchanged by this fix.

Added canvas_terrain_test: 48 seeded movement trajectories cover both canvas hierarchies, both directions, ground/brick/active-question/used-question fixtures, and three corner phases/heights. Checks include correct horizontal stopping, head-only X retention, zero-speed accepted bounce versus +60 solid reversal, no snap, phase-3 head exclusion, natural clearance, no used-block bounce, and exactly one coin per accepted question-block bounce. A temporary counterfactual disabling the additional canvas lookup fails at the CanvasLayer brick side-contact assertion, confirming the regression detects the reproduced defect. Production code was not reverted for that check.

Replayed the same 810-sample actual-1-1 fixture from the previous reproduction with the fix. Maximum occupied-head depth falls from 13.92514 pixels to 3.498276 pixels; the deeply embedded late-short-body bonk is eliminated in that controlled sweep. Ten samples retain shallow natural overlap, which the reference probe model allows. Preserved post-fix data in reference/stage-canvas-used-fixed.csv; replay uses stage-canvas-used.gd with its output filename changed to retain the original baseline. This remains a controlled physics capture, not an interactive rendered F5 comparison.

An initial new-test parse failure (an inferred bool from Variant iteration) was corrected before final verification. Historical pre-fix/counterfactual failures are distinct from final passing runs.

Final verification: canvas_terrain_test passed after the type correction and again after adding natural-clearance assertions. Existing bonk_contact_test, corner_correction_test, super_mario_corner_test, and super_mario_movement_test also passed with the production fix. All five scenes passed without engine errors/warnings in their final runs; the initial combined runner failed solely because of the corrected new-test parse error. Formatter and whitespace checks passed. No full suite, project-settings changes, or interactive playtest was performed.

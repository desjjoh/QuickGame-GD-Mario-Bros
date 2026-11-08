# Selectable level shadow styles

## Implemented on 2026-11-08

Open scenes/main/game.tscn, select Game, then load a preset into Presentation → Shadow Style:

| Resource | Appearance |
| --- | --- |
| assets/shadows/soft.tres | Existing Gaussian drop shadow, offset (2,2), radius 4.5 |
| assets/shadows/crisp.tres | Nearest-sampled hard offset shadow, no blur pass |
| assets/shadows/outer_blur.tres | Gaussian silhouette blur with offset (0,0), surrounding the sharp artwork |
| Empty field | No shadow material; both capture updates disabled |

Soft is the authored Game default; levels do not expose style overrides. All presets retain black at 0.38 opacity. These are presentation resources, not positional audio or gameplay settings. Game's existing Shadow Shader Enabled switch remains a master override. One Game selection applies to the title and all stages. Standalone F6 reads the saved Game style and master toggle through PackedScene state without instantiating a second game. Selection is applied during F5/F6 rendering; no custom editor preview tool was added.

ShadowStyle owns a composite ShaderMaterial and horizontal Shader plus uses_blur. Presets can therefore supply alternate shaders without branching on style names. The shared interface uses foreground_texture, horizontal_texture, shadow_offset, blur_radius, shadow_color, and shadow_enabled. The compositor duplicates the selected material for runtime parameters and never edits the saved preset. Resource replacement and clearing are picked up during render synchronization. Keep offset plus blur extent within the existing 12-pixel capture padding.

## Shared standalone and Game rendering

Previously F5 used SharedShadowComposer and excluded decorations, while standalone F6 used the old root CanvasGroup shader and included them. Both now use SharedShadowComposer. Game retains its persistent compositor; a standalone BaseLevel creates Systems/ShadowComposer and an empty screen root. Render-only routing places that compositor outside the level it captures. Scene parents, ownership, physics transforms, and gameplay queries stay unchanged. BaseLevel no longer has a saved root ShaderMaterial; its nested CanvasGroup is disabled while captured. The historical level_shadow.gdshader remains available for reference but is no longer the active F6 path.

DecorationLayout renders behind the composite with the camera transform, receives foreground shadows, and never contributes silhouettes. This applies when styles are enabled or cleared, and while changing areas. Players retain the existing foreground/pipe routing. Crisp disables the intermediate blur viewport; clearing a style disables both viewport updates and clears the final shadow material. Buffers remain allocated for restoration.

## Koopa pixel investigation

Rendered comparisons of the two Koopa walking poses at integer positions preserve opaque foreground pixels across Soft, Crisp, and Outer Blur versus no effect, within a 0.01 channel tolerance. Captured Koopa images were inspected. This does not establish that the user's intermittent stray pixel is fixed.

An exploratory half-pixel-position comparison found edge-pixel differences between direct and compositor rendering. Initial comparisons also needed the cosmetic walk synchronizer disabled so they compared the same pose. The half-pixel discrepancy remains unresolved and is outside the passing integer-position regression. No sprite artwork, import filters, interpolation settings, or global pixel-snap settings were changed to conceal it. A natural moving-Koopa reproduction remains necessary to connect it to the reported artifact.

## Verification

Headless focused checks cover shadow style selection, shared composition, HUD scrolling, pipe transfer, flagpole draw order, and enemy boundaries. Rendered shadow_style_test passed on default D3D12 Forward+ and OpenGL Compatibility, checking both Game and standalone paths, sharp foreground, visible decorations without cast shadows, Crisp offset, centered Outer Blur, and null bypass/restoration. The existing shared_shadow_test passed rendered on D3D12, including Gaussian/reference agreement, camera fractions, HUD/player ordering, and same-frame composition. koopa_shadow_test passed rendered on D3D12 at integer placements for both walking poses and all three presets. Exploratory half-pixel failures are described above rather than counted as passes.

No full regression suite or natural interactive Koopa playthrough was performed. No project settings, input bindings, import settings, or audio properties changed. The user approved the Shadow Style resource setup and requested Outer Blur in addition to Soft/Crisp/null.


## Game-wide ownership correction — 2026-11-08

The user clarified that style selection must be game-wide rather than level-specific. Moved the exported Shadow Style field and Soft resource reference from BaseLevel to Game. SharedShadowComposer retains the Game selection across bind_level calls and supports runtime Game Inspector changes. BaseLevel no longer exposes the field. Standalone F6 reads the authored game.tscn property state, including the existing master toggle, rather than introducing a preview-specific authoring setting or another game session.

Verification after this correction: shadow_style_test and shared_shadow_test passed headless; shadow_style_test and integer-position koopa_shadow_test passed rendered on D3D12. The style test covers blank Game startup and Outer Blur retention through level replacement; standalone startup matches the saved Game selection. The earlier half-pixel artifact limitation remains unresolved.


## 2026-11-08 — Smoother, bolder Outer Blur

Outer Blur now uses dedicated horizontal/composite shaders with 25 samples per axis, a wider Gaussian distribution, radius 6 (previously 4.5), and opacity 0.60 (previously 0.45). The foreground remains nearest-filtered; only the glow mask is blurred. Soft/Crisp shader resources are unchanged. The effect still renders at the game's canvas resolution, so it retains some pixel character rather than becoming a full-resolution postprocess. The wider kernel increases blur sampling cost for this style; no performance benchmark was run.

shadow_style_test and shared_shadow_test passed headlessly without engine errors/warnings. shadow_style_test also passed with the OpenGL Compatibility renderer and no reported errors/warnings. No project/import settings changed.


## 2026-11-08 — Native window rendering and all-style refinement

With approved canvas_items/keep/fractional settings, final composition now rasterizes at the aspect-fitted window resolution instead of enlarging a completed low-resolution glow. Outer Blur radius is narrowed from 6 to 4; opacity reduced from 0.60 to 0.45 after user visual feedback. Soft uses 25 taps per axis with the original Gaussian spread retained. Crisp interpolates only the offset alpha silhouette to smooth its border; visible foreground sampling remains nearest and the offset shape remains hard. No additional blur pass is enabled for Crisp.

Added window_render_test with render-resolution/aspect-fit assertions and all-style checks at 768×720, 1024×960, and 1000×700. It checks opaque foreground preservation, decoration visibility/exclusion from casting, and shadow presence. Initial test assumptions about ViewportTexture.get_size and a single subpixel edge sample were corrected: get_image reports actual fitted render dimensions, and edge checks sample the shadow band. Rendered OpenGL Compatibility checks passed without reported errors/warnings; both existing focused shadow scenes passed headlessly. Larger images were visually inspected for sharp foreground and smooth shadow edges. Other renderers/performance were not benchmarked.

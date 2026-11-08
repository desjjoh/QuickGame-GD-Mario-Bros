# Bounded area background colours

## Implemented on 2026-11-08

The user requested a drawable background within area boundaries and selected a solid colour per area. BaseLevelArea exposes Background → Background Color and owns a Background ColorRect. Alpha defaults to zero, preserving all existing stage appearances until a colour is chosen. This is independent of AreaTheme; changing theme or music does not replace the selected colour.

The fill's horizontal extent is the camera's World Left/World Right interval. Its vertical extent is the camera's center Y plus/minus half the logical visible height, divided by camera zoom. Global bounds are converted into area-local position, so LowerArea's translated scene does not shift or duplicate the fill. Editor refresh uses the configured logical viewport height and updates while editing; runtime uses the active viewport height. This implementation supports the existing centered, unrotated area-camera convention.

SharedShadowComposer routes the active fill behind decorations, then renders shadows/foreground above them. Background and decorations do not contribute to the silhouette mask. The fill can receive shadows, including with partial alpha; clearing its alpha exposes the existing viewport background. This works with Game/F5 and standalone/F6, including a null game-wide shadow style. Scene parents, transforms, collision, and input ownership stay unchanged. ColorRect ignores mouse input.

Existing area runtime-template capture/load/unload includes Background. The exported colour persists on the area; synchronization reapplies it to a recreated fill. The compositor restores valid old render parents when changing background references or exiting. No duplicate gameplay area, global clear-colour change, or project setting is needed.

Affected paths: scenes/levels/areas/base_area.{gd,tscn}, scenes/ui/shared_shadow_composer.gd, tests/area_background_test.*, and current configuration/architecture/testing guides.

Verification: area_streaming_test, scene_hierarchy_test, shadow_style_test, and area_background_test passed headless without engine errors or warnings. The new background test passed rendered on D3D12, including colour clipping at horizontal boundaries, foreground order, shadow reception without backdrop shadow casting, transparent fallback, and transfer to the offset underground area. Standalone colour coverage was added and rerun as recorded in the history entry. No full regression suite or interactive editor-authoring playthrough was performed. No existing area colours, terrain, project settings, imports, or audio properties changed.


## Game-owned black fallback — 2026-11-08

The user reverted the subsequent global black-clear-colour setting and requested a black background behind Game instead. Game/Backdrop is a viewport-anchored black ColorRect, ignores input, and stays outside shadow capture. Transparent area fills reveal it during Game/F5; standalone F6 retains the engine clear colour where no area colour is supplied. Rendered area_background_test asserts black outside the bounded area, while shadow-style and shared-shadow fixtures explicitly provide a contrasting area colour for their shadow assertions. All three rendered tests passed on D3D12 without errors or warnings.

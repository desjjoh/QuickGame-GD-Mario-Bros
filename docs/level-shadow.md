# Combined level shadow

BaseLevel is a CanvasGroup, still compatible with Node2D. Its shader reads the group's combined transparent rendering and draws an offset silhouette behind it. Terrain, players, enemies, interactable objects, and decorations beneath the level root contribute together. Existing node paths, spawning, and physics remain unchanged.

Select the level root and expand Material > Shader Parameters to adjust `shadow_offset` (logical viewport pixels), `blur_radius`, `shadow_color` (including opacity), or `shadow_enabled`. Defaults are a down-right (2, 2) offset, a 4.5-pixel blur radius, and black at 38% opacity in both the saved BaseLevel material and shader defaults. The group's fit and clear margins are 12 pixels; keep both greater than the blur radius plus the largest absolute offset to avoid clipping. The shader uses a weighted 13-by-13 alpha kernel and draws the sharp foreground over it, making a soft drop shadow. This costs more texture samples than the original crisp trial; performance on target hardware still needs profiling.

Keep an opaque receiving backdrop outside the CanvasGroup. TestLevel supplies the bounded background described below; the viewport clear color remains visible outside that rectangle. A full-screen opaque image inside the group turns the combined silhouette into a rectangle. Future CanvasLayer content or independent viewports do not automatically join the group; place contributing decorations and objects in its normal CanvasItem hierarchy. Screen-reading shaders and clipping children need separate evaluation with CanvasGroup.

Implementation: `scenes/levels/base/base_level.tscn`, `base_level.gd`, and `level_shadow.gdshader`. Uses Godot's documented CanvasGroup backbuffer contract, including premultiplied color handling: https://docs.godotengine.org/en/stable/classes/class_canvasgroup.html

Verified a rendered preview with the project's Forward+ D3D12 renderer. This is a visual trial inspired by the requested style, not a reconstruction of Mario Maker's renderer.

## Test-level background

TestLevel/Background is a rectangular Polygon2D covering the current area (0,0) to (768,240), colored #a2baff. Its Z index is -1, placing it behind the Z=0 CanvasGroup composite rather than contributing to its halo silhouette. The project-wide clear color is unchanged. This is a bounded scene background, not the future area/background management system.

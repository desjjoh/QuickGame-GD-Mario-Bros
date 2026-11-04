# Shared world, HUD and player shadow

Game is a persistent CanvasLayer at layer 0. Game/SharedShadow is a screen-space Node2D compositor that captures world content, screen-fixed UI and the player into one transparent foreground image. It blurs that image's alpha horizontally, then vertically, and composites the resulting shadow behind the original sharp foreground. Opaque HUD, terrain and player pixels cover the shadow; transparent gaps can show it.

## Two-pass rendering

SharedShadowComposer creates two internal SubViewports: ShadowForeground captures the contributors, and ShadowHorizontal stores the horizontally blurred alpha in its red channel. The final shader reads that mask vertically and combines it with the untouched foreground. The weighted Gaussian is separable: 13 horizontal plus 13 vertical samples replace the previous 13x13 (169-sample) blur. The final pass also reads the foreground once. This reduces sampling work, but the extra render targets and passes have their own CPU/GPU cost; it is not a claim of a 6.5x frame-rate improvement.

Buffers use the logical viewport size plus a 12px transparent border on each side: 280x264 for the current 256x240 view, independent of the 3x window scale. The border retains silhouettes just outside the camera that can cast a shadow into view. Both buffers clear each frame; render-texture dependencies supply the current frame without a history buffer or delayed foreground. There is no per-frame texture readback in gameplay. Only the blur textures use linear sampling; the final foreground uses nearest filtering.

## Render ownership and lifecycle

RenderingServer CanvasItem parents/draw indices route world, UI and Players into the foreground viewport. Their scene parents, ownership, input viewports, node paths and physics transforms stay unchanged. No body is reparented and no duplicate sprites or gameplay nodes are created. The capture viewports use isolated 2D worlds, disable 3D and GUI input, and contain only render helpers. They do not become gameplay areas.

Foreground order remains world, UI/transition content, player. During pipe travel the level moves Players before Areas in its logical order; the compositor returns Players to the level's render parent below terrain. Exit/cancellation restores foreground routing. Camera interpolation is applied only to world/player render roots; UI remains at identity in gameplay coordinates. Capture padding is an internal render translation shared by all contributors. The current stationary level/Players containers remain the supported configuration.

BaseLevel retains its authored material and CanvasGroup for standalone/editor previews, which still use the original single-pass shader. Game reads the material's parameters, clears the runtime level material and disables its nested CanvasGroup so no second effect runs. Game/SharedShadow uses the new composite material; source shader parameters are copied on binding or change without mutating the saved resource. Replacing a level preserves the compositor and UI. Game owns and frees the internal buffers; the pre-draw callback disconnects on exit.

## Settings and boundaries

Author shadow_offset=(2,2), blur_radius=4.5, shadow_color=black at 0.38 alpha and shadow_enabled=true on the saved level-root material. Keep offset plus blur radius within the 12px border. Inspect SharedShadow.material for the active composite shader; the runtime level material is intentionally null. Buffer textures and intermediate materials are runtime-owned.

Current contributors stay at Z=0 in one foreground canvas. The existing viewport clear color receives the shadow and is unchanged. Independent CanvasLayers, viewports, screen-reading effects, alternate Z bands and opaque backdrop nodes need explicit integration; a backdrop placed in the foreground capture becomes part of its alpha mask. This effect does not reconstruct Mario Maker's renderer.

## Diagnostic toggle

Select Game in scenes/main/game.tscn and uncheck Presentation / Shadow Shader Enabled before F5, or change it in the Remote Inspector. The default is true and the choice persists through level changes. Disabled routes contributors directly to the screen, clears the final material and stops updates on both buffers. It retains the allocated buffers for fast restoration. Re-enabling restores the two-pass effect with the active level's parameters. Normal camera/UI routing and pipe order continue in either mode.

No VSync, physics, interpolation, Project Settings or import parameters change. Use F5 through Game to test the optimized path; standalone level F6 retains the reference shader. See [frame pacing](frame-pacing.md) for the diagnostic legacy/two-pass/off comparison.

## Verification

shared_shadow_test renders overlapping world, HUD and player shapes, checks foreground order and a HUD-cast shadow, compares nonzero-radius blur against a CPU evaluation of the original 2D Gaussian, and checks same-frame moving/color-changing foreground output. It also covers camera fractions, pipe routing, buffer dimensions, disabled updates/startup, restoration and level replacement. hud_scroll_test compares foreground glyph pixels while camera speed changes. Headless checks do not establish image correctness; current rendered results and performance limits are recorded in [verification](verification.md).

# Shared world, HUD and player shadow

Game is a persistent CanvasLayer at layer 0; Game/SharedShadow is its screen-space CanvasGroup compositor. During normal play it combines world content, screen-fixed UI and the player into one alpha mask, then runs the existing soft-shadow shader once. Foreground order is world, HUD/transition content, player. The shadow is composited behind the complete foreground, so it cannot darken opaque HUD, terrain or player pixels. Transparent gaps can show the shadow naturally.

## Render ownership and lifecycle

SharedShadowComposer configures rendering-server CanvasItem parents/draw indices only. LevelContainer, UI and the current level's Players keep their scene parents, ownership, node paths and physics transforms. No physics body is reparented and no mirror player sprite is created. World rendering is routed first, UI second, Players last. Render parents change only on level binding or switching pipe draw mode; player-container rendering transforms are refreshed before drawing.

BaseLevel retains its CanvasGroup and authored shadow material for standalone/editor previews. When Game binds a level, its material is assigned to SharedShadow, and the runtime level's own group mode is disabled through RenderingServer with its material cleared. This avoids a second shadow/composite. Binding rejects stale/shutdown levels; the pre-draw callback disconnects on compositor exit. Replacing a level binds the new source material without recreating UI.

UI is a Control fixed at identity in Game's screen-space canvas. It never moves to cancel camera motion. Before drawing, the final interpolated viewport camera matrix is applied only to the world and foreground-player render roots. Those two proxy RIDs disable additional interpolation individually; descendant bodies retain native interpolation and physics transforms remain unchanged. UI and SharedShadow disable interpolation locally. Current stages use stationary level/Players containers; moving/scaling those containers dynamically needs additional qualification.

During pipe travel, the level still moves Players before Areas in its logical draw order. The compositor detects that mode and returns Players to the level's render parent at its authored local transform, below world artwork and UI. On exit/cancel it restores foreground routing. Players remain Z=0 throughout, and existing transport cleanup remains authoritative.

## Settings and boundaries

Author per-level shadow parameters on the level root's saved Material: shadow_offset=(2,2) logical pixels, blur_radius=4.5, shadow_color=black at 0.38 alpha, shadow_enabled=true. In a running Game inspect SharedShadow.material instead; the runtime level's material is intentionally null. The persistent group's fit/clear margins are 12 pixels, matching the standalone base scene. Keep margins greater than blur radius plus maximum offset.

All contributing visuals stay at Z=0 in one canvas. Independent CanvasLayers, viewports, clipping children, screen-reading effects and alternate Z bands require explicit integration; they do not automatically join this mask. Receiving opaque backdrops should stay at Z=-1 outside the composite. An opaque panel inside the foreground mask becomes part of its silhouette; this also applies to full-screen transition panels. No new background painting or shader tuning was introduced here.

The shader blurs only combined alpha with a weighted 13x13 kernel and preserves sharp foreground pixels using Godot's premultiplied backbuffer convention. Target-device performance still needs profiling. This is a project rendering design, not a reconstruction of Mario Maker's renderer. See [CanvasGroup documentation](https://docs.godotengine.org/en/stable/classes/class_canvasgroup.html).

## Verification

shared_shadow_test renders deliberately overlapping world, HUD and player shapes. Pixel assertions check player-over-HUD ordering, undarkened opaque foreground and an actual HUD-cast shadow. hud_scroll_test samples every foreground glyph pixel across physics-driven acceleration/braking, excluding the animated coin; world art remains visible through transparent gaps. Rendered checks at several frame-rate caps exercise the separate physics/render cadences. Fractional camera motion keeps HUD pixels fixed. The same test checks pipe-mode routing, unchanged logical player ownership and level replacement. hud_test renders actual gameplay and transition previews; pipe and camera regressions cover their existing behavior. Headless tests cannot establish image correctness, so the rendered overlap check is required for this contract.

## Diagnostic toggle on Game

Select Game in scenes/main/game.tscn and uncheck Presentation / Shadow Shader Enabled before F5 to compare frame pacing. It defaults true. The same property works on the running Game in the Remote Inspector. It applies to the persistent world/HUD/player composition, including title/transition UI, and remains selected across level replacement.

Disabled removes the shader material and disables the shared CanvasGroup compositor pass through RenderingServer; camera/UI routing and draw order still run normally. Merely clearing the material would leave CanvasGroup's default compositing work, so this bypass also removes that pass. Re-enabling restores the active level's authored material without changing shader parameters or shared resources. No VSync, interpolation, camera, Project Settings or import values change. This supports A/B testing; it does not establish the cause of reported frame drops.

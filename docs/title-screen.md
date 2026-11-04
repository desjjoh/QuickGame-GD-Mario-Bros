# Title screen and starting a game

GameHandler owns title creation and game-flow decisions. Normal F5 startup shows TitleScreen immediately with scenes/levels/test_level.tscn as its world background. It does not invoke TransitionCoordinator at boot. Existing background entities, including Mario and painted blocks, remain visible but gameplay-suspended; the background level's physics callback is disabled so title presentation does not run camera/death gameplay checks. The controller handler remains active for menu input. No demo/attract playback or inactivity timer exists.

## Scene and ownership

Persistent Game owns LevelContainer and screen-space UI. GameHandler creates scenes/ui/title/title_screen.tscn under UI/ScreenContainer and loads its exported background_level into LevelContainer through the existing immediate loading lifecycle. The title Control contains the 1 PLAYER GAME label, themed start-cursor sprite, TOP- six-digit score label and ©1985 NINTENDO copyright line. All use the 8x8 UI grid. Menu and top-score text use the existing white HUD font; copyright uses the Overworld alternate alphabet through alphabet-alt.fnt, including its supplied © glyph. No second-player option is introduced; TitleCard displays the supplied logo artwork. Existing HUD remains present with bound session values. Top score reads GameHandler.top_score initially and updates through session_value_changed; no automatic record promotion or disk persistence is implemented.

The menu emits start_requested; it does not directly replace levels or initialize session data. GameHandler's GameFlow is DETACHED, TITLE, STARTING, PLAYING or GAME_OVER. The active flow is available globally and flow_changed reports changes. Game.start_with_title defaults to true; initial_level remains the first gameplay target (1-1), rather than the title background. Direct gameplay fixtures explicitly use start_with_title=false. TestLevel's scene controls remain normal when run directly with F6; only GameHandler's title usage suspends its player.

## Starting and cleanup

1. Title samples ControllerHandler's Start edge while visible. GameHandler accepts it only in TITLE with no active transition.
2. Confirmation is consumed, flow becomes STARTING and the menu hides. Repeated/held requests cannot start another load.
3. The existing level transition hides gameplay/HUD and runs the first-level operation. The title background shuts down, previous session/progress is cleared, and 1-1 loads.
4. The current level intro and timed holds complete. The title UI is released and flow becomes PLAYING; the new Mario receives gameplay control.

There is no new black overlay or clear-color override. Transitions continue to use the existing viewport background. Entity and area lifecycle cleanup remains owned by their existing methods. Title Mario's suspension is not copied onto the new gameplay player.

Cancellation/failure restores a usable title through deferred recovery: cancellation may originate inside level tree removal, where adding/removing new children is unsafe. Recovery carries a weak reference to the expected Game and checks that Game still owns the STARTING flow. Detaching the Game invalidates recovery and clears title/level ownership; no menu is recreated over a closing game. This does not implement game over, pause or return-to-title gameplay UI.

## Input

The approved control-binding scope adds the start Input Map action: Enter, keypad Enter and gamepad Start/Menu (JOY_BUTTON_START, index 6, any device). ControllerHandler.start_action now defaults to start, and input_start_just_pressed supplies one-edge menu intent. Select stays unbound because there is no alternate option yet. Existing gameplay bindings are preserved.

Enter is already a primary binding, so consume_menu_confirmation suppresses that held primary intent until release. This prevents confirming the menu from immediately jumping after reveal, including direct-load testing. Release tracking continues while transition input is disabled, so a later fresh Jump is not blocked by an earlier Enter press. A gamepad Start press does not block an unrelated later Jump when primary was not held. Fresh gameplay input works normally after release.

## Reference and scope

The [SMB disassembly](https://gist.github.com/1wErt3r/4048722) separates TitleScreenMode from GameMode. GameMenuRoutine handles Start and selection, clears ordinary player input in NullJoypad, and eventually runs its demo routine when DemoTimer expires. Our flow keeps title-to-game ownership and the single-player cursor concept while deliberately omitting the demo and two-player selection. The modern persistent Game/UI and scene replacement are engine architecture choices, not emulated memory/PPU operations. Timing for entering 1-1 remains in the existing transition definitions.

## Verification

title_test checks immediate title with zero transitions, background/player suspension despite movement/jump input, the white HUD font and 8x8 cursor, Enter/keypad/controller bindings, keyboard and controller Start, repeat rejection, cancellation recovery, fresh session state, transitioned 1-1 entry, held-confirmation suppression, fresh Jump after release and Game teardown during Start. Rendered validation writes .godot/validation/title-screen.png. Hardware controller/speaker behavior and physical monitor pacing still need user playtesting; input events in the test are simulated.

## Background-themed title artwork

TitleScreen resolves its canonical Overworld start-cursor texture through the active background area's AreaTheme.texture_overrides. Underground maps it to assets/palettes/underground/ui/start-cursor.png. This is the same visual-theme resource used for terrain and HUD coin artwork; the cursor remains a screen-space Sprite2D on the 8x8 UI grid. White menu text stays on the existing HUD font.

The title binds the active area on readiness and level/area changes, and listens to BaseLevelArea.area_theme_changed for runtime theme selection. The signal follows the area's existing TileSet application. Missing/null themes fall back to the canonical Overworld cursor; mapping always starts from that canonical asset so returning from Underground cannot retain stale art. Connections are released on title exit and shared scene/texture resources are not modified. Additional title artwork can use the same mapping as it is introduced.

Focused title/area-theme checks cover both presets, an initially Underground title instance, live theme selection, null/missing-art fallback, canonical resource isolation, unchanged white font and the existing Start/cancellation/cleanup flow.

## Shared player status

Starting a new game resets Small form, score/coins to zero and reserves to two (three displayed lives), while retaining top score for the app session. See [player status](player-status.md).

## Copyright accent font

Copyright is positioned at (104,120), following a requested three-cell (24-pixel) rightward adjustment. AreaTheme.title_accent_font optionally supplies a replacement Font for this label; null or unavailable themes use the canonical Overworld alternate font. The Underground preset assigns assets/palettes/underground/ui/alphabet-alt.fnt, which maps the supplied cyan alphabet-alt.png using the same glyph layout, including ©. Both initial Underground startup and live theme changes select it. This leaves menu/top-score fonts white. Title font overrides are instance-local and refresh through the existing area-theme binding. The source PNG and its existing texture import settings are preserved.

## Palette-aware title card

TitleScreen/TitleCard is a native-size 192x96 Sprite2D at (32,32), with centered=false, on the existing 8x8 UI grid and shared shadow composition. It sits above the copyright/menu without changing their positions. The canonical texture is assets/palettes/overworld/ui/start-title.png; Underground maps it to its own ui/start-title.png through AreaTheme.texture_overrides. Initial area selection, live theme changes and missing/null-theme fallback use the same binding as the cursor. Scene defaults remain Overworld and shared textures are not modified.

Both PNGs are batch exports of the supplied start-title.aseprite sources using the installed Aseprite CLI. Keep those editable files; after changing a card, export its matching PNG at native size. The game loads PNG textures rather than Aseprite documents. Existing project/render/input settings and other atlas import settings are unchanged.

Title tests allow authored block scenery in the shared sandbox and verify that every existing background entity is gameplay-suspended. Static/cosmetic background animation is still allowed; no entity movement or demo playback is introduced.

Game over explicitly shuts down/removes the departed stage and clears its progress before returning here. Holding Start through the game-over card requires release before a new title Start edge. Returning preserves the earned score/coin totals and top score until normal new-game initialization resets player/session values. See [game over](game-over.md).

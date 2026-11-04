# Intermittent held Run investigation

The user reports Run sometimes feels released after jumping/landing, with a re-press restoring it. The cause is not yet reproduced or established. ControllerHandler polls secondary every physics tick, and grounded states rebuild the Run profile from that held value. Jump/fall air control can have a lower speed cap depending on current speed; this is separate from losing the button intent. No production input, movement constants, buffering, binding or Project Settings changes were made for this investigation.

## Capture an occurrence

1. Open tools/diagnostics/run_input_probe.tscn and press F6.
2. Start 1 PLAYER GAME or 1 PLAYER TEST normally. The diagnostic uses the normal Game/title lifecycle.
3. Hold Run and reproduce the jumping/landing issue. An overlay displays Pad X, mapped action, handler value, current state, floor contact, input gate, horizontal speed, effective cap and active modifiers.
4. Press F7 when Run feels lost, ideally before releasing it. Then release/re-press Run as usual; both button events are recorded.
5. Press F8/stop the run to save, or let it finish after three minutes. Output prints the absolute CSV path under user://diagnostics. Project > Open User Data Folder locates that directory.

The overlay/recorder is opt-in and never attaches during normal F5 gameplay. It samples after player/level physics, stores changes and button/focus/connection events in memory, and writes once at completion. Pad X is Godot's per-device mapped button state, not a hardware/HID trace. An apparent release there may involve the controller, driver, connection or focus; it does not alone prove a hardware fault. All listed connected devices are shown. Keyboard Run events are recorded too, although Pad X naturally remains zero when using the keyboard.

## Interpret the layers

- Pad X becomes 0 while physically held: inspect the accompanying button-release, focus and connection events; the engine is no longer reporting that device button held.
- Pad X stays 1 but mapped action becomes false: investigate action mapping/aggregation.
- Mapped action stays true but handler becomes false: check handler_enabled and the controller sampling path.
- Handler stays true but controls are unavailable: check the entity suspension/input gate and current state's controls flag.
- Input remains held but the effective cap stays at 90 after returning to grounded Move: inspect air/slide modifiers and the ground profile handoff.
- Only velocity falls, while input and the 150 cap remain active: investigate collision/movement rather than inferring a lost button.

State/control details can be inspected in the Remote Inspector alongside a capture. Physics-step values do not establish what the physical controller transmitted; a hardware reproduction is still needed. Do not add release debouncing or Run latching without evidence, since it would change the reference release behavior.

## Verification - 2026-11-04

held_run_landing_test passed rendered at a 240 FPS cap: 16 jump/landing cycles, four combinations of keyboard/simulated-controller input and travel direction, with Run pressed once per trial. Assertions check held mapped/handler intent, removed air modifier, grounded 150 speed cap, actual 150 speed and no re-press. A rendered probe startup/shutdown smoke run saved a CSV without engine errors/warnings. These do not reproduce a physical controller dropout or prove the reported issue resolved.

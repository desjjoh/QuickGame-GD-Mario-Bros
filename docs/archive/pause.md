# Gameplay pause

## Ownership and behavior

GameHandler creates PauseController alongside its other lifecycle helpers. It exposes `is_paused`, `pause_changed(value)`, and `request_pause_toggle()`. Pause preserves Playing flow and current level state.

PauseController accepts the existing ControllerHandler Start action through an Always-processing input listener. SceneTree pause stops physics, frame processing, animations, bound tweens, ordinary audio, and the shared cosmetic clock. The listener continues running so the same action can resume. No menu, dimming, automatic focus-loss pause, Input Map change, or project setting is added.

Pause requires an existing level that has not shut down. The only presentation exclusions are the title screen and an active TransitionCoordinator operation. Pipe entry/emergence, death (including waits after player retirement), and level endings remain pausable. Weak standalone-level registration permits F6 pause without starting its session timer or music. Current-level ownership takes precedence over the fallback.

## Input and cleanup

Start is Enter or controller Start/Menu. Enter also belongs to Primary. Both pause edges consume confirmation through ControllerHandler's existing release latch, preventing a resume jump. Echoes are ignored, a fresh Start release is required, and input toggles have a 43/60-second lockout measured while paused as well. Programmatic toggles share eligibility but bypass physical-button debounce.

Level shutdown clears pause before cancelling gameplay. Session reset, entering Title or Detached flow, and starting an accepted screen transition also clear it. Completing flow does not clear pause. Cleanup stops the pause voice without a resume cue. Weak source tracking avoids retaining freed levels.

## Audio

SoundHandler's dedicated non-positional PauseCue AudioStreamPlayer uses Process Mode Always and default playback gain and pitch. The handler and reward player remain pausable. Music and existing effects preserve playback positions and resume immediately on unpause.

The same cue plays on both edges. The reference SoundEngine uses frequency-table offsets $44 and $64 (periods $54 and $6a), control $84, and note durations 6, 6, 6, and 24 nominal 60 Hz frames. Each note restarts the envelope. The existing pulse generator renders a 0.7-second WAV. Reference: [SMB disassembly, SoundEngine and FreqRegLookupTbl](https://gist.github.com/1wErt3r/4048722).

The NES clears effect buffers on pause and holds its audio engine through the resume cue; our agreed behavior preserves audio and resumes it immediately. Listening comparison against Mesen remains outstanding; exact APU output fidelity is not claimed.

## Verification

On 2026-11-07, pause_test reached PASS in Godot 4.7.2 headless at a real-time 60 FPS cap. Coverage includes Enter, echo rejection, no resume jump, frozen player position/velocity, Goomba movement, mushroom emergence, popup tween, timer and clock, suspended music/reward playback, independently finishing pause audio, lifecycle exclusions, paused shutdown, and standalone F6 cleanup. The expanded test reported two ObjectDB leaks at exit.

Title, transition, sideways-pipe, and animation-clock regressions also reached PASS. Transition reported two ObjectDB leaks and animation-clock seven. No full suite was run. Rendered playtesting, physical controller input, and listening comparison remain manual checks.

### Presentation coverage update - 2026-11-07

The initial lifecycle exclusions above were superseded by the title/transition-only rule. Updated pause_test verifies allowed presentation flags, Completing flow, title/transition rejection, and an accepted transition clearing an existing pause. Death, sideways_pipe, and flagpole_ending tests use a shared pause snapshot fixture to check frozen presentation state and successful continuation. All five focused scenes (including transition_test) reached PASS. Pause and flagpole-ending runs reported two ObjectDB leaks each. Rendered verification remains outstanding.
